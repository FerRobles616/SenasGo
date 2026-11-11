import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/shared/models/lesson_model.dart';
import 'package:senasgo/shared/widgets/app_feature_icon.dart';
import 'package:senasgo/shared/widgets/app_ui.dart';

/// Cofre de recompensa local al completar una unidad.
///
/// La rareza depende del recorrido real, no del azar ni de compras. El cofre
/// se entrega una sola vez y la animación se puede desactivar desde el sistema.
class RewardChestView extends StatefulWidget {
  const RewardChestView({required this.lessonId, super.key});

  final String lessonId;

  @override
  State<RewardChestView> createState() => _RewardChestViewState();
}

class _RewardChestViewState extends State<RewardChestView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _opened = true);
      }
    });

  late final LessonModel? _lesson = _findLesson();
  late final int _unitIndex = _findUnitIndex();
  late final _ChestReward _reward = _buildReward();
  late bool _claimed = HiveService.isChestClaimed(_chestId);
  bool _opened = false;
  bool _claiming = false;

  String get _chestId => 'unit_${widget.lessonId}';

  LessonModel? _findLesson() {
    for (final lesson in HiveService.lessons) {
      if (lesson.id == widget.lessonId) return lesson;
    }
    return null;
  }

  int _findUnitIndex() {
    final lessons = HiveService.lessons;
    for (var i = 0; i < lessons.length; i++) {
      if (lessons[i].id == widget.lessonId) return i;
    }
    return 0;
  }

  _ChestReward _buildReward() {
    if (_unitIndex <= 0) {
      return const _ChestReward(
        rarity: _Rarity.common,
        xp: 20,
        freezes: 0,
      );
    }
    if (_unitIndex == 1) {
      return const _ChestReward(
        rarity: _Rarity.rare,
        xp: 30,
        freezes: 0,
      );
    }
    return const _ChestReward(
      rarity: _Rarity.epic,
      xp: 40,
      freezes: 1,
    );
  }

  bool get _complete {
    final lesson = _lesson;
    if (lesson == null || lesson.signIds.isEmpty) return false;
    final learned = HiveService.learnedSignIds;
    return lesson.signIds.every(learned.contains);
  }

  @override
  void initState() {
    super.initState();
    if (_claimed) {
      _opened = true;
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_claiming || !_complete) return;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    setState(() => _claiming = true);
    if (!_claimed) {
      await HiveService.claimChest(
        chestId: _chestId,
        xp: _reward.xp,
        freezes: _reward.freezes,
      );
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _claimed = true;
      _claiming = false;
    });
    if (reduceMotion) {
      _controller.value = 1;
      setState(() => _opened = true);
    } else {
      await _controller.forward();
    }
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _lesson;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final reward = _reward;
    final opened = _opened;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Cofre de unidad'),
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: _leave,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              children: [
                _RarityPill(rarity: reward.rarity),
                const SizedBox(height: 18),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _ChestArt(
                    progress: _controller.value,
                    opened: opened,
                    rarity: reward.rarity,
                    shake: !opened && !reduceMotion
                        ? math.sin(_controller.value * math.pi * 8) * 0.03
                        : 0,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  lesson?.title ?? 'Unidad',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _complete
                      ? opened
                          ? 'Recompensa reclamada'
                          : 'Completaste esta unidad.'
                      : 'Todavía faltan señas para completar esta unidad.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.muted, fontSize: 13.5, height: 1.35),
                ),
                if (opened) ...[
                  const SizedBox(height: 18),
                  _RewardCard(reward: reward),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _leave,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('VOLVER AL CAMINO'),
                  ),
                ] else ...[
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _complete && !_claiming ? _open : null,
                    icon: _claiming
                        ? const Icon(Icons.hourglass_top_rounded)
                        : _complete
                            ? const AppFeatureIcon(
                                asset: AppFeatureAssets.reward,
                                fallbackIcon: Icons.redeem_rounded,
                                color: Colors.white,
                                size: 22,
                              )
                            : const Icon(Icons.redeem_rounded),
                    label: Text(_claiming ? 'ABRIENDO…' : 'ABRIR COFRE'),
                  ),
                ],
                if (!_complete && lesson != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/lesson-guide/${lesson.id}'),
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text('VER LA GUÍA'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Rarity { common, rare, epic }

class _ChestReward {
  const _ChestReward({
    required this.rarity,
    required this.xp,
    required this.freezes,
  });

  final _Rarity rarity;
  final int xp;
  final int freezes;

  Color get color => switch (rarity) {
        _Rarity.common => AppColors.teal,
        _Rarity.rare => AppColors.sky,
        _Rarity.epic => AppColors.gold,
      };

  String get label => switch (rarity) {
        _Rarity.common => 'COFRE COMÚN',
        _Rarity.rare => 'COFRE RARO',
        _Rarity.epic => 'COFRE ÉPICO',
      };
}

class _RarityPill extends StatelessWidget {
  const _RarityPill({required this.rarity});

  final _Rarity rarity;

  @override
  Widget build(BuildContext context) {
    final reward = _ChestReward(
      rarity: rarity,
      xp: 0,
      freezes: 0,
    );
    return AppPill(
      icon: rarity == _Rarity.epic
          ? Icons.auto_awesome_rounded
          : Icons.workspace_premium_rounded,
      label: reward.label,
      color: reward.color,
      background: reward.color.withValues(alpha: 0.14),
    );
  }
}

class _ChestArt extends StatelessWidget {
  const _ChestArt({
    required this.progress,
    required this.opened,
    required this.rarity,
    required this.shake,
  });

  final double progress;
  final bool opened;
  final _Rarity rarity;
  final double shake;

  @override
  Widget build(BuildContext context) {
    final color = _ChestReward(rarity: rarity, xp: 0, freezes: 0).color;
    final glow = opened ? 1.0 : progress * 0.6;
    final lidLift = opened ? 1.0 : 0.0;
    return SizedBox(
      width: 280,
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo de rareza.
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 230 * (0.85 + glow * 0.15),
            height: 230 * (0.85 + glow * 0.15),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.30 * glow),
                  color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          if (opened)
            Positioned.fill(
              child: CustomPaint(
                painter: _RaysPainter(color.withValues(alpha: 0.6)),
              ),
            ),
          // Cofre.
          Transform.translate(
            offset: Offset(0, opened ? -6 : 0),
            child: Transform.rotate(
              angle: shake,
              child: Transform.scale(
                scale: 0.92 + progress * 0.08,
                child: SizedBox(
                  width: 190,
                  height: 155,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        width: 176,
                        height: 105,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color.lerp(color, Colors.white, 0.28)!,
                              color,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Color.lerp(color, Colors.black, 0.24)!,
                              width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                      ),
                      // Tapa.
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 520),
                        curve: Curves.easeOutBack,
                        bottom: 78 + 44 * lidLift,
                        child: Transform.rotate(
                          angle: -0.16 * lidLift,
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            width: 194,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color.lerp(color, Colors.white, 0.38)!,
                                  Color.lerp(color, Colors.white, 0.12)!,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Color.lerp(color, Colors.black, 0.22)!,
                                  width: 4),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: opened ? 52 : 48,
                        child: AnimatedOpacity(
                          opacity: opened ? 0 : 1,
                          duration: const Duration(milliseconds: 220),
                          child: Container(
                            width: 44,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4D6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Color.lerp(color, Colors.black, 0.24)!,
                                  width: 3),
                            ),
                            child: Icon(Icons.lock_rounded,
                                color: Color.lerp(color, Colors.black, 0.3),
                                size: 22),
                          ),
                        ),
                      ),
                      if (opened) ...[
                        for (final spark in const [
                          Offset(-100, -70),
                          Offset(95, -55),
                          Offset(-105, 20),
                          Offset(112, 28),
                          Offset(-45, -112),
                          Offset(55, -105),
                        ])
                          Positioned(
                            left: 95 + spark.dx,
                            top: 82 + spark.dy,
                            child: _Spark(color: color),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Spark extends StatelessWidget {
  const _Spark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutBack,
      builder: (context, value, _) => Transform.scale(
        scale: value,
        child: Icon(Icons.auto_awesome_rounded,
            color: color.withValues(alpha: 0.9), size: 16),
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  _RaysPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 12);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final start = center + Offset(math.cos(angle), math.sin(angle)) * 112;
      final end = center + Offset(math.cos(angle), math.sin(angle)) * 132;
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.reward});

  final _ChestReward reward;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: reward.color.withValues(alpha: 0.45)),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: reward.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: AppFeatureIcon(
                asset: AppFeatureAssets.reward,
                fallbackIcon: Icons.auto_awesome_rounded,
                color: reward.color,
                size: 34,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¡Recompensa desbloqueada!',
                    style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
                const SizedBox(height: 3),
                Text(
                  reward.freezes > 0
                      ? '+${reward.xp} XP y +${reward.freezes} protector de racha'
                      : '+${reward.xp} XP para tu camino',
                  style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          AppPill(
            icon: Icons.bolt_rounded,
            label: '+${reward.xp} XP',
            color: reward.color,
            background: reward.color.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }
}
