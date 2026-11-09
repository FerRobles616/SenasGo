import 'package:hive/hive.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/features/learning/data/seed_data.dart';
import 'package:senasgo/shared/models/lesson_model.dart';
import 'package:senasgo/shared/models/practice_attempt.dart';
import 'package:senasgo/shared/models/progress_model.dart';
import 'package:senasgo/shared/models/sign_model.dart';
import 'package:senasgo/shared/models/user_model.dart';

/// Acceso único a la persistencia local (Hive). 100% offline.
class HiveService {
  static Future<void> registerAdapters() async {
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserModelAdapter());
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LessonModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(SignCategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(SignModelAdapter());
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ProgressModelAdapter());
    }
  }

  static Future<void> initBoxes() async {
    await Hive.openBox<UserModel>(AppConstants.hiveBoxUser);
    await Hive.openBox<LessonModel>(AppConstants.hiveBoxLessons);
    await Hive.openBox<SignModel>(AppConstants.hiveBoxVocabulary);
    await Hive.openBox<ProgressModel>(AppConstants.hiveBoxProgress);
    await Hive.openBox<dynamic>(AppConstants.hiveBoxGame);
    // Los reportes se guardan como mapas: no requieren adaptador y permiten
    // evolucionar el formulario sin migraciones.
    await Hive.openBox<dynamic>(AppConstants.hiveBoxSupport);
    // Preferencias de la persona (onboarding, meta diaria, nombre visible).
    // Es una caja de mapas para poder crecer sin migraciones.
    await Hive.openBox<dynamic>(AppConstants.hiveBoxPrefs);
  }

  /// Inserta el vocabulario acotado solo la primera vez.
  /// Copia el catálogo a Hive. Corre en cada inicio: así las señas y
  /// lecciones nuevas o corregidas llegan a quien ya tenía la app. Las señas
  /// son contenido fijo; de las lecciones se conserva si ya se completaron.
  static Future<void> seedIfEmpty() async {
    for (final lesson in SeedData.lessons) {
      final stored = lessonsBox.get(lesson.id);
      final updated = stored == null
          ? lesson
          : lesson.copyWith(isCompleted: stored.isCompleted);
      if (stored != updated) await lessonsBox.put(lesson.id, updated);
    }
    for (final sign in SeedData.signs) {
      if (vocabularyBox.get(sign.id) != sign) {
        await vocabularyBox.put(sign.id, sign);
      }
    }
  }

  // ─────────────────────────── Boxes ───────────────────────────
  static Box<UserModel> get userBox =>
      Hive.box<UserModel>(AppConstants.hiveBoxUser);
  static Box<LessonModel> get lessonsBox =>
      Hive.box<LessonModel>(AppConstants.hiveBoxLessons);
  static Box<SignModel> get vocabularyBox =>
      Hive.box<SignModel>(AppConstants.hiveBoxVocabulary);
  static Box<ProgressModel> get progressBox =>
      Hive.box<ProgressModel>(AppConstants.hiveBoxProgress);
  static Box<dynamic> get gameBox =>
      Hive.box<dynamic>(AppConstants.hiveBoxGame);
  static Box<dynamic> get prefsBox =>
      Hive.box<dynamic>(AppConstants.hiveBoxPrefs);

  // ─────────────────────────── Preferencias ───────────────────────────
  static bool get onboardingDone =>
      prefsBox.get('onboardingDone', defaultValue: false) as bool;

  static Future<void> setOnboardingDone(bool done) async {
    await prefsBox.put('onboardingDone', done);
  }

  static int get dailyGoalMinutes => prefsBox.get('dailyGoalMinutes',
      defaultValue: AppConstants.defaultDailyGoalMinutes) as int;

  static Future<void> setDailyGoalMinutes(int minutes) async {
    await prefsBox.put('dailyGoalMinutes', minutes.clamp(5, 30));
  }

  /// Recordatorio semanal de práctica (1 = lunes, 7 = domingo).
  static int? get reminderWeekday => prefsBox.get('reminderWeekday') as int?;

  static int get reminderHour =>
      prefsBox.get('reminderHour', defaultValue: 19) as int;

  static int get reminderMinute =>
      prefsBox.get('reminderMinute', defaultValue: 0) as int;

  static bool get reminderEnabled => reminderWeekday != null;

  static Future<void> setReminder({
    required int weekday,
    required int hour,
    required int minute,
  }) async {
    await prefsBox.put('reminderWeekday', weekday);
    await prefsBox.put('reminderHour', hour);
    await prefsBox.put('reminderMinute', minute);
  }

  static Future<void> clearReminder() async {
    await prefsBox.delete('reminderWeekday');
    await prefsBox.delete('reminderHour');
    await prefsBox.delete('reminderMinute');
  }

  static Future<void> updateUsername(String username) async {
    final clean = username.trim();
    if (clean.isEmpty) return;
    final user = currentUser;
    await saveUser(user.copyWith(username: clean));
  }

  /// Recompensa única de bienvenida. La marca se guarda antes de sumar XP
  /// para que tocar dos veces el botón no duplique la recompensa.
  static bool get welcomeRewardClaimed =>
      prefsBox.get('welcomeRewardClaimed', defaultValue: false) as bool;

  static Future<UserModel> claimWelcomeReward() async {
    if (welcomeRewardClaimed) return currentUser;
    await prefsBox.put('welcomeRewardClaimed', true);
    return addXp(AppConstants.welcomeRewardXp);
  }

  // ─────────────────────────── Usuario ───────────────────────────
  static UserModel get currentUser =>
      userBox.values.isEmpty ? UserModel.initial() : userBox.values.first;

  static Future<void> saveUser(UserModel user) async {
    await userBox.clear();
    await userBox.put(user.id, user);
  }

  /// Otorga XP locales (ciclo: Practicar -> Recibir Feedback).
  static Future<UserModel> addXp(int amount) async {
    if (amount > 0) await _trackXp(amount);
    final user = currentUser;
    final newXp = user.xp + amount;
    final updated = user.copyWith(
      xp: newXp,
      level: calculateLevel(newXp),
      lastLogin: DateTime.now(),
    );
    await saveUser(updated);
    return updated;
  }

  // ─────────────────────────── Cofres ───────────────────────────

  static List<String> get claimedChests {
    final raw = prefsBox.get('claimedChests', defaultValue: const <dynamic>[]);
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is String) item
    ];
  }

  static bool isChestClaimed(String chestId) => claimedChests.contains(chestId);

  /// Entrega un cofre una sola vez. Devuelve false si ya estaba reclamado.
  static Future<bool> claimChest({
    required String chestId,
    required int xp,
    int freezes = 0,
  }) async {
    if (isChestClaimed(chestId)) return false;
    await prefsBox.put('claimedChests', [...claimedChests, chestId]);
    await addXp(xp);
    if (freezes > 0) {
      await gameBox.put('streakFreezes', streakFreezes + freezes);
    }
    return true;
  }

  static String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime _mondayOf(DateTime date) {
    final day = _day(date);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  static String _weekKey(DateTime date) => _dayKey(_mondayOf(date));

  /// Lleva el XP del día y de la semana para retos y liga. Se guarda aparte
  /// del total porque el total histórico nunca debe reiniciarse.
  static Future<void> _trackXp(int amount) async {
    final now = DateTime.now();
    final today = _dayKey(now);
    if (gameBox.get('dailyXpDate') != today) {
      await gameBox.put('dailyXpDate', today);
      await gameBox.put('dailyXp', 0);
    }
    final daily = gameBox.get('dailyXp', defaultValue: 0) as int;
    await gameBox.put('dailyXp', daily + amount);

    final week = _weekKey(now);
    if (gameBox.get('weeklyXpWeek') != week) {
      await gameBox.put('weeklyXpWeek', week);
      await gameBox.put('weeklyXp', 0);
    }
    final weekly = gameBox.get('weeklyXp', defaultValue: 0) as int;
    await gameBox.put('weeklyXp', weekly + amount);
  }

  static int get dailyXp {
    if (gameBox.get('dailyXpDate') != _dayKey(DateTime.now())) return 0;
    return gameBox.get('dailyXp', defaultValue: 0) as int;
  }

  static int get weeklyXp {
    if (gameBox.get('weeklyXpWeek') != _weekKey(DateTime.now())) return 0;
    return gameBox.get('weeklyXp', defaultValue: 0) as int;
  }

  /// Retos ya reclamados (IDs estables). Evita recompensas infinitas.
  static Set<String> get claimedChallenges {
    final raw =
        gameBox.get('claimedChallenges', defaultValue: const <dynamic>[]);
    if (raw is! List) return <String>{};
    return raw.whereType<String>().toSet();
  }

  static Future<UserModel> claimChallenge(String challengeId, int xp) async {
    if (claimedChallenges.contains(challengeId)) return currentUser;
    await gameBox.put('claimedChallenges', [
      ...claimedChallenges,
      challengeId,
    ]);
    return addXp(xp);
  }

  // ─────────────────────────── Progreso ───────────────────────────
  static ProgressModel get progress {
    final userId = currentUser.id;
    return progressBox.get(userId) ??
        ProgressModel(
          userId: userId,
          completedSignIds: const [],
          streakDays: 0,
          lastPracticeDate: null,
          totalPracticeTimeSeconds: 0,
          correctAttempts: 0,
          totalAttempts: 0,
        );
  }

  /// Registra un intento evaluado. Si fue correcto otorga +10 XP locales
  /// (estado 10 del flujo) y marca la seña como aprendida.
  static Future<UserModel> recordAttempt({
    required String signId,
    required bool correct,
  }) async {
    final p = progress;
    await progressBox.put(
      p.userId,
      p.copyWith(
        totalAttempts: p.totalAttempts + 1,
        correctAttempts: p.correctAttempts + (correct ? 1 : 0),
        completedSignIds: correct && !p.completedSignIds.contains(signId)
            ? [...p.completedSignIds, signId]
            : p.completedSignIds,
        lastPracticeDate: DateTime.now(),
      ),
    );
    await _recordRecentAttempt(signId, correct);
    if (!correct) return currentUser;
    await _touchStreak();
    return addXp(AppConstants.xpPerCorrectSign);
  }

  /// Últimos intentos (más recientes primero) para la pantalla de progreso.
  static List<PracticeAttempt> get recentAttempts {
    final raw = gameBox.get('recentAttempts', defaultValue: const <dynamic>[]);
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) PracticeAttempt.fromMap(item),
    ];
  }

  static Future<void> _recordRecentAttempt(String signId, bool correct) async {
    final list = [
      PracticeAttempt(signId: signId, correct: correct, at: DateTime.now())
          .toMap(),
      ...recentAttempts.map((a) => a.toMap()),
    ];
    if (list.length > 40) list.removeRange(40, list.length);
    await gameBox.put('recentAttempts', list);
  }

  /// Intentos desde el lunes de esta semana (incluye incorrectos).
  static List<PracticeAttempt> get weeklyAttempts {
    final monday = _mondayOf(DateTime.now());
    return recentAttempts.where((a) => !a.at.isBefore(monday)).toList();
  }

  static int get todayCorrectCount {
    final today = _day(DateTime.now());
    return recentAttempts.where((a) => a.correct && _day(a.at) == today).length;
  }

  static int get weeklyDistinctSigns {
    final ids = <String>{};
    for (final attempt in weeklyAttempts) {
      if (attempt.correct) ids.add(attempt.signId);
    }
    return ids.length;
  }

  static int get weekendPracticeCount {
    return weeklyAttempts
        .where((a) =>
            a.at.weekday == DateTime.saturday ||
            a.at.weekday == DateTime.sunday)
        .length;
  }

  // ─────────────────────────── Racha ───────────────────────────
  // Nota: la documentación v3_04 deja el "sistema de rachas persistentes"
  // fuera del alcance del prototipo; se incluye a pedido del equipo.

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Días seguidos con al menos una seña correcta (0 si se cortó).
  ///
  /// Si se salteó exactamente un día y quedan protectores, la racha sigue
  /// viva hasta que la persona vuelva a practicar. El protector se consume
  /// en ese momento, no al abrir la pantalla.
  static int get streak {
    final days = gameBox.get('streakDays', defaultValue: 0) as int;
    final last = gameBox.get('streakDate') as DateTime?;
    if (last == null) return 0;
    final gap = _day(DateTime.now()).difference(_day(last)).inDays;
    if (gap <= 1) return days;
    if (gap == 2 && streakFreezes > 0) return days;
    return 0;
  }

  static DateTime? get streakDate => gameBox.get('streakDate') as DateTime?;

  static int get bestStreak {
    final stored = gameBox.get('bestStreak', defaultValue: 0) as int;
    return stored < streak ? streak : stored;
  }

  static int get streakFreezes => gameBox.get('streakFreezes',
      defaultValue: AppConstants.initialStreakFreezes) as int;

  /// Días con al menos una práctica correcta, para el calendario.
  static List<DateTime> get practiceDays {
    final raw = gameBox.get('practiceDays', defaultValue: const <dynamic>[]);
    if (raw is! List) return const [];
    final result = <DateTime>[];
    for (final item in raw) {
      if (item is! String) continue;
      final parsed = DateTime.tryParse(item);
      if (parsed != null) result.add(_day(parsed));
    }
    result.sort();
    return result;
  }

  /// Hoy ya hubo al menos una seña correcta.
  static bool get practicedToday {
    final last = gameBox.get('streakDate') as DateTime?;
    return last != null && _day(last) == _day(DateTime.now());
  }

  static Future<void> _recordPracticeDay(DateTime date) async {
    final key = _dayKey(date);
    final days = practiceDays.map(_dayKey).toSet();
    if (days.contains(key)) return;
    final updated = [...practiceDays, _day(date)]..sort();
    // Un año de historial es suficiente para el calendario y mantiene la caja
    // liviana en teléfonos con poca memoria.
    if (updated.length > 400) updated.removeRange(0, updated.length - 400);
    await gameBox.put(
      'practiceDays',
      [for (final day in updated) _dayKey(day)],
    );
  }

  /// Si hoy ya sumó, no cambia; si fue ayer, +1; si no, vuelve a 1.
  /// Si hubo un hueco de un día, usa un protector de racha si hay disponible.
  static Future<void> _touchStreak() async {
    final now = DateTime.now();
    await _recordPracticeDay(now);
    if (practicedToday) return;

    final last = gameBox.get('streakDate') as DateTime?;
    final previous = gameBox.get('streakDays', defaultValue: 0) as int;
    var freezes = streakFreezes;
    var days = 1;
    if (last != null) {
      final gap = _day(now).difference(_day(last)).inDays;
      if (gap == 1) {
        days = previous + 1;
      } else if (gap == 2 && freezes > 0) {
        freezes -= 1;
        days = previous + 1;
      }
    }
    final best = bestStreak;
    await gameBox.put('streakDays', days);
    await gameBox.put('streakDate', now);
    await gameBox.put('streakFreezes', freezes);
    if (days > best) await gameBox.put('bestStreak', days);
  }

  /// Señas aprendidas (al menos una práctica correcta).
  static Set<String> get learnedSignIds => progress.completedSignIds.toSet();

  /// Nivel dinámico: a mayor nivel, más estricto el umbral de IA.
  static int calculateLevel(int xp) {
    if (xp < 100) return 1;
    if (xp < 300) return 2;
    if (xp < 600) return 3;
    if (xp < 1000) return 4;
    return 5;
  }

  // ─────────────────────────── Lecciones ───────────────────────────
  static List<LessonModel> get lessons {
    final list = lessonsBox.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  static Future<void> markLessonCompleted(String lessonId) async {
    final lesson = lessonsBox.get(lessonId);
    if (lesson == null || lesson.isCompleted) return;
    await lessonsBox.put(lessonId, lesson.copyWith(isCompleted: true));

    final user = currentUser;
    if (!user.completedLessons.contains(lessonId)) {
      await saveUser(user.copyWith(
        completedLessons: [...user.completedLessons, lessonId],
      ));
    }
  }

  static SignModel? signById(String id) => vocabularyBox.get(id);

  static List<SignModel> get signsOfAll => vocabularyBox.values.toList();

  static List<SignModel> signsOf(String lessonId) {
    final lesson = lessonsBox.get(lessonId);
    if (lesson == null) return const [];
    return lesson.signIds
        .map((id) => vocabularyBox.get(id))
        .whereType<SignModel>()
        .toList();
  }

  // ─────────────────────────── Niveles ───────────────────────────

  /// Umbral de XP para cada nivel (el índice 0 es el nivel 1).
  static const List<int> levelThresholds = [0, 100, 300, 600, 1000];

  static int xpForLevel(int level) =>
      levelThresholds[(level - 1).clamp(0, levelThresholds.length - 1)];

  /// XP que falta para el siguiente nivel, o null si ya es nivel máximo.
  static int? xpToNextLevel(int xp) {
    for (final threshold in levelThresholds) {
      if (xp < threshold) return threshold - xp;
    }
    return null;
  }
}
