import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/shared/widgets/jaguarete_mascot.dart';
import 'package:senasgo/shared/widgets/pushable_button.dart';

/// Primer contacto con SeñasGo.
///
/// Tres pasos cortos, como en un juego: bienvenida, meta diaria y compromiso.
/// Todo se guarda en el teléfono; no hay cuenta ni servidor.
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _pages = PageController();
  int _page = 0;
  int _goal = AppConstants.defaultDailyGoalMinutes;
  bool _saving = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish({bool skip = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    await HiveService.setDailyGoalMinutes(_goal);
    await HiveService.setOnboardingDone(true);
    if (!mounted) return;
    context.go('/welcome-reward');
  }

  void _next() {
    if (_page >= 2) {
      _finish();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF04120F),
              AppColors.primary,
              Color(0xFF2DD4BF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 12, 0),
                child: Row(
                  children: [
                    const _BrandMark(),
                    const Spacer(),
                    TextButton(
                      onPressed: _saving ? null : () => _finish(skip: true),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                      ),
                      child: const Text('Saltar'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _WelcomePage(onStart: _next),
                    _GoalPage(
                      goal: _goal,
                      onChanged: (value) => setState(() => _goal = value),
                      onContinue: _next,
                    ),
                    _CommitmentPage(
                      goal: _goal,
                      onCommit: _finish,
                      onSkip: () => _finish(skip: true),
                      saving: _saving,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: i == _page ? 24 : 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i == _page
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(Icons.sign_language_rounded,
              color: AppColors.primary, size: 23),
        ),
        const SizedBox(width: 9),
        const Text(
          'SeñasGo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    // En teléfonos de 320×640 la bienvenida necesita compactarse para que
    // EMPEZAR quede a la vista sin obligar a desplazar la primera pantalla.
    final compact = MediaQuery.sizeOf(context).height < 720;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, compact ? 4 : 12, 24, 8),
      child: Column(
        children: [
          SizedBox(height: compact ? 4 : 12),
          Container(
            width: compact ? 132 : 168,
            height: compact ? 132 : 168,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 2,
              ),
            ),
            child: Center(
              child: JaguareteMascot(
                size: compact ? 104 : 132,
                mood: MascotMood.cheering,
              ),
            ),
          ),
          SizedBox(height: compact ? 12 : 22),
          Text(
            'Aprendé LSPy\ncon el Jaguareté',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 29 : 35,
              fontWeight: FontWeight.w900,
              height: 1.03,
              letterSpacing: -0.7,
            ),
          ),
          SizedBox(height: compact ? 6 : 10),
          Text(
            'Lecciones cortas, un profesor 3D que te muestra cada paso y '
            'práctica con cámara. Todo funciona sin internet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: compact ? 13 : 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? 12 : 22),
          _FeatureRow(
            compact: compact,
            icon: Icons.view_in_ar_rounded,
            title: 'Profesor 3D',
            subtitle: 'Mirá la forma, el lugar y el movimiento de cada seña.',
          ),
          SizedBox(height: compact ? 6 : 9),
          _FeatureRow(
            compact: compact,
            icon: Icons.videocam_rounded,
            title: 'Práctica con cámara',
            subtitle: 'La app analiza tu mano sin guardar ni enviar imágenes.',
          ),
          SizedBox(height: compact ? 6 : 9),
          _FeatureRow(
            compact: compact,
            icon: Icons.offline_bolt_rounded,
            title: '100% offline',
            subtitle: 'Tus lecciones y tu progreso viven en este teléfono.',
          ),
          SizedBox(height: compact ? 14 : 26),
          PushableButton(
            onPressed: onStart,
            color: Colors.white,
            shadowColor: const Color(0xFFB9D6FF),
            height: compact ? 54 : 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'EMPEZAR',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.7,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 11 : 14,
        vertical: compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 34 : 38,
            height: compact ? 34 : 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: compact ? 19 : 21),
          ),
          SizedBox(width: compact ? 9 : 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 13 : 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 11.5 : 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalPage extends StatelessWidget {
  const _GoalPage({
    required this.goal,
    required this.onChanged,
    required this.onContinue,
  });

  final int goal;
  final ValueChanged<int> onChanged;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 720;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, compact ? 8 : 22, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Eyebrow('TU RITMO'),
          SizedBox(height: compact ? 5 : 8),
          Text(
            '¿Cuánto tiempo\nquerés practicar?',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 28 : 34,
              fontWeight: FontWeight.w900,
              height: 1.03,
              letterSpacing: -0.6,
            ),
          ),
          SizedBox(height: compact ? 6 : 10),
          Text(
            'Elegí una meta realista. Vas a poder cambiarla cuando quieras '
            'desde tu perfil.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: compact ? 13 : 15,
              height: compact ? 1.3 : 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? 14 : 24),
          Wrap(
            spacing: compact ? 10 : 12,
            runSpacing: compact ? 10 : 12,
            children: [
              for (final option in const [5, 10, 15, 20])
                _GoalOption(
                  minutes: option,
                  selected: goal == option,
                  compact: compact,
                  onTap: () => onChanged(option),
                ),
            ],
          ),
          SizedBox(height: compact ? 14 : 24),
          Container(
            padding: EdgeInsets.all(compact ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_rounded, color: Color(0xFFFFD86B)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Con 10 minutos por día podés aprender una seña nueva y '
                    'repasar la anterior. La constancia importa más que la prisa.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 12 : 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 14 : 28),
          PushableButton(
            onPressed: onContinue,
            color: Colors.white,
            shadowColor: const Color(0xFFB9D6FF),
            height: compact ? 52 : 58,
            child: Text(
              'CONTINUAR',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalOption extends StatelessWidget {
  const _GoalOption({
    required this.minutes,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final int minutes;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - (compact ? 58 : 60)) / 2;
    return SizedBox(
      width: width,
      child: Material(
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 16,
              compact ? 10 : 16,
              compact ? 8 : 12,
              compact ? 9 : 14,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: selected ? AppColors.primary : Colors.white,
                  size: compact ? 19 : 22,
                ),
                SizedBox(width: compact ? 6 : 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$minutes min',
                        style: TextStyle(
                          // Sobre blanco en los dos temas.
                          color: selected ? AppPalette.light.ink : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: compact ? 18 : 20,
                        ),
                      ),
                      Text(
                        'por día',
                        style: TextStyle(
                          color: selected
                              ? AppPalette.light.muted
                              : Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                          fontSize: compact ? 11 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: compact ? 18 : 21),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommitmentPage extends StatelessWidget {
  const _CommitmentPage({
    required this.goal,
    required this.onCommit,
    required this.onSkip,
    required this.saving,
  });

  final int goal;
  final VoidCallback onCommit;
  final VoidCallback onSkip;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 720;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, compact ? 8 : 22, 24, 8),
      child: Column(
        children: [
          const _Eyebrow('TU COMPROMISO'),
          SizedBox(height: compact ? 5 : 8),
          Text(
            '¿Practicamos\ntodos los días?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 28 : 34,
              fontWeight: FontWeight.w900,
              height: 1.03,
              letterSpacing: -0.6,
            ),
          ),
          SizedBox(height: compact ? 6 : 10),
          Text(
            'Con $goal minutos por día vas a construir una racha. '
            'Si un día no podés, tus protectores te ayudan a no perderla.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: compact ? 13 : 15,
              height: compact ? 1.3 : 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? 12 : 22),
          Container(
            padding: EdgeInsets.all(compact ? 14 : 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        color: AppColors.streak, size: compact ? 40 : 48),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Racha de 1 día',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w900,
                            fontSize: compact ? 17 : 19,
                          ),
                        ),
                        Text(
                          'Hoy es un buen día para empezar',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                            fontSize: compact ? 11 : 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: compact ? 10 : 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < 7; i++)
                      _DayDot(
                        label: const ['L', 'M', 'M', 'J', 'V', 'S', 'D'][i],
                        active: i == 0,
                        compact: compact,
                      ),
                  ],
                ),
                SizedBox(height: compact ? 10 : 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '${AppConstants.initialStreakFreezes} protectores de racha',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 11.5 : 12.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 12 : 22),
          PushableButton(
            onPressed: saving ? null : onCommit,
            color: Colors.white,
            shadowColor: const Color(0xFFB9D6FF),
            height: compact ? 52 : 58,
            child: Text(
              saving ? 'PREPARANDO…' : 'MANTENER MI COMPROMISO',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: saving ? null : onSkip,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Ahora no'),
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.active,
    this.compact = false,
  });

  final String label;
  final bool active;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 32.0;
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: active ? AppColors.streak : AppColors.surfaceAlt,
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? AppColors.streak : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Icon(
            active ? Icons.local_fire_department_rounded : Icons.circle,
            color: active ? Colors.white : AppColors.border,
            size: active ? (compact ? 17 : 19) : 7,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: active ? AppColors.streak : AppColors.muted,
            fontWeight: FontWeight.w800,
            fontSize: compact ? 10 : 10.5,
          ),
        ),
      ],
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.78),
        fontWeight: FontWeight.w900,
        fontSize: 11.5,
        letterSpacing: 1.2,
      ),
    );
  }
}
