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
    primary: Color(0xFF2563EB),
    primaryDark: Color(0xFF1D4ED8),
    primaryDeep: Color(0xFF1E3A8A),
    primarySoft: Color(0xFFE8F1FF),
    sky: Color(0xFF38BDF8),
    skySoft: Color(0xFFE0F2FE),
    teal: Color(0xFF14B8A6),
    tealSoft: Color(0xFFCCFBF1),
    indigo: Color(0xFF6366F1),
    indigoSoft: Color(0xFFE0E7FF),
    background: Color(0xFFF4F8FF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEDF4FF),
    border: Color(0xFFDCE8FA),
    ink: Color(0xFF10233F),
    muted: Color(0xFF64748B),
    navy: Color(0xFF0B1B33),
    cameraCard: Color(0xFF0F2547),
    success: Color(0xFF10B981),
    successSoft: Color(0xFFD1FAE5),
    successInk: Color(0xFF047857),
    error: Color(0xFFEF4444),
    errorSoft: Color(0xFFFEE2E2),
    errorInk: Color(0xFFB91C1C),
    warning: Color(0xFFF59E0B),
    warningSoft: Color(0xFFFEF3C7),
    warningInk: Color(0xFF92400E),
    streak: Color(0xFFF97316),
    heart: Color(0xFFF43F5E),
    gem: Color(0xFF0EA5E9),
    gold: Color(0xFFFBBF24),
    locked: Color(0xFFE2E8F0),
    lockedShade: Color(0xFFCBD5E1),
    lockedInk: Color(0xFF94A3B8),
  );

  /// Noche azul profunda: el azul de SeñasGo sube de brillo para mantener el
  /// contraste y los fondos "Soft" pasan a ser tintes oscuros.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    primary: Color(0xFF4C8DFF),
    primaryDark: Color(0xFF2F6BDB),
    primaryDeep: Color(0xFFC9DCFF),
    primarySoft: Color(0xFF1A2F55),
    sky: Color(0xFF38BDF8),
    skySoft: Color(0xFF0F3047),
    teal: Color(0xFF2DD4BF),
    tealSoft: Color(0xFF0E3B3A),
    indigo: Color(0xFF818CF8),
    indigoSoft: Color(0xFF262A57),
    background: Color(0xFF0D1626),
    surface: Color(0xFF15223A),
    surfaceAlt: Color(0xFF1B2B47),
    border: Color(0xFF283B5E),
    ink: Color(0xFFE8EFFC),
    muted: Color(0xFF94A5C2),
    navy: Color(0xFF040A15),
    cameraCard: Color(0xFF0A1424),
    success: Color(0xFF34D399),
    successSoft: Color(0xFF0F3A2D),
    successInk: Color(0xFF6EE7B7),
    error: Color(0xFFF87171),
    errorSoft: Color(0xFF471A20),
    errorInk: Color(0xFFFCA5A5),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF3A2C0C),
    warningInk: Color(0xFFFCD34D),
    streak: Color(0xFFFB923C),
    heart: Color(0xFFFB7185),
    gem: Color(0xFF38BDF8),
    gold: Color(0xFFFBBF24),
    locked: Color(0xFF24344F),
    lockedShade: Color(0xFF1A273E),
    lockedInk: Color(0xFF6B7D9C),
  );
}

/// Colores de la paleta activa. La app la fija según el tema (ver `main.dart`)
/// y vuelve a construir las pantallas al cambiarlo.
class AppColors {
  const AppColors._();

  static AppPalette _palette = AppPalette.light;

  static AppPalette get palette => _palette;
  static bool get isDark => _palette.isDark;

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
    UnitPalette(Color(0xFF2563EB), Color(0xFF1D4ED8)), // azul principal
    UnitPalette(Color(0xFF0EA5E9), Color(0xFF0284C7)), // celeste
    UnitPalette(Color(0xFF14B8A6), Color(0xFF0F766E)), // turquesa
    UnitPalette(Color(0xFF6366F1), Color(0xFF4338CA)), // índigo
    UnitPalette(Color(0xFFF59E0B), Color(0xFFB45309)), // ámbar
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
      onPrimary: Colors.white,
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
      scaffoldBackgroundColor: p.background,
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
          foregroundColor: Colors.white,
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
          side: BorderSide(color: p.border, width: 1.6),
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
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: p.border),
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
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle:
            TextStyle(color: p.ink, fontWeight: FontWeight.w800, fontSize: 13),
        secondaryLabelStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
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
