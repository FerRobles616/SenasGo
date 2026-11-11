import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/practice/presentation/widgets/feedback_panel.dart';
import 'package:senasgo/shared/models/sign_model.dart';
import 'package:senasgo/shared/widgets/app_feature_icon.dart';
import 'package:senasgo/shared/widgets/exit_lesson_dialog.dart';
import 'package:senasgo/shared/widgets/jaguarete_mascot.dart';
import 'package:senasgo/shared/widgets/lesson_progress_bar.dart';

/// Repaso rápido sin cámara: preguntas de opción múltiple sobre las señas de
/// una lección. Alterna "¿qué seña es?" (descripción → nombre) y "¿cómo se
/// hace?" (nombre → descripción). No afecta el progreso: sirve para afianzar lo
/// aprendido en cualquier lugar, aunque no se pueda usar la cámara.
class QuizView extends StatefulWidget {
  const QuizView({required this.lessonId, super.key});

  /// Lección a repasar; sin lección se repasan todas las señas.
  final String? lessonId;

  @override
  State<QuizView> createState() => _QuizViewState();
}

enum _Kind { whichSign, howToSign }

class _Question {
  const _Question(this.kind, this.answer, this.options);

  final _Kind kind;
  final SignModel answer;
  final List<SignModel> options;
}

class _QuizViewState extends State<QuizView> {
  /// La mitad que una seña practicada con cámara.
  static const _xpPerAnswer = 5;

  late final List<_Question> _questions = _buildQuestions();
  late final String _title = _lessonTitle();

  int _index = 0;
  SignModel? _selected;
  bool _checked = false;
  int _correct = 0;
  int _combo = 0;
  int _earnedXp = 0;
  bool _finished = false;
  bool _leaving = false;

  String _lessonTitle() {
    for (final lesson in HiveService.lessons) {
      if (lesson.id == widget.lessonId) return lesson.title;
    }
    return 'Todas las señas';
  }

  List<_Question> _buildQuestions() {
    final rnd = math.Random();
    final all = HiveService.signsOfAll;
    final lessonSigns =
        widget.lessonId == null ? all : HiveService.signsOf(widget.lessonId!);
    final pool = (lessonSigns.isEmpty ? all : lessonSigns).toList()
      ..shuffle(rnd);
    return [
      for (var i = 0; i < pool.length; i++)
        _Question(
          i.isEven ? _Kind.whichSign : _Kind.howToSign,
          pool[i],
          _optionsFor(pool[i], all, rnd),
        ),
    ];
  }

  /// La respuesta y tres señas más, primero de la misma categoría: elegir
  /// entre "Uno" y "Dos" enseña más que entre "Uno" y "Gracias".
  List<SignModel> _optionsFor(
      SignModel answer, List<SignModel> all, math.Random rnd) {
    final others = all.where((s) => s.id != answer.id).toList()..shuffle(rnd);
    final same = others.where((s) => s.category == answer.category);
    final rest = others.where((s) => s.category != answer.category);
    return [
      answer,
      ...[...same, ...rest].take(3)
    ]..shuffle(rnd);
  }

  bool get _isLast => _index + 1 >= _questions.length;

  void _select(SignModel option) {
    if (_checked) return;
    setState(() => _selected = option);
  }

  void _check() {
    if (_selected == null || _checked) return;
    final ok = _selected!.id == _questions[_index].answer.id;
    setState(() {
      _checked = true;
      if (ok) {
        _correct++;
        _combo++;
      } else {
        _combo = 0;
      }
    });
  }

  Future<void> _next() async {
    if (!_isLast) {
      setState(() {
        _index++;
        _selected = null;
        _checked = false;
      });
      return;
    }
    final xp = _correct * _xpPerAnswer;
    if (xp > 0) await HiveService.addXp(xp);
    if (!mounted) return;
    setState(() {
      _earnedXp = xp;
      _finished = true;
    });
  }

  // ───────────────────────── Salida ─────────────────────────

  bool get _needsExitConfirm =>
      !_leaving &&
      !_finished &&
      _questions.isNotEmpty &&
      (_index > 0 || _checked || _selected != null);

  Future<void> _confirmExit() async {
    if (!_needsExitConfirm) {
      _leave();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => ExitLessonDialog(
        remaining: _questions.length - _index - (_checked ? 1 : 0),
        singular: 'pregunta',
        plural: 'preguntas',
        goal: 'el repaso',
      ),
    );
    if (leave == true && mounted) _leave();
  }

  void _leave() {
    setState(() => _leaving = true);
    // Un cuadro después, cuando PopScope ya deja salir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.canPop() ? context.pop() : context.go('/');
    });
  }

  // ───────────────────────── Pantalla ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return PopScope(
      canPop: !_needsExitConfirm,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        body: SafeArea(
          child: _questions.isEmpty
              ? _empty()
              : _finished
                  ? _summary()
                  : _question(reduceMotion),
        ),
      ),
    );
  }

  Widget _question(bool reduceMotion) {
    final q = _questions[_index];
    return Column(
      children: [
        _header(),
        Expanded(
          child: AnimatedSwitcher(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0.08, 0), end: Offset.zero)
                    .animate(animation),
                child: child,
              ),
            ),
            child: ListView(
              key: ValueKey(_index),
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              children: [
                Text(
                  'REPASO RÁPIDO · ${_title.toUpperCase()}',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  q.kind == _Kind.whichSign
                      ? '¿Qué seña es?'
                      : '¿Cómo se hace «${q.answer.name}»?',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 14),
                if (q.kind == _Kind.whichSign) ...[
                  _PromptCard(text: q.answer.description),
                  const SizedBox(height: 18),
                  _nameGrid(q),
                ] else ...[
                  Text(
                    'Elegí la descripción correcta.',
                    style: TextStyle(color: AppColors.muted, fontSize: 15),
                  ),
                  const SizedBox(height: 14),
                  for (final option in q.options) ...[
                    _OptionCard(
                      state: _stateOf(option, q),
                      onTap: () => _select(option),
                      semanticLabel: option.description,
                      child: Text(
                        option.description,
                        style: TextStyle(
                          color: _inkOf(option, q),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
        ),
        _bottom(q),
      ],
    );
  }

  Widget _header() {
    final done = _index + (_checked ? 1 : 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Salir del repaso',
                onPressed: _confirmExit,
                icon:
                    Icon(Icons.close_rounded, size: 28, color: AppColors.muted),
              ),
              Expanded(
                child: LessonProgressBar(
                  done: done,
                  total: _questions.length,
                  unitLabel: 'preguntas',
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: ComboChip(combo: _combo),
          ),
        ],
      ),
    );
  }

  Widget _nameGrid(_Question q) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        for (final option in q.options)
          _OptionCard(
            state: _stateOf(option, q),
            onTap: () => _select(option),
            semanticLabel: option.name,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _categoryIcon(option.category, _inkOf(option, q)),
                const SizedBox(height: 8),
                Text(
                  option.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _inkOf(option, q),
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _bottom(_Question q) {
    if (!_checked) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: FilledButton(
          onPressed: _selected == null ? null : _check,
          child: const Text('COMPROBAR'),
        ),
      );
    }
    final ok = _selected!.id == q.answer.id;
    return VerdictPanel(
      key: ValueKey('quiz-$_index'),
      success: ok,
      title: ok ? '¡Correcto!' : '¡Casi!',
      message: ok
          ? _combo >= 2
              ? '$_combo seguidas · +$_xpPerAnswer XP'
              : '+$_xpPerAnswer XP al terminar el repaso.'
          : q.kind == _Kind.whichSign
              ? 'Era «${q.answer.name}».'
              : 'Se hace así: ${q.answer.description}',
      child: FilledButton(
        onPressed: _next,
        child: Text(_isLast ? 'VER RESULTADO' : 'CONTINUAR'),
      ),
    );
  }

  Widget _summary() {
    final total = _questions.length;
    final perfect = _correct == total;
    final percent = total == 0 ? 0 : (_correct * 100 / total).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: JaguareteMascot(
              size: 140,
              mood: perfect ? MascotMood.cheering : MascotMood.happy,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            perfect ? '¡Repaso perfecto!' : '¡Repaso completo!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Acertaste $_correct de $total.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 17),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  icon: Icons.bolt_rounded,
                  asset: AppFeatureAssets.xp,
                  color: AppColors.gold,
                  value: '+$_earnedXp',
                  label: 'XP',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryStat(
                  icon: Icons.track_changes_rounded,
                  asset: AppFeatureAssets.goal,
                  color: AppColors.success,
                  value: '$percent%',
                  label: 'aciertos',
                ),
              ),
            ],
          ),
          const Spacer(),
          FilledButton(
            onPressed: _leave,
            child: const Text('VOLVER AL CAMINO'),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: JaguareteMascot(mood: MascotMood.thinking)),
          const SizedBox(height: 16),
          Text(
            'Todavía no hay señas para repasar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.ink, fontSize: 18),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _leave, child: const Text('VOLVER')),
        ],
      ),
    );
  }

  // ───────────────────────── Estados de opción ─────────────────────────

  _OptionState _stateOf(SignModel option, _Question q) {
    final isSelected = _selected?.id == option.id;
    if (!_checked) {
      return isSelected ? _OptionState.selected : _OptionState.idle;
    }
    if (option.id == q.answer.id) return _OptionState.correct;
    if (isSelected) return _OptionState.wrong;
    return _OptionState.dimmed;
  }

  Color _inkOf(SignModel option, _Question q) => switch (_stateOf(option, q)) {
        _OptionState.selected => AppColors.primary,
        _OptionState.correct => AppColors.successInk,
        _OptionState.wrong => AppColors.errorInk,
        _ => AppColors.ink,
      };

  IconData _iconOf(SignCategory category) => switch (category) {
        SignCategory.greetings => Icons.waving_hand_rounded,
        SignCategory.numbers => Icons.tag_rounded,
        SignCategory.basics => Icons.chat_bubble_outline_rounded,
        SignCategory.family => Icons.family_restroom_rounded,
        SignCategory.emotions => Icons.emoji_emotions_outlined,
      };

  String? _assetOf(SignCategory category) => switch (category) {
        SignCategory.greetings => AppFeatureAssets.practice,
        SignCategory.family => AppFeatureAssets.community,
        SignCategory.emotions => AppFeatureAssets.feedback,
        _ => null,
      };

  Widget _categoryIcon(SignCategory category, Color color) {
    final asset = _assetOf(category);
    final icon = _iconOf(category);
    if (asset == null) return Icon(icon, size: 30, color: color);
    return AppFeatureIcon(
      asset: asset,
      fallbackIcon: icon,
      color: color,
      size: 32,
    );
  }
}

enum _OptionState { idle, selected, correct, wrong, dimmed }

/// Tarjeta de respuesta con borde inferior "físico", como los botones del
/// camino. Cambia de color al elegirla y al comprobar.
class _OptionCard extends StatefulWidget {
  const _OptionCard({
    required this.state,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
  });

  final _OptionState state;
  final VoidCallback onTap;
  final String semanticLabel;
  final Widget child;

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final (background, edge) = switch (widget.state) {
      _OptionState.selected => (AppColors.primarySoft, AppColors.primary),
      _OptionState.correct => (AppColors.successSoft, AppColors.success),
      _OptionState.wrong => (AppColors.errorSoft, AppColors.error),
      _ => (AppColors.surface, AppColors.border),
    };
    const depth = 4.0;
    final pressed = _pressed && widget.state == _OptionState.idle ||
        _pressed && widget.state == _OptionState.selected;
    return Semantics(
      button: true,
      selected: widget.state == _OptionState.selected,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: widget.state == _OptionState.dimmed ? 0.45 : 1,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: EdgeInsets.only(top: pressed ? depth : 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: edge, width: 2),
              boxShadow: pressed
                  ? null
                  : [BoxShadow(color: edge, offset: const Offset(0, depth))],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Descripción de la seña en una tarjeta, con un ícono de mano.
class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.sign_language_rounded,
                color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.asset,
  });

  final IconData icon;
  final String? asset;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
      ),
      child: Column(
        children: [
          asset == null
              ? Icon(icon, color: color, size: 28)
              : AppFeatureIcon(
                  asset: asset!,
                  fallbackIcon: icon,
                  color: color,
                  size: 30,
                ),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 24)),
          Text(label,
              style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
