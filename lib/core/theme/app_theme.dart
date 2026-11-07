import 'package:flutter/material.dart';

/// Paleta de SeñasGo: azules luminosos, tinta profunda y acentos cálidos.
///
/// La intención es que la app se sienta amable y energética como un juego,
/// pero sin perder legibilidad: el azul guía la acción, el naranja celebra la
/// racha y el rojo solo aparece cuando hay algo que corregir.
///
/// Hay dos versiones, clara y oscura, con los mismos nombres: cada pantalla
/// pide `AppColors.ink` y recibe el tono del tema activo.
@immutable
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.onPrimary,
    required this.primary,
    required this.primaryDark,
    required this.primaryDeep,
    required this.primarySoft,
    required this.sky,
    required this.skySoft,
    required this.teal,
    required this.tealSoft,
    required this.indigo,
    required this.indigoSoft,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.outlineStrong,
    required this.ink,
    required this.muted,
    required this.navy,
    required this.cameraCard,
    required this.success,
    required this.successSoft,
    required this.successInk,
    required this.error,
    required this.errorSoft,
    required this.errorInk,
    required this.warning,
    required this.warningSoft,
    required this.warningInk,
    required this.streak,
    required this.heart,
    required this.gem,
    required this.gold,
    required this.locked,
    required this.lockedShade,
    required this.lockedInk,
  });

  final Brightness brightness;

  /// Texto/icono legible sobre [primary].
  final Color onPrimary;

  // Identidad principal
  final Color primary;
  final Color primaryDark;
  final Color primaryDeep;
  final Color primarySoft;
  final Color sky;
  final Color skySoft;
  final Color teal;
  final Color tealSoft;
  final Color indigo;
  final Color indigoSoft;

  // Superficies
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;

  /// Borde de controles interactivos. Debe distinguirse del fondo.
  final Color outlineStrong;
  final Color ink;
  final Color muted;
  final Color navy;
  final Color cameraCard;

  // Estados. Los "Ink" son el texto legible sobre su fondo "Soft".
  final Color success;
  final Color successSoft;
  final Color successInk;
  final Color error;
  final Color errorSoft;
  final Color errorInk;
  final Color warning;
  final Color warningSoft;
  final Color warningInk;

  // Gamificación (barra superior)
  final Color streak;
  final Color heart;
  final Color gem;
  final Color gold;

  // Nodos bloqueados del camino
  final Color locked;
  final Color lockedShade;
  final Color lockedInk;

  bool get isDark => brightness == Brightness.dark;

  static const light = AppPalette(
    brightness: Brightness.light,
    onPrimary: Colors.white,
    primary: Color(0xFF0F766E),
    primaryDark: Color(0xFF115E59),
    primaryDeep: Color(0xFF134E4A),
    primarySoft: Color(0xFFD9F5EE),
    sky: Color(0xFF0891B2),
    skySoft: Color(0xFFCFFAFE),
    teal: Color(0xFF0D9488),
    tealSoft: Color(0xFFCCFBF1),
    indigo: Color(0xFF14B8A6),
    indigoSoft: Color(0xFFD1FAE5),
    background: Color(0xFFF4FAF5),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE8F4EC),
    border: Color(0xFFCFE3D7),
    outlineStrong: Color(0xFF5F957F),
    ink: Color(0xFF10231C),
    muted: Color(0xFF5C786C),
    navy: Color(0xFF071A16),
    cameraCard: Color(0xFF0B241E),
    success: Color(0xFF10B981),
    successSoft: Color(0xFFD1FAE5),
    successInk: Color(0xFF047857),
    error: Color(0xFFE11D48),
    errorSoft: Color(0xFFFFE4E6),
    errorInk: Color(0xFF9F1239),
    warning: Color(0xFFD97706),
    warningSoft: Color(0xFFFEF3C7),
    warningInk: Color(0xFF92400E),
    streak: Color(0xFFF97316),
    heart: Color(0xFFE11D48),
    gem: Color(0xFF0D9488),
    gold: Color(0xFFFBBF24),
    locked: Color(0xFFDDEBE2),
    lockedShade: Color(0xFFC5DCCF),
    lockedInk: Color(0xFF7C9587),
  );

  /// Noche azul profunda: el azul de SeñasGo sube de brillo para mantener el
  /// contraste y los fondos "Soft" pasan a ser tintes oscuros.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    onPrimary: Color(0xFF04120F),
    primary: Color(0xFF2DD4BF),
    primaryDark: Color(0xFF14B8A6),
    primaryDeep: Color(0xFF5EEAD4),
    primarySoft: Color(0xFF12382D),
    sky: Color(0xFF22D3EE),
    skySoft: Color(0xFF083344),
    teal: Color(0xFF2DD4BF),
    tealSoft: Color(0xFF0F3B35),
    indigo: Color(0xFF5EEAD4),
    indigoSoft: Color(0xFF0E3B36),
    background: Color(0xFF04120F),
    surface: Color(0xFF0C2A22),
    surfaceAlt: Color(0xFF12382D),
    border: Color(0xFF1E5A48),
    outlineStrong: Color(0xFF4F8B74),
    ink: Color(0xFFF1FFF9),
    muted: Color(0xFF9FC4B6),
    navy: Color(0xFF020806),
    cameraCard: Color(0xFF071A16),
    success: Color(0xFF34D399),
    successSoft: Color(0xFF0F3A2D),
    successInk: Color(0xFF6EE7B7),
    error: Color(0xFFFB7185),
    errorSoft: Color(0xFF471A20),
    errorInk: Color(0xFFFDA4AF),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF3A2C0C),
    warningInk: Color(0xFFFCD34D),
    streak: Color(0xFFFB923C),
    heart: Color(0xFFFB7185),
    gem: Color(0xFF2DD4BF),
    gold: Color(0xFFFBBF24),
    locked: Color(0xFF1A3A30),
    lockedShade: Color(0xFF122C24),
    lockedInk: Color(0xFF6F9182),
  );
}

/// Colores de la paleta activa. La app la fija según el tema (ver `main.dart`)
/// y vuelve a construir las pantallas al cambiarlo.
class AppColors {
  const AppColors._();

  static AppPalette _palette = AppPalette.light;

  static AppPalette get palette => _palette;
  static bool get isDark => _palette.isDark;
  static Color get onPrimary => _palette.onPrimary;

  static void use(AppPalette palette) => _palette = palette;

  // Identidad principal
  static Color get primary => _palette.primary;
  static Color get primaryDark => _palette.primaryDark;
  static Color get primaryDeep => _palette.primaryDeep;
  static Color get primarySoft => _palette.primarySoft;
  static Color get sky => _palette.sky;
  static Color get skySoft => _palette.skySoft;
  static Color get teal => _palette.teal;
  static Color get tealSoft => _palette.tealSoft;
  static Color get indigo => _palette.indigo;
  static Color get indigoSoft => _palette.indigoSoft;

  // Superficies
  static Color get background => _palette.background;
  static Color get surface => _palette.surface;
  static Color get surfaceAlt => _palette.surfaceAlt;
  static Color get border => _palette.border;
  static Color get outlineStrong => _palette.outlineStrong;
  static Color get ink => _palette.ink;
  static Color get muted => _palette.muted;
  static Color get navy => _palette.navy;
  static Color get cameraCard => _palette.cameraCard;

  // Estados
  static Color get success => _palette.success;
  static Color get successSoft => _palette.successSoft;
  static Color get successInk => _palette.successInk;
  static Color get error => _palette.error;
  static Color get errorSoft => _palette.errorSoft;
  static Color get errorInk => _palette.errorInk;
  static Color get warning => _palette.warning;
  static Color get warningSoft => _palette.warningSoft;
  static Color get warningInk => _palette.warningInk;

  // Gamificación (barra superior)
  static Color get streak => _palette.streak;
  static Color get heart => _palette.heart;
  static Color get gem => _palette.gem;
  static Color get gold => _palette.gold;

  // Nodos bloqueados del camino
  static Color get locked => _palette.locked;
  static Color get lockedShade => _palette.lockedShade;
  static Color get lockedInk => _palette.lockedInk;

  // Sombras suaves reutilizables
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.28)
              : primary.withValues(alpha: 0.08),
          blurRadius: 22,
          offset: const Offset(0, 9),
        ),
      ];
}

/// Color de cada unidad del camino (cara del botón + borde inferior 3D).
///
/// Se mantiene dentro de la familia azul, con un acento ámbar para que el
/// camino no se vuelva monótono.
class UnitPalette {
  const UnitPalette(this.face, this.shade);

  final Color face;
  final Color shade;

  static const List<UnitPalette> all = [
    UnitPalette(Color(0xFF0F766E), Color(0xFF115E59)), // selva
    UnitPalette(Color(0xFF0D9488), Color(0xFF0B7A70)), // turquesa
    UnitPalette(Color(0xFFB45309), Color(0xFF92400E)), // jaguar
    UnitPalette(Color(0xFFBE123C), Color(0xFF9F1239)), // coral
    UnitPalette(Color(0xFF047857), Color(0xFF065F46)), // esmeralda
  ];

  static UnitPalette of(int unitIndex) => all[unitIndex % all.length];
}

class AppTheme {
  const AppTheme._();

  static final ThemeData light = _build(AppPalette.light);
  static final ThemeData dark = _build(AppPalette.dark);

  static ThemeData _build(AppPalette p) {
    final scheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: p.brightness,
    ).copyWith(
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.primarySoft,
      onPrimaryContainer: p.primaryDeep,
      secondary: p.sky,
      onSecondary: p.navy,
      secondaryContainer: p.skySoft,
      onSecondaryContainer: p.isDark ? p.ink : p.navy,
      tertiary: p.teal,
      error: p.error,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.ink,
      surfaceContainerHighest: p.surfaceAlt,
      outline: p.border,
      outlineVariant: p.border,
    );

    const rounded16 = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      // Tipografía redondeada y gruesa, de lectura muy clara.
      fontFamily: 'Nunito',
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: JunglePageTransitionsBuilder(),
          TargetPlatform.iOS: JunglePageTransitionsBuilder(),
          TargetPlatform.linux: JunglePageTransitionsBuilder(),
          TargetPlatform.macOS: JunglePageTransitionsBuilder(),
          TargetPlatform.windows: JunglePageTransitionsBuilder(),
        },
      ),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Nunito',
          color: p.ink,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
        iconTheme: IconThemeData(color: p.ink),
      ),
      textTheme: TextTheme(
        headlineLarge:
            TextStyle(color: p.ink, fontWeight: FontWeight.w900, height: 1.08),
        headlineMedium:
            TextStyle(color: p.ink, fontWeight: FontWeight.w900, height: 1.1),
        headlineSmall:
            TextStyle(color: p.ink, fontWeight: FontWeight.w900, height: 1.12),
        titleLarge:
            TextStyle(color: p.ink, fontWeight: FontWeight.w900, height: 1.15),
        titleMedium:
            TextStyle(color: p.ink, fontWeight: FontWeight.w800, height: 1.2),
        bodyLarge: TextStyle(color: p.ink, height: 1.4),
        bodyMedium: TextStyle(color: p.ink, height: 1.4),
        bodySmall: TextStyle(color: p.muted, height: 1.35),
        labelLarge: const TextStyle(fontWeight: FontWeight.w800),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          textStyle:
              const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: p.primary,
          side: BorderSide(color: p.outlineStrong, width: 1.8),
          shape: rounded16,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          shape: rounded16,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: TextStyle(color: p.muted, fontWeight: FontWeight.w600),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: p.outlineStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: p.outlineStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: p.error),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.primarySoft,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            color: selected ? p.primary : p.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 25,
            color: selected ? p.primary : p.muted,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.primary,
        disabledColor: p.locked,
        side: BorderSide(color: p.outlineStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle:
            TextStyle(color: p.ink, fontWeight: FontWeight.w800, fontSize: 13),
        secondaryLabelStyle: TextStyle(
            color: p.onPrimary, fontWeight: FontWeight.w800, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // En oscuro el azul noche se perdería contra el fondo.
        backgroundColor: p.isDark ? p.surfaceAlt : p.navy,
        contentTextStyle: const TextStyle(
            fontFamily: 'Nunito',
            color: Colors.white,
            fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        modalBarrierColor: p.navy.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        titleTextStyle: TextStyle(
            fontFamily: 'Nunito',
            color: p.ink,
            fontSize: 22,
            fontWeight: FontWeight.w900),
        contentTextStyle: TextStyle(
            fontFamily: 'Nunito', color: p.muted, fontSize: 14, height: 1.4),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: p.border),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.primarySoft,
        circularTrackColor: p.primarySoft,
      ),
      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: p.ink),
      listTileTheme: ListTileThemeData(
        iconColor: p.primary,
        textColor: p.ink,
      ),
    );
  }
}

/// Transiciones entre pantallas, al estilo "fade through" de Material.
///
/// Las pantallas tienen fondo transparente (el degradado de [JungleBackdrop]
/// queda detrás de todas), así que nunca se muestran dos a la vez: la que se
/// va desaparece en el primer tercio y recién entonces aparece la nueva. Sin
/// eso el contenido de ambas se superponía como un fantasma.
///
/// - Pestañas principales: solo fundido y un leve zoom (no hay jerarquía
///   entre ellas); la barra de navegación queda fija (Hero en AppBottomNav).
/// - Lección, práctica, quiz y profesor: suben desde abajo, como un modo
///   aparte del que se vuelve.
/// - El resto (detalle, ayuda, perfil…): avanzan de derecha a izquierda.
class JunglePageTransitionsBuilder extends PageTransitionsBuilder {
  const JunglePageTransitionsBuilder();

  /// Rutas de la barra inferior (nombre = path de GoRoute).
  static const tabRoutes = {
    '/',
    '/library',
    '/challenges',
    '/progress',
    '/help',
    '/streak',
  };

  /// Flujos a pantalla completa que se abren "hacia arriba".
  static const flowRoutes = {
    '/lesson/:id',
    '/lesson-guide/:id',
    '/practice',
    '/quiz',
    '/teacher/:signId',
  };

  @override
  Duration get transitionDuration => const Duration(milliseconds: 340);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final name = route.settings.name;
    final axis = tabRoutes.contains(name)
        ? _Axis.none
        : flowRoutes.contains(name)
            ? _Axis.vertical
            : _Axis.horizontal;
    return _FadeThrough(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      axis: axis,
      child: child,
    );
  }
}

enum _Axis { none, horizontal, vertical }

class _FadeThrough extends StatelessWidget {
  const _FadeThrough({
    required this.animation,
    required this.secondaryAnimation,
    required this.axis,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final _Axis axis;
  final Widget child;

  // La pantalla saliente se apaga en el primer 35 %; la entrante aparece
  // después. Así nunca hay dos contenidos superpuestos.
  static const _outEnd = 0.35;

  Offset _shift(double t, double distance) => switch (axis) {
        _Axis.none => Offset.zero,
        _Axis.horizontal => Offset(distance * t, 0),
        _Axis.vertical => Offset(0, distance * t),
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      child: child,
      builder: (context, child) {
        // Entrada (o salida al volver atrás).
        final a = animation.value;
        final inT = Curves.easeOutCubic
            .transform(((a - _outEnd) / (1 - _outEnd)).clamp(0.0, 1.0));
        final moveIn = 1 - Curves.easeOutCubic.transform(a);
        // Salida cuando otra pantalla se abre encima (o regreso).
        final s = secondaryAnimation.value;
        final outT =
            Curves.easeInCubic.transform((s / _outEnd).clamp(0.0, 1.0));
        final moveOut = Curves.easeInOutCubic.transform(s);

        final opacity = inT * (1 - outT);
        final inDist = axis == _Axis.vertical ? 56.0 : 36.0;
        final offset = _shift(moveIn, inDist) - _shift(moveOut, 24);
        final scale =
            axis == _Axis.none ? (0.97 + 0.03 * inT) * (1 + 0.02 * outT) : 1.0;
        return IgnorePointer(
          // Mientras se va, la pantalla saliente no recibe toques.
          ignoring: opacity < 1 && s > 0,
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: offset,
              child: Transform.scale(scale: scale, child: child),
            ),
          ),
        );
      },
    );
  }
}

/// Fondo orgánico compartido por las pantallas. El degradado es estático para
/// no gastar batería; el movimiento se reserva para las interacciones.
class JungleBackdrop extends StatelessWidget {
  const JungleBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnimatedContainer(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.85, -0.9),
          radius: 1.35,
          colors: dark
              ? const [Color(0xFF0B3B2E), Color(0xFF04120F)]
              : const [Color(0xFFE0F4E8), Color(0xFFF4FAF5)],
          stops: const [0, 0.92],
        ),
      ),
      child: child,
    );
  }
}
