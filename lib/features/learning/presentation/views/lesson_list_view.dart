import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/support/presentation/support_actions.dart';
import 'package:senasgo/shared/models/lesson_model.dart';
import 'package:senasgo/shared/models/sign_model.dart';
import 'package:senasgo/shared/widgets/app_bottom_nav.dart';

/// Biblioteca: lecciones y señas del vocabulario acotado, con búsqueda y
/// filtros. Cada seña se puede abrir directamente en la demostración 3D.
enum _LibrarySection { lessons, signs }

class LessonListView extends StatefulWidget {
  const LessonListView({super.key});

  @override
  State<LessonListView> createState() => _LessonListViewState();
}

class _LessonListViewState extends State<LessonListView> {
  final _search = TextEditingController();
  late List<LessonModel> _lessons = HiveService.lessons;
  late List<SignModel> _signs = HiveService.signsOfAll;
  SignCategory? _category;
  String _query = '';
  _LibrarySection _section = _LibrarySection.lessons;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
        _lessons = HiveService.lessons;
        _signs = HiveService.signsOfAll;
      });

  List<SignModel> get _filteredSigns {
    final q = _query.trim().toLowerCase();
    return _signs.where((sign) {
      if (_category != null && sign.category != _category) return false;
      if (q.isEmpty) return true;
      return sign.name.toLowerCase().contains(q) ||
          sign.description.toLowerCase().contains(q) ||
          sign.tags.any((tag) => tag.toLowerCase().contains(q));
    }).toList();
  }

  List<LessonModel> get _filteredLessons {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _lessons;
    return _lessons.where((lesson) {
      if (lesson.title.toLowerCase().contains(q) ||
          lesson.description.toLowerCase().contains(q)) {
        return true;
      }
      return lesson.signIds.any((id) {
        final sign = HiveService.signById(id);
        return sign != null && sign.name.toLowerCase().contains(q);
      });
    }).toList();
  }

  String? _lessonOf(String signId) {
    for (final lesson in _lessons) {
      if (lesson.signIds.contains(signId)) return lesson.id;
    }
    return null;
  }

  void _openSign(SignModel sign) {
    final lessonId = _lessonOf(sign.id);
    if (lessonId == null) return;
    context.push('/lesson/$lessonId?sign=${sign.id}');
  }

  @override
  Widget build(BuildContext context) {
    final learned = HiveService.learnedSignIds;
    final lessons = _filteredLessons;
    final signs = _filteredSigns;

    return Scaffold(
      appBar: AppBar(
        // Pestaña raíz: sin flecha aunque Aprender la abra con push.
        automaticallyImplyLeading: false,
        title: const Text('Biblioteca'),
        actions: [
          IconButton(
            tooltip: 'Ayuda y comentarios',
            onPressed: () =>
                SupportSheet.show(context, contextLabel: 'Biblioteca de señas'),
            icon: const Icon(Icons.support_agent_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          _LibrarySwitch(
            section: _section,
            onChanged: (section) => setState(() {
              _section = section;
              if (section == _LibrarySection.lessons) _category = null;
            }),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: _section == _LibrarySection.lessons
                  ? 'Buscar una lección…'
                  : 'Buscar una seña…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: AppColors.outlineStrong),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: AppColors.outlineStrong),
              ),
            ),
          ),
          if (_section == _LibrarySection.signs) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _FilterChip(
                  label: 'Todas',
                  icon: Icons.apps_rounded,
                  selected: _category == null,
                  onTap: () => setState(() => _category = null),
                ),
                _FilterChip(
                  label: 'Saludos',
                  icon: Icons.waving_hand_rounded,
                  selected: _category == SignCategory.greetings,
                  onTap: () =>
                      setState(() => _category = SignCategory.greetings),
                ),
                _FilterChip(
                  label: 'Números',
                  icon: Icons.pin_rounded,
                  selected: _category == SignCategory.numbers,
                  onTap: () => setState(() => _category = SignCategory.numbers),
                ),
                _FilterChip(
                  label: 'Básicos',
                  icon: Icons.chat_bubble_outline_rounded,
                  selected: _category == SignCategory.basics,
                  onTap: () => setState(() => _category = SignCategory.basics),
                ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          if (_section == _LibrarySection.lessons) ...[
            const _SectionHeader(title: 'Lecciones'),
            const SizedBox(height: 10),
            if (lessons.isEmpty)
              _EmptySearch(
                onClear: () {
                  _search.clear();
                  setState(() => _query = '');
                },
              )
            else
              for (var i = 0; i < lessons.length; i++) ...[
                _LessonCard(
                  lesson: lessons[i],
                  palette: UnitPalette.of(i),
                  learned: learned,
                  onTap: () async {
                    await context.push('/lesson/${lessons[i].id}');
                    if (mounted) _reload();
                  },
                ),
                const SizedBox(height: 10),
              ],
          ] else ...[
            _SectionHeader(
              title: _query.isEmpty && _category == null
                  ? 'Todas las señas'
                  : 'Resultados',
              subtitle: signs.isEmpty
                  ? 'No encontramos señas con ese filtro.'
                  : '${signs.length} seña${signs.length == 1 ? '' : 's'} disponible${signs.length == 1 ? '' : 's'}.',
            ),
            const SizedBox(height: 10),
            if (signs.isEmpty)
              _EmptySearch(
                onClear: () {
                  _search.clear();
                  setState(() {
                    _query = '';
                    _category = null;
                  });
                },
              )
            else
              for (final sign in signs) ...[
                _SignCard(
                  sign: sign,
                  learned: learned.contains(sign.id),
                  onTap: () => _openSign(sign),
                ),
                const SizedBox(height: 8),
              ],
            if (_query.isNotEmpty || _category != null) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () {
                  _search.clear();
                  setState(() {
                    _query = '';
                    _category = null;
                  });
                },
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Ver todas las señas'),
              ),
            ],
          ],
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(icon,
          size: 14, color: selected ? AppColors.onPrimary : AppColors.primary),
      label: Text(label),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: AppColors.outlineStrong),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      labelPadding: const EdgeInsets.only(right: 2),
      labelStyle: TextStyle(
        color: selected ? AppColors.onPrimary : AppColors.ink,
        fontWeight: FontWeight.w800,
        fontSize: 11.5,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.ink)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!,
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ],
    );
  }
}

/// Cambia entre el recorrido de lecciones y el vocabulario suelto sin
/// apilar dos listas largas en la misma pantalla.
class _LibrarySwitch extends StatelessWidget {
  const _LibrarySwitch({required this.section, required this.onChanged});

  final _LibrarySection section;
  final ValueChanged<_LibrarySection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _LibrarySwitchOption(
              icon: Icons.school_rounded,
              label: 'Lecciones',
              selected: section == _LibrarySection.lessons,
              onTap: () => onChanged(_LibrarySection.lessons),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _LibrarySwitchOption(
              icon: Icons.sign_language_rounded,
              label: 'Señas',
              selected: section == _LibrarySection.signs,
              onTap: () => onChanged(_LibrarySection.signs),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibrarySwitchOption extends StatelessWidget {
  const _LibrarySwitchOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.surface : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18,
                    color: selected ? AppColors.primary : AppColors.muted),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? AppColors.primary : AppColors.muted,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.palette,
    required this.learned,
    required this.onTap,
  });

  final LessonModel lesson;
  final UnitPalette palette;
  final Set<String> learned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = lesson.signIds.where((id) => learned.contains(id)).length;
    final total = lesson.signIds.length;
    final fraction = total == 0 ? 0.0 : done / total;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: palette.face.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(17),
                ),
                child:
                    Icon(Icons.school_rounded, color: palette.face, size: 27),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(lesson.title,
                              style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.ink)),
                        ),
                        if (done == total && total > 0)
                          Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 20),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(lesson.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12.5,
                            height: 1.3)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: fraction,
                              minHeight: 6,
                              backgroundColor: AppColors.primarySoft,
                              valueColor: AlwaysStoppedAnimation(palette.face),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$done/$total',
                            style: TextStyle(
                                color: palette.face,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignCard extends StatelessWidget {
  const _SignCard({
    required this.sign,
    required this.learned,
    required this.onTap,
  });

  final SignModel sign;
  final bool learned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      learned ? AppColors.successSoft : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  learned ? Icons.check_rounded : Icons.sign_language_rounded,
                  color: learned ? AppColors.success : AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(sign.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: AppColors.ink)),
                        const SizedBox(width: 7),
                        _CategoryTag(category: sign.category),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(sign.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.muted, fontSize: 12, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Icon(Icons.play_circle_outline_rounded,
                  color: AppColors.primary, size: 23),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({required this.category});

  final SignCategory category;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (category) {
      SignCategory.greetings => ('Saludo', AppColors.primary),
      SignCategory.numbers => ('Número', AppColors.gem),
      SignCategory.basics => ('Básico', AppColors.streak),
      SignCategory.family => ('Familia', AppColors.success),
      SignCategory.emotions => ('Emoción', AppColors.heart),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9.5, fontWeight: FontWeight.w800)),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: AppColors.muted),
          const SizedBox(height: 8),
          Text('Sin resultados',
              style:
                  TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 4),
          Text('Probá con otra palabra o categoría.',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Limpiar filtros'),
          ),
        ],
      ),
    );
  }
}
