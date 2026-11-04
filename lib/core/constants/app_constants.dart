class AppConstants {
  const AppConstants._();

  // App Info
  static const String appName = 'SeñasGo';
  static const String appVersion = '0.1.0';

  /// Buzón de soporte. La app no envía nada automáticamente: el reporte se
  /// guarda en el teléfono y, si la persona lo decide, se copia o se abre en
  /// su app de correo.
  static const String supportEmail = 'soporte@senasgo.app';

  // Camera & Vision (control térmico: nunca 60 FPS)
  static const int targetFpsMin = 10;
  static const int targetFpsMax = 15;

  /// Fracción del ancho de la imagen que ocupa el recuadro guía (encuadre).
  static const double guideBoxFraction = 0.75;

  /// Tiempo máximo de captura sin ver la mano antes de pausar (estado 6).
  static const Duration captureTimeout = Duration(seconds: 4);

  /// Ventana de fotogramas usada para evaluar el movimiento de la seña.
  static const Duration evaluationWindow = Duration(milliseconds: 1500);

  // Modelos Edge AI (opcionales; sin ellos la app usa el modo conceptual)
  static const String handLandmarkModel = 'assets/models/hand_landmark.tflite';
  static const String signClassifierModel =
      'assets/models/gesture_model.tflite';
  static const String signClassifierLabels = 'assets/models/gesture_labels.txt';

  // Iluminación (luma 0-255)
  static const double minCenterLuma = 45; // ambiente oscuro
  static const double maxCenterLuma = 235; // sobreexpuesto
  static const double backlightMinBorderLuma = 180; // fondo muy brillante
  static const double backlightMinDelta = 70; // fondo vs. mano

  // Game
  static const int xpPerCorrectSign = 10;
  static const int xpPerChallenge = 20;
  static const int welcomeRewardXp = 10;
  static const int defaultDailyGoalMinutes = 10;
  static const int initialStreakFreezes = 2;

  /// Hasta este nivel se aplica la tolerancia más amplia (curva de
  /// aprendizaje); después el umbral de confianza sube más despacio.
  static const int beginnerLevelCap = 3;
  static const String hiveBoxUser = 'user_box';
  static const String hiveBoxLessons = 'lessons_box';
  static const String hiveBoxVocabulary = 'vocabulary_box';
  static const String hiveBoxProgress = 'progress_box';
  static const String hiveBoxGame = 'game_box';
  static const String hiveBoxSupport = 'support_box';
  static const String hiveBoxPrefs = 'prefs_box';

  // Vidas: permiten equivocarse sin frustrar; se recuperan solas.
  static const int maxHearts = 5;
  static const Duration heartRegen = Duration(minutes: 20);
}
