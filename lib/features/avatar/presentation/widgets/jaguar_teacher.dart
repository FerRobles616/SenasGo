import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:senasgo/core/services/device_performance.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/avatar/data/sign_animation_catalog.dart';
import 'package:senasgo/features/avatar/domain/teacher_view.dart';
import 'package:senasgo/features/avatar/presentation/widgets/pro_sign_language_avatar.dart';

export 'package:senasgo/features/avatar/domain/teacher_view.dart';

/// Profesor jaguareté en 3D (GLB con animaciones por seña).
///
/// - Usa `model_viewer_plus`, que empaqueta model-viewer y funciona offline.
/// - En Android/iOS las animaciones y la cámara se cambian por JavaScript,
///   sin recargar el modelo.
/// - En web se reconstruye el visor con una clave distinta (el canal JS de la
///   plataforma no está disponible).
/// - Si el equipo tiene poca RAM o el visor falla, muestra el póster y ofrece
///   el avatar 2D procedural como respaldo.
class JaguarTeacher extends StatefulWidget {
  const JaguarTeacher({
    required this.signId,
    this.height = 380,
    this.initialView = TeacherView.body,
    this.showControls = true,
    this.showHeader = true,
    this.onExpand,
    this.borderRadius = 28,
    this.clip,
    this.replayToken = 0,
    super.key,
  });

  final String signId;
  final double height;
  final TeacherView initialView;
  final bool showControls;
  final bool showHeader;
  final VoidCallback? onExpand;
  final double borderRadius;

  /// Clip concreto a reproducir. Si es null se usa el clip completo de la seña.
  final String? clip;

  /// Cambiar este valor vuelve a reproducir el clip actual.
  final int replayToken;

  /// Clips incluidos en teacher.glb. Si una seña no tiene clip se usa idle.
  static const Set<String> clipIds = {
    'saludo_hola',
    'saludo_chau',
    'saludo_saludos',
    'numero_uno',
    'numero_dos',
    'numero_tres',
    'basico_gracias',
    'basico_si',
    'basico_no',
    'basico_por_favor',
    'idle',
  };

  @override
  State<JaguarTeacher> createState() => _JaguarTeacherState();
}

class _JaguarTeacherState extends State<JaguarTeacher> {
  late TeacherView _view = widget.initialView;
  late bool _fallback = DevicePerformance.isLowMemory;
  bool _show2d = false;
  bool _ready = false;
  int _replay = 0;
  // El controlador es específico de la implementación móvil; en web no existe.
  dynamic _web;
  Timer? _readyTimer;

  // En web los assets de Flutter se publican bajo assets/assets/..., y
  // model-viewer recibe la ruta tal cual (sin el prefijo de rootBundle).
  static String get _asset =>
      kIsWeb ? 'assets/assets/models/teacher.glb' : 'assets/models/teacher.glb';
  static const _poster = 'assets/images/teacher_poster.png';

  String get _clip {
    final requested = widget.clip;
    if (requested != null && requested.isNotEmpty) return requested;
    return JaguarTeacher.clipIds.contains(widget.signId)
        ? widget.signId
        : 'idle';
  }

  String get _orbit => _view == TeacherView.hands
      // Primer plano de mano con contexto: la cabeza y el torso siguen
      // visibles para que la seña no se lea como un gesto aislado.
      ? '0deg 82deg 1.42m'
      // Retrato de medio cuerpo: cabeza, hombros, pecho y manos. El objetivo
      // deja fuera las piernas sin recortar la cara ni la mano que firma; la
      // distancia mantiene ambos brazos dentro del encuadre al gesticular.
      : '0deg 80deg 1.95m';

  String get _target {
    if (_view == TeacherView.body) return '0m 1.42m 0m';
    // Las animaciones `_forma` de todas las señas muestran la mano en el
    // mismo punto, frente al pecho (`show` en tool/avatar/generate.py,
    // llevado al cuerpo del profesor por BodyMap). Medidas en el GLB.
    // Enfocar la mano (no el pecho) es lo que hace útil el primer plano.
    return '-0.13m 1.42m 0.33m';
  }

  String get _fov => _view == TeacherView.hands ? '32deg' : '34deg';

  @override
  void initState() {
    super.initState();
    if (!_fallback) _startReadyTimer();
  }

  void _startReadyTimer() {
    _readyTimer?.cancel();
    // Si el visor no avisa (web o un WebView lento), ocultamos el póster
    // igual para no tapar el modelo cuando termine de cargar.
    _readyTimer = Timer(Duration(seconds: kIsWeb ? 3 : 7), () {
      if (mounted && !_ready) setState(() => _ready = true);
    });
  }

  @override
  void didUpdateWidget(covariant JaguarTeacher old) {
    super.didUpdateWidget(old);
    final signChanged = old.signId != widget.signId;
    final clipChanged = old.clip != widget.clip;
    final tokenChanged = old.replayToken != widget.replayToken;
    final viewChanged = old.initialView != widget.initialView;
    if (!signChanged && !clipChanged && !tokenChanged && !viewChanged) {
      return;
    }
    if (viewChanged) _view = widget.initialView;

    if (kIsWeb) {
      setState(() {
        // El póster solo cubre la carga inicial o el cambio de seña. Al pasar
        // de paso no lo mostramos: taparía el modelo nuevo con una pose vieja.
        if (signChanged) _ready = false;
        _replay++;
      });
      if (signChanged) _startReadyTimer();
      return;
    }

    if (signChanged || clipChanged) {
      _playClip();
      _applyView();
    } else if (viewChanged) {
      _applyView();
    } else if (tokenChanged) {
      _replayAnimation();
    }
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    super.dispose();
  }

  void _onMessage(dynamic message) {
    final value = message.message;
    if (!mounted) return;
    if (value == 'ready') {
      setState(() => _ready = true);
      _readyTimer?.cancel();
      _playClip();
      _applyView();
    } else if (value.startsWith('error')) {
      setState(() => _fallback = true);
      _readyTimer?.cancel();
    }
  }

  Future<void> _playClip() async {
    if (kIsWeb) return;
    final web = _web;
    if (web == null) return;
    try {
      await web.runJavaScript(
          "window.teacherPlay && window.teacherPlay('${_clip.replaceAll("'", "")}');");
    } catch (_) {
      // El respaldo visual ya está disponible.
    }
  }

  Future<void> _applyView() async {
    if (kIsWeb) return;
    final web = _web;
    if (web == null) return;
    try {
      await web.runJavaScript(
          "window.teacherView && window.teacherView('$_orbit', '$_target', '$_fov');");
    } catch (_) {
      // Sin acción: la cámara se queda en la vista anterior.
    }
  }

  Future<void> _replayAnimation() async {
    if (kIsWeb) {
      setState(() {
        _ready = false;
        _replay++;
      });
      _startReadyTimer();
      return;
    }
    final web = _web;
    if (web == null) {
      setState(() => _replay++);
      return;
    }
    try {
      await web
          .runJavaScript('window.teacherReplay && window.teacherReplay();');
    } catch (_) {
      // Nada: se puede tocar de nuevo.
    }
  }

  void _setView(TeacherView view) {
    if (view == _view) return;
    setState(() {
      _view = view;
      if (kIsWeb) _ready = false;
    });
    if (kIsWeb) {
      _startReadyTimer();
    } else {
      _applyView();
    }
  }

  static const _relatedJs = '''
const mv = document.querySelector('model-viewer');
const send = (m) => { try { if (window.TeacherStatus) TeacherStatus.postMessage(m); } catch (e) {} };
mv.addEventListener('load', () => send('ready'));
mv.addEventListener('error', () => send('error'));
// Enseñar no es un loop: al terminar, el profesor sostiene la última pose.
mv.addEventListener('finished', () => {
  try { mv.pause(); } catch (e) {}
  send('finished');
});
window.teacherPlay = (name) => {
  try {
    mv.animationName = name;
    mv.currentTime = 0;
    mv.play();
  } catch (e) { send('error'); }
};
window.teacherReplay = () => {
  try { mv.currentTime = 0; mv.play(); } catch (e) {}
};
window.teacherView = (orbit, target, fov) => {
  try {
    mv.cameraOrbit = orbit;
    mv.cameraTarget = target;
    mv.fieldOfView = fov;
    mv.jumpCameraToGoal();
  } catch (e) {}
};
''';

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: radius,
        // Escenario oscuro: las manos claras del jaguar ganan contraste y la
        // atención se va al gesto, no a la armadura ni al fondo.
        gradient: const RadialGradient(
          center: Alignment(0, -0.18),
          radius: 1.08,
          colors: [Color(0xFF0B3B2E), Color(0xFF071A16), Color(0xFF050B16)],
          stops: [0, 0.56, 1],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!_fallback)
            ModelViewer(
              key: kIsWeb
                  ? ValueKey('teacher-$_clip-${_view.name}-$_replay')
                  : const ValueKey('teacher-3d'),
              src: _asset,
              alt: 'Profesor jaguareté demostrando una seña de LSPy',
              loading: Loading.eager,
              reveal: Reveal.auto,
              // El profesor no es un visor libre: la cámara la controla la
              // demostración para que el estudiante mire donde importa.
              cameraControls: false,
              disablePan: true,
              disableTap: true,
              touchAction: TouchAction.panY,
              disableZoom: true,
              autoRotate: false,
              interactionPrompt: InteractionPrompt.none,
              cameraOrbit: _orbit,
              cameraTarget: _target,
              // Sin este límite model-viewer no permite acercarse más que el
              // tamaño del modelo y la vista "Manos" queda a media distancia.
              minCameraOrbit: 'auto auto 0.35m',
              fieldOfView: _fov,
              exposure: 1.08,
              shadowIntensity: 0.62,
              animationName: _clip,
              animationCrossfadeDuration: 350,
              autoPlay: true,
              backgroundColor: Colors.transparent,
              relatedJs: _relatedJs,
              javascriptChannels: {
                JavascriptChannel(
                  'TeacherStatus',
                  onMessageReceived: _onMessage,
                ),
              },
              onWebViewCreated: (controller) => _web = controller,
              debugLogging: false,
            ),
          // Póster encima mientras carga: evita el flash blanco del WebView.
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _ready && !_fallback ? 0 : 1,
              duration: const Duration(milliseconds: 420),
              child: Image.asset(
                _poster,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          if (_fallback) _fallbackContent(radius),
          if (!_fallback && !_ready)
            Positioned(
              left: 18,
              right: 18,
              bottom: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: Colors.white38,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
          if (widget.showHeader) _header(),
          if (widget.showControls && !_fallback) _controls(),
        ],
      ),
    );
  }

  Widget _header() {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Pill(
            icon: Icons.school_rounded,
            text: 'PROFESOR JAGUARETÉ',
            color: AppColors.primary,
          ),
          const Spacer(),
          _Pill(
            icon: Icons.pending_outlined,
            text: 'POR VALIDAR',
            color: AppColors.warningInk,
            background: Color(0xFFFFF1E6),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: SegmentedButton<TeacherView>(
                segments: const [
                  ButtonSegment(
                    value: TeacherView.body,
                    label: Text('Torso'),
                    icon: Icon(Icons.accessibility_new_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: TeacherView.hands,
                    label: Text('Manos'),
                    icon: Icon(Icons.back_hand_outlined, size: 18),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (s) => _setView(s.first),
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStateProperty.all(const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800)),
                  side: WidgetStateProperty.all(
                      BorderSide(color: AppColors.border)),
                  backgroundColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? AppColors.primarySoft
                          : AppColors.surface),
                  foregroundColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? AppColors.primary
                          : AppColors.muted),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Repetir seña',
              onPressed: _replayAnimation,
              icon: const Icon(Icons.replay_rounded),
              color: AppColors.primary,
              visualDensity: VisualDensity.compact,
            ),
            if (widget.onExpand != null)
              IconButton(
                tooltip: 'Ver en pantalla completa',
                onPressed: widget.onExpand,
                icon: const Icon(Icons.fullscreen_rounded),
                color: AppColors.primary,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackContent(BorderRadius radius) {
    if (_show2d) {
      return ClipRRect(
        borderRadius: radius,
        child: ProSignLanguageAvatar(
          animation: SignAnimationCatalog.of(widget.signId),
          height: widget.height,
          showControls: false,
        ),
      );
    }
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Color(0xE6FFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Modo de compatibilidad',
                  style: TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Este equipo no puede mostrar el profesor 3D. Podés ver la '
                  'demostración con el avatar 2D.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () => setState(() => _show2d = true),
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: const Text('Ver demostración 2D'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.text,
    required this.color,
    this.background,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3)),
        ],
      ),
    );
  }
}
