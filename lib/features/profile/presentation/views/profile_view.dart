import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/core/theme/theme_controller.dart';
import 'package:senasgo/features/cloud/presentation/widgets/cloud_account_section.dart';
import 'package:senasgo/features/profile/data/calendar_service.dart';
import 'package:senasgo/features/support/presentation/support_actions.dart';
import 'package:senasgo/shared/models/progress_model.dart';
import 'package:senasgo/shared/models/user_model.dart';
import 'package:senasgo/shared/widgets/app_ui.dart';
import 'package:senasgo/shared/widgets/jaguarete_mascot.dart';

/// Perfil local de quien aprende.
///
/// Es también la puerta a la liga y a las novedades, dos pantallas que en
/// Duolingo son sociales. Acá son locales y honestas: no hay cuentas ni
/// servidores, así que no inventamos amigos ni rankings falsos.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late UserModel _user = HiveService.currentUser;
  late ProgressModel _progress = HiveService.progress;
  late int _goal = HiveService.dailyGoalMinutes;

  void _reload() {
    setState(() {
      _user = HiveService.currentUser;
      _progress = HiveService.progress;
      _goal = HiveService.dailyGoalMinutes;
    });
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _user.username);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cómo te llamamos?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 24,
          decoration: const InputDecoration(
            labelText: 'Tu nombre',
            hintText: 'Aprendiz de LSPy',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    await HiveService.updateUsername(result);
    if (mounted) _reload();
  }

  Future<void> _editGoal() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.locked,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Tu meta diaria',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Elegí un tiempo que puedas sostener. La constancia importa más que la prisa.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              for (final minutes in const [5, 10, 15, 20])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => Navigator.pop(sheetContext, minutes),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: minutes == _goal
                            ? AppColors.primary
                            : AppColors.outlineStrong,
                        width: minutes == _goal ? 2 : 1,
                      ),
                    ),
                    tileColor: minutes == _goal
                        ? AppColors.primarySoft
                        : AppColors.surface,
                    leading: Icon(
                      Icons.timer_outlined,
                      color: minutes == _goal
                          ? AppColors.primary
                          : AppColors.muted,
                    ),
                    title: Text(
                      '$minutes minutos por día',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    trailing: minutes == _goal
                        ? Icon(Icons.check_circle_rounded,
                            color: AppColors.primary)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    await HiveService.setDailyGoalMinutes(selected);
    if (mounted) _reload();
  }

  Future<void> _editReminder() async {
    if (!calendarSupported) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text(
              'El calendario del dispositivo está disponible en la app Android o iOS.'),
        ));
      return;
    }
    final result = await showModalBottomSheet<_ReminderChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ReminderSheet(
        initialWeekday: HiveService.reminderWeekday,
        initialHour: HiveService.reminderHour,
        initialMinute: HiveService.reminderMinute,
      ),
    );
    if (result == null || !mounted) return;
    final opened = await addPracticeReminder(
      weekday: result.weekday,
      hour: result.hour,
      minute: result.minute,
    );
    if (!mounted) return;
    if (opened) {
      await HiveService.setReminder(
        weekday: result.weekday,
        hour: result.hour,
        minute: result.minute,
      );
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Recordatorio agregado a tu calendario.'),
        ));
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('No se pudo abrir el calendario del dispositivo.'),
        ));
    }
  }

  static String _reminderLabel() {
    final weekday = HiveService.reminderWeekday;
    if (weekday == null) return 'Elegí un día y una hora';
    const days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    final h = HiveService.reminderHour.toString().padLeft(2, '0');
    final m = HiveService.reminderMinute.toString().padLeft(2, '0');
    return '${days[(weekday - 1).clamp(0, 6)]} · $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final nextXp = HiveService.xpToNextLevel(_user.xp);
    final base = HiveService.xpForLevel(_user.level);
    final nextBase = nextXp == null ? _user.xp : _user.xp + nextXp;
    final levelFraction = nextXp == null
        ? 1.0
        : ((_user.xp - base) / (nextBase - base)).clamp(0.0, 1.0);
    final totalSigns = HiveService.signsOfAll.length;
    final learned = _progress.completedSignIds.length;
    final weeklyXp = HiveService.weeklyXp;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          IconButton(
            tooltip: 'Ayuda y comentarios',
            onPressed: () =>
                SupportSheet.show(context, contextLabel: 'Mi perfil'),
            icon: const Icon(Icons.support_agent_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          AppHeroHeader(
            colors: const [
              Color(0xFF0B3B2E),
              Color(0xFF0F766E),
              Color(0xFF115E59)
            ],
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.36),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: ColoredBox(
                          color: AppColors.primarySoft,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: JaguareteMascot(size: 96),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _user.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Nivel ${_user.level}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.86),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar nombre',
                      onPressed: _editName,
                      icon: const Icon(Icons.edit_rounded, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                Row(
                  children: [
                    Text(
                      '${_user.xp} XP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      nextXp == null
                          ? 'Nivel máximo'
                          : '$nextXp XP para el nivel ${_user.level + 1}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: levelFraction,
                    minHeight: 9,
                    backgroundColor: Colors.white.withValues(alpha: 0.22),
                    valueColor: AlwaysStoppedAnimation(AppColors.gold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ProfileStat(
                  icon: Icons.sign_language_rounded,
                  color: AppColors.primary,
                  value: '$learned',
                  label: 'señas aprendidas',
                  hint: 'de $totalSigns',
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _ProfileStat(
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.streak,
                  value: '${HiveService.streak}',
                  label: 'días de racha',
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _ProfileStat(
                  icon: Icons.bolt_rounded,
                  color: AppColors.teal,
                  value: '$weeklyXp',
                  label: 'XP semanal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const AppSectionTitle('Mi compromiso'),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AppIconBadge(
                  icon: Icons.timer_outlined,
                  color: AppColors.teal,
                  size: 50,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meta diaria',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                      Text(
                        '$_goal min',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 19,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _editGoal,
                  icon: const Icon(Icons.tune_rounded, size: 17),
                  label: const Text('Cambiar'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            onTap: () => context.push('/streak'),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AppIconBadge(
                  icon: Icons.calendar_month_rounded,
                  color: AppColors.streak,
                  size: 50,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calendario de racha',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                      Text(
                        '${HiveService.bestStreak} días es tu mejor racha',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            onTap: _editReminder,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AppIconBadge(
                  icon: Icons.notifications_active_rounded,
                  color: AppColors.primary,
                  size: 50,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recordatorio de práctica',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                      Text(
                        _reminderLabel(),
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const CloudAccountSection(),
          const SizedBox(height: 20),
          const AppSectionTitle('Apariencia'),
          const SizedBox(height: 10),
          const _AppearancePicker(),
          const SizedBox(height: 20),
          const AppSectionTitle('Comunidad'),
          const SizedBox(height: 10),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ProfileLinkRow(
                  icon: Icons.emoji_events_rounded,
                  color: AppColors.gold,
                  title: 'Liga de práctica',
                  subtitle: '$weeklyXp XP esta semana',
                  onTap: () => context.push('/league'),
                ),
                const Divider(height: 1, indent: 66),
                _ProfileLinkRow(
                  icon: Icons.people_alt_rounded,
                  color: AppColors.indigo,
                  title: 'Novedades',
                  subtitle: 'Tu actividad, solo en este teléfono',
                  onTap: () => context.push('/community'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const AppSectionTitle('Ajustes'),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded),
                  title: const Text('Ayuda y comentarios'),
                  subtitle: const Text('Preguntas, ideas o problemas'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => SupportSheet.show(context,
                      contextLabel: 'Mi perfil · ajustes'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.add_to_home_screen_rounded),
                  title: const Text('Acceso rápido en tu teléfono'),
                  subtitle: const Text('Tené SeñasGo a un toque'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/shortcut'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Acerca de SeñasGo'),
                  subtitle: const Text(
                      'Versión ${AppConstants.appVersion} · 100% offline'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/help'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tus datos viven en este teléfono. No hay cuentas, nube ni publicidad.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLinkRow extends StatelessWidget {
  const _ProfileLinkRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              AppIconBadge(icon: icon, color: color, size: 42, radius: 13),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Oscuro · Claro · Según el sistema. El cambio se ve al instante.
class _AppearancePicker extends StatelessWidget {
  const _AppearancePicker();

  static const _icons = {
    AppearancePreference.dark: Icons.dark_mode_rounded,
    AppearancePreference.light: Icons.light_mode_rounded,
    AppearancePreference.system: Icons.brightness_auto_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Row(
        children: [
          for (final option in AppearancePreference.values) ...[
            if (option != AppearancePreference.values.first)
              const SizedBox(width: 8),
            Expanded(
              child: _AppearanceOption(
                icon: _icons[option]!,
                label: option.label,
                selected: controller.preference == option,
                onTap: () => controller.setPreference(option),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppearanceOption extends StatelessWidget {
  const _AppearanceOption({
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
    final radius = BorderRadius.circular(18);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Apariencia: $label',
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.outlineStrong,
                width: selected ? 2 : 1.4,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 26,
                    color: selected ? AppColors.primary : AppColors.muted),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.15,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: selected ? AppColors.primaryDeep : AppColors.ink,
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

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.hint,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 12, 8, 11),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  height: 1,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    hint!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
              fontSize: 9.5,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderChoice {
  const _ReminderChoice({
    required this.weekday,
    required this.hour,
    required this.minute,
  });

  final int weekday;
  final int hour;
  final int minute;
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({
    required this.initialWeekday,
    required this.initialHour,
    required this.initialMinute,
  });

  final int? initialWeekday;
  final int initialHour;
  final int initialMinute;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  static const _days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  late int _weekday = widget.initialWeekday?.clamp(1, 7) ?? 1;
  late TimeOfDay _time = TimeOfDay(
    hour: widget.initialHour.clamp(0, 23),
    minute: widget.initialMinute.clamp(0, 59),
  );

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.locked,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Recordatorio de práctica',
                style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink)),
            const SizedBox(height: 4),
            Text(
              'Elegí un día y una hora para practicar LSPy.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < 7; i++)
                  ChoiceChip(
                    selected: _weekday == i + 1,
                    onSelected: (_) => setState(() => _weekday = i + 1),
                    label: Text(_days[i]),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(color: AppColors.outlineStrong),
                    labelStyle: TextStyle(
                      color: _weekday == i + 1
                          ? AppColors.onPrimary
                          : AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule_rounded),
              label: Text(
                '${_time.hour.toString().padLeft(2, '0')}:'
                '${_time.minute.toString().padLeft(2, '0')}',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Se agrega un evento semanal. Podés borrarlo desde tu calendario.',
              style: TextStyle(
                  color: AppColors.muted, fontSize: 11.5, height: 1.35),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                context,
                _ReminderChoice(
                  weekday: _weekday,
                  hour: _time.hour,
                  minute: _time.minute,
                ),
              ),
              icon: const Icon(Icons.event_available_rounded),
              label: const Text('AGREGAR AL CALENDARIO'),
            ),
          ],
        ),
      ),
    );
  }
}
