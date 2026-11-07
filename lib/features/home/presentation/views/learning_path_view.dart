import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/home/domain/learning_path.dart';
import 'package:senasgo/features/home/presentation/widgets/lesson_node.dart';
import 'package:senasgo/features/home/presentation/widgets/mascot_tooltip.dart';
import 'package:senasgo/features/home/presentation/widgets/path_painter.dart';
import 'package:senasgo/features/home/presentation/widgets/top_stats_bar.dart';
import 'package:senasgo/features/home/presentation/widgets/unit_header.dart';
import 'package:senasgo/shared/widgets/app_bottom_nav.dart';
import 'package:senasgo/shared/widgets/jaguarete_mascot.dart';
import 'package:senasgo/shared/widgets/pushable_button.dart';

/// Pantalla principal: camino de aprendizaje vertical estilo Duolingo.
class LearningPathView extends StatefulWidget {
  const LearningPathView({this.pathLoader, super.key});

  /// Permite inyectar datos en tests; por defecto lee Hive.
  final LearningPath Function()? pathLoader;

  @override
  State<LearningPathView> createState() => _LearningPathViewState();
}

class _LearningPathViewState extends State<LearningPathView> {
  late LearningPath _path = _load();

  /// Marca la seña actual para llevarla al centro de la pantalla.
  final GlobalKey _currentKey = GlobalKey();

  /// Globo abierto bajo un nodo (o null) y el enganche de cada nodo.
  OverlayEntry? _popover;
  final Map<String, LayerLink> _links = {};

  LayerLink _linkFor(PathNode node) =>
      _links.putIfAbsent('${node.lessonId}/${node.sign.id}', LayerLink.new);

  void _closePopover() {
    _popover?.remove();
    _popover?.dispose();
    _popover = null;
  }

  @override
  void dispose() {
    _closePopover();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _scrollToCurrent();
  }

  /// En la primera unidad no hace falta desplazar: la seña actual ya queda a
  /// la vista y así el encabezado de la unidad no se corta en pantallas bajas.
  bool get _currentIsInFirstUnit {
    final current = _path.current;
    if (current == null) return true;
    return _path.units.isEmpty || _path.units.first.nodes.contains(current);
  }

  /// Como en Duolingo: al abrir (o al volver de practicar) la seña que toca
  /// queda a la vista, sin tener que buscarla.
  void _scrollToCurrent() {
    if (_currentIsInFirstUnit) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _currentKey.currentContext;
      if (!mounted || ctx == null) return;
      final reduceMotion =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  LearningPath _load() => (widget.pathLoader ?? LearningPath.fromStorage)();

  /// Al volver de practicar, la biblioteca o el progreso, se refresca el camino.
  Future<void> _open(String route) async {
    _closePopover();
    await context.push(route);
    if (!mounted) return;
    setState(() => _path = _load());
    _scrollToCurrent();
  }

  void _onNodeTap(PathNode node, PathUnit unit, BuildContext nodeContext) {
    if (node.status == NodeStatus.locked) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
            '🔒 Completá "${_path.current?.sign.name ?? 'la seña anterior'}" '
            'para desbloquear "${node.sign.name}".',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ));
      return;
    }
    _showPopover(node, unit, nodeContext);
  }

  /// Globo bajo el nodo tocado: queda enganchado al nodo (acompaña el
  /// desplazamiento) y se corre de lado si el nodo está cerca de un borde,
  /// sin que la flecha deje de señalarlo.
  Future<void> _showPopover(
      PathNode node, PathUnit unit, BuildContext nodeContext) async {
    _closePopover();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // Deja lugar debajo del nodo para que el globo entre en pantalla.
    await Scrollable.ensureVisible(
      nodeContext,
      alignment: 0.3,
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    if (!mounted || !nodeContext.mounted) return;
    final box = nodeContext.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final nodeX = box.localToGlobal(box.size.center(Offset.zero)).dx;
    final width = math.min(screenWidth - 32, 340.0);
    final idealLeft = nodeX - width / 2;
    final left = idealLeft.clamp(16.0, screenWidth - 16 - width);
    final stats = _path.stats;
    _popover = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // Tocar o arrastrar fuera del globo lo cierra; el gesto sigue de
          // largo, así se puede desplazar o tocar otro nodo de una vez.
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _closePopover(),
            ),
          ),
          CompositedTransformFollower(
            link: _linkFor(node),
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            offset: Offset(left - idealLeft, 6),
            child: _NodePopover(
              width: width,
              arrowX: nodeX - left,
              node: node,
              unit: unit,
              position: unit.nodes.indexOf(node) + 1,
              energy: stats.energy,
              nextEnergyIn: stats.nextEnergyIn,
              reduceMotion: reduceMotion,
              onPractice: () => _open(
                  '/practice?lesson=${node.lessonId}&sign=${node.sign.id}'),
              onLearn: () =>
                  _open('/lesson/${node.lessonId}?sign=${node.sign.id}'),
              onGuide: () => _open('/lesson-guide/${node.lessonId}'),
              onQuiz: () => _open('/quiz?lesson=${node.lessonId}'),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_popover!);
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    final current = path.current;
    PathUnit? currentUnit;
    if (current != null) {
      for (final unit in path.units) {
        if (unit.nodes.contains(current)) {
          currentUnit = unit;
          break;
        }
      }
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        // Pocas unidades: se construyen todas para poder ubicar la actual.
        scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
        slivers: [
          TopStatsBar(stats: path.stats),
          for (final unit in path.units) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              sliver: SliverToBoxAdapter(
                child: _Centered(
                  child: UnitHeader(
                    unit: unit,
                    onGuide: () => _open('/lesson-guide/${unit.lesson.id}'),
                    currentSign:
                        currentUnit?.index == unit.index ? current : null,
                    onStart: currentUnit?.index == unit.index && current != null
                        ? () => _open(
                            '/practice?lesson=${current.lessonId}&sign=${current.sign.id}')
                        : null,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _Centered(
                child: _UnitPath(
                  unit: unit,
                  currentKey: _currentKey,
                  onNodeTap: (n, ctx) => _onNodeTap(n, unit, ctx),
                  linkFor: _linkFor,
                  onMilestone: () => _open('/lesson-guide/${unit.lesson.id}'),
                ),
              ),
            ),
          ],
          if (path.current == null)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: _Centered(
                  child: MascotTooltip(
                    mood: MascotMood.cheering,
                    messages: [
                      '¡Completaste todo el camino! Repasá cualquier seña cuando quieras.'
                    ],
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 0,
        onSelected: (i) {
          if (i == 1) _open('/library');
          if (i == 2) _open('/challenges');
          if (i == 3) _open('/progress');
          if (i == 4) _open('/help');
        },
      ),
    );
  }
}

/// Ancho máximo en tablets: el camino queda centrado y legible.
class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: child,
        ),
      );
}

/// Nodos de una unidad en zigzag, unidos por el camino y cerrados por un cofre.
class _UnitPath extends StatelessWidget {
  const _UnitPath({
    required this.unit,
    required this.onNodeTap,
    required this.linkFor,
    required this.currentKey,
    required this.onMilestone,
  });

  final PathUnit unit;
  final void Function(PathNode node, BuildContext nodeContext) onNodeTap;
  final LayerLink Function(PathNode node) linkFor;
  final GlobalKey currentKey;
  final VoidCallback onMilestone;

  /// Desplazamiento horizontal del zigzag (fracción de la amplitud).
  static const List<double> _wave = [
    0,
    0.55,
    0.85,
    0.55,
    0,
    -0.55,
    -0.85,
    -0.55
  ];

  @override
  Widget build(BuildContext context) {
    final palette = UnitPalette.of(unit.index);
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final amplitude = math.min(width * 0.24, 110.0);
        final children = <Widget>[];
        final centers = <Offset>[];
        var y = 8.0;
        var reachedUntil = -1;

        for (var i = 0; i < unit.nodes.length; i++) {
          final node = unit.nodes[i];
          final isCurrent = node.status == NodeStatus.current;
          final cx =
              width / 2 + amplitude * _wave[node.indexInPath % _wave.length];
          centers.add(Offset(
            cx,
            y +
                LessonNode.slotHeightFor(current: isCurrent) -
                (isCurrent ? 65 : 60),
          ));
          if (node.status != NodeStatus.locked) reachedUntil = i;
          children.add(Positioned(
            left: cx - 70,
            top: y,
            child: Builder(
              builder: (nodeContext) => LessonNode(
                key: isCurrent ? currentKey : null,
                node: node,
                palette: palette,
                link: linkFor(node),
                onTap: () => onNodeTap(node, nodeContext),
              ),
            ),
          ));
          y += LessonNode.slotHeightFor(current: isCurrent) - 18;
        }

        // Cofre de unidad: un hito visual al terminar todas las señas.
        final chestCenter = Offset(width / 2, y + 34);
        centers.add(chestCenter);
        if (unit.completedCount == unit.nodes.length && unit.nodes.isNotEmpty) {
          reachedUntil = centers.length - 1;
        }
        children.add(Positioned(
          left: width / 2 - 72,
          top: y - 4,
          child: _UnitChest(
            palette: palette,
            complete: unit.completedCount == unit.nodes.length &&
                unit.nodes.isNotEmpty,
            onTap: onMilestone,
          ),
        ));
        y += 128;

        return SizedBox(
          height: y + 28,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration:
                      MediaQuery.maybeDisableAnimationsOf(context) ?? false
                          ? Duration.zero
                          : const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => CustomPaint(
                    painter: PathPainter(
                      points: centers,
                      reachedUntil: reachedUntil,
                      color: palette.face,
                      progress: value,
                    ),
                  ),
                ),
              ),
              ...children,
            ],
          ),
        );
      },
    );
  }
}

/// Cofre que cierra una unidad y lleva a su guía.
class _UnitChest extends StatelessWidget {
  const _UnitChest({
    required this.palette,
    required this.complete,
    required this.onTap,
  });

  final UnitPalette palette;
  final bool complete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = complete ? AppColors.gold : AppColors.lockedShade;
    return Semantics(
      button: true,
      label: complete
          ? 'Cofre de la unidad completado. Abrir la guía.'
          : 'Cofre de la unidad bloqueado. Completá todas las señas para abrirlo.',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 144,
          child: Column(
            children: [
              Container(
                width: 68,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: complete
                        ? [Color(0xFFFFE08A), AppColors.gold]
                        : [AppColors.locked, AppColors.lockedShade],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: complete
                        ? const Color(0xFFD99A00)
                        : AppColors.lockedShade,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  complete ? Icons.redeem_rounded : Icons.lock_rounded,
                  color: complete ? const Color(0xFF7A4B00) : Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 5),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    complete ? 'UNIDAD COMPLETA' : 'COFRE',
                    style: TextStyle(
                      color:
                          complete ? AppColors.warningInk : AppColors.lockedInk,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Globo de la seña tocada en el camino: cara del color de la unidad, flecha
/// hacia el nodo y las tres acciones (practicar, demostración, guía).
class _NodePopover extends StatelessWidget {
  const _NodePopover({
    required this.width,
    required this.arrowX,
    required this.node,
    required this.unit,
    required this.position,
    required this.energy,
    required this.nextEnergyIn,
    required this.reduceMotion,
    required this.onPractice,
    required this.onLearn,
    required this.onGuide,
    required this.onQuiz,
  });

  final double width;

  /// Posición horizontal del nodo dentro del globo (punta de la flecha).
  final double arrowX;
  final PathNode node;
  final PathUnit unit;
  final int position;
  final int energy;
  final Duration? nextEnergyIn;
  final bool reduceMotion;
  final VoidCallback onPractice;
  final VoidCallback onLearn;
  final VoidCallback onGuide;

  /// Repaso rápido sin cámara de la lección.
  final VoidCallback onQuiz;

  @override
  Widget build(BuildContext context) {
    final palette = UnitPalette.of(unit.index);
    final done = node.status == NodeStatus.completed;
    final noEnergy = energy == 0;
    final radius = BorderRadius.circular(22);
    final label = noEnergy
        ? 'SIN ENERGÍA'
        : done
            ? 'REPASAR · +${AppConstants.xpPerCorrectSign} XP'
            : 'EMPEZAR · +${AppConstants.xpPerCorrectSign} XP';

    final card = SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                EdgeInsets.only(left: (arrowX - 11).clamp(20.0, width - 42)),
            child: CustomPaint(
              size: const Size(22, 11),
              painter: _ArrowPainter(palette.face),
            ),
          ),
          Material(
            color: palette.face,
            borderRadius: radius,
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${unit.lesson.title.toUpperCase()} · '
                    'SEÑA $position DE ${unit.nodes.length}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    node.sign.name,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    node.sign.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.battery_charging_full_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          noEnergy
                              ? 'Sin energía · recuperás una en ${(nextEnergyIn?.inMinutes ?? 0) + 1} min'
                              : '$energy de energía disponible',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PushableButton(
                    onPressed: noEnergy ? null : onPractice,
                    color: noEnergy
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.white,
                    shadowColor: noEnergy
                        ? Colors.transparent
                        : Color.lerp(Colors.white, palette.shade, 0.45)!,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: noEnergy ? Colors.white : palette.shade,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _PopoverAction(
                          icon: Icons.play_circle_outline_rounded,
                          label: 'Demostración',
                          onTap: onLearn,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PopoverAction(
                          icon: Icons.quiz_rounded,
                          label: 'Repaso',
                          onTap: onQuiz,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton.icon(
                      onPressed: onGuide,
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.white),
                      icon: const Icon(Icons.menu_book_rounded, size: 17),
                      label: const Text('Ver la guía de la lección'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (reduceMotion) return card;
    // Crece desde la flecha, con un rebote corto.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.85 + 0.15 * t,
          alignment: Alignment((arrowX / width) * 2 - 1, -1),
          child: child,
        ),
      ),
      child: card,
    );
  }
}

/// Acción secundaria del globo: botón translúcido sobre el color de la unidad.
class _PopoverAction extends StatelessWidget {
  const _PopoverAction(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Flecha del globo que apunta hacia arriba, al nodo.
class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
