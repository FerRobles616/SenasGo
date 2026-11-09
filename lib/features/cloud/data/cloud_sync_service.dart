import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:senasgo/core/config/supabase_config.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/theme_controller.dart';

/// Sincronización opcional del progreso con Supabase/PostgreSQL.
///
/// Hive sigue siendo la fuente de verdad inmediata. La nube se usa para
/// recuperar el progreso en otro dispositivo o después de reinstalar.
class CloudSyncService {
  const CloudSyncService._();

  static bool _ready = false;
  static bool _syncing = false;

  static final ValueNotifier<DateTime?> lastSync =
      ValueNotifier<DateTime?>(null);
  static final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  static bool get configured => SupabaseConfig.configured;
  static bool get ready => _ready;
  static bool get syncing => _syncing;
  static User? get user => _ready ? _client.auth.currentUser : null;
  static String? get email => user?.email;

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<void> initialize() async {
    if (!configured || _ready) return;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      );
      _ready = true;
      _client.auth.onAuthStateChange.listen((event) {
        if (event.session != null) {
          unawaited(syncNow());
        }
      });
      Timer.periodic(const Duration(seconds: 45), (_) {
        if (_client.auth.currentUser != null) unawaited(syncNow());
      });
    } catch (e) {
      // Sin configuración válida, la app sigue funcionando offline.
      debugPrint('Supabase no disponible: $e');
      _ready = false;
    }
  }

  static Future<void> signIn(String email, String password) async {
    if (!_ready) throw StateError('La nube no está configurada.');
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    await syncNow();
  }

  static Future<bool> signUp(String email, String password) async {
    if (!_ready) throw StateError('La nube no está configurada.');
    await _client.auth.signUp(email: email.trim(), password: password);
    final hasSession = _client.auth.currentUser != null;
    if (hasSession) await syncNow();
    return hasSession;
  }

  static Future<void> signOut() async {
    if (!_ready) return;
    await _client.auth.signOut();
  }

  static Future<void> syncNow() async {
    if (!_ready || _syncing) return;
    final current = _client.auth.currentUser;
    if (current == null) return;
    _syncing = true;
    error.value = null;
    try {
      final profile = await _client
          .from('profiles')
          .select()
          .eq('user_id', current.id)
          .maybeSingle();
      if (profile == null) {
        await _uploadLocal(current.id);
      } else {
        await _mergeAndUpload(current.id, profile);
      }
      lastSync.value = DateTime.now();
      await HiveService.prefsBox
          .put('lastCloudSync', lastSync.value!.toIso8601String());
    } catch (e) {
      error.value = _friendlyError(e);
      debugPrint('Error de sincronización: $e');
    } finally {
      _syncing = false;
    }
  }

  static Future<void> _mergeAndUpload(
      String userId, Map<String, dynamic> cloudProfile) async {
    final localUser = HiveService.currentUser;
    final localProgress = HiveService.progress;

    final cloudSigns = await _client
        .from('user_signs')
        .select('sign_id')
        .eq('user_id', userId);
    final cloudGame = await _client
        .from('game_state')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    final cloudPrefs = await _client
        .from('preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    final cloudChests =
        await _client.from('chests').select('source_id').eq('user_id', userId);

    final learned = <String>{
      ...localProgress.completedSignIds,
      for (final row in cloudSigns) row['sign_id'] as String,
    };
    final xp = math.max(localUser.xp, _asInt(cloudProfile['xp']));
    final level = math.max(localUser.level, _asInt(cloudProfile['level']));
    final username = localUser.username == 'Usuario'
        ? (cloudProfile['username'] as String? ?? localUser.username)
        : localUser.username;

    final mergedUser = localUser.copyWith(
      username: username,
      xp: xp,
      level: level,
    );
    await HiveService.saveUser(mergedUser);
    await HiveService.progressBox.put(
      localProgress.userId,
      localProgress.copyWith(
        completedSignIds: learned.toList(),
        totalAttempts: math.max(
          localProgress.totalAttempts,
          _asInt(cloudGame?['total_attempts']),
        ),
      ),
    );

    if (cloudGame != null) {
      final cloudStreak = _asInt(cloudGame['streak_days']);
      final cloudBest = _asInt(cloudGame['best_streak']);
      if (cloudStreak > HiveService.streak) {
        await HiveService.gameBox.put('streakDays', cloudStreak);
        final date = cloudGame['streak_date'] as String?;
        if (date != null) {
          await HiveService.gameBox.put('streakDate', DateTime.tryParse(date));
        }
      }
      if (cloudBest > HiveService.bestStreak) {
        await HiveService.gameBox.put('bestStreak', cloudBest);
      }
      final cloudFreezes = _asInt(cloudGame['freezes']);
      if (cloudFreezes > HiveService.streakFreezes) {
        await HiveService.gameBox.put('streakFreezes', cloudFreezes);
      }
    }

    if (cloudPrefs != null) {
      final goal = _asInt(cloudPrefs['daily_goal']);
      if (goal >= 5 && goal <= 30) {
        await HiveService.setDailyGoalMinutes(goal);
      }
      final appearance = cloudPrefs['appearance'] as String?;
      final mode = AppearancePreference.values
          .where((item) => item.name == appearance)
          .firstOrNull;
      if (mode != null && mode != ThemeController.instance.preference) {
        await ThemeController.instance.setPreference(mode);
      }
    }

    final claimed = <String>{
      ...HiveService.claimedChests,
      for (final row in cloudChests)
        if (row['source_id'] is String) row['source_id'] as String,
    };
    await HiveService.prefsBox.put('claimedChests', claimed.toList());

    await _uploadLocal(userId);
  }

  static Future<void> _uploadLocal(String userId) async {
    final user = HiveService.currentUser;
    final progress = HiveService.progress;
    final now = DateTime.now().toUtc().toIso8601String();

    await _client.from('profiles').upsert({
      'user_id': userId,
      'username': user.username,
      'xp': user.xp,
      'level': user.level,
      'updated_at': now,
    });
    await _client.from('game_state').upsert({
      'user_id': userId,
      'streak_days': HiveService.streak,
      'streak_date': _dateOnly(HiveService.streakDate),
      'best_streak': HiveService.bestStreak,
      'freezes': HiveService.streakFreezes,
      'updated_at': now,
    });
    await _client.from('preferences').upsert({
      'user_id': userId,
      'daily_goal': HiveService.dailyGoalMinutes,
      'appearance': ThemeController.instance.preference.name,
      'reminder_weekday': HiveService.reminderWeekday,
      'reminder_hour': HiveService.reminderHour,
      'reminder_minute': HiveService.reminderMinute,
      'updated_at': now,
    });

    final signs = progress.completedSignIds;
    if (signs.isNotEmpty) {
      await _client.from('user_signs').upsert([
        for (final signId in signs)
          {
            'user_id': userId,
            'sign_id': signId,
            'learned_at': now,
          }
      ], onConflict: 'user_id,sign_id');
    }

    for (final chestId in HiveService.claimedChests) {
      final sourceId = chestId.startsWith('unit_') ? chestId : chestId;
      await _client.from('chests').upsert({
        'user_id': userId,
        'rarity': 'common',
        'reward_type': 'xp',
        'reward_value': 0,
        'source_type': 'unit',
        'source_id': sourceId,
        'opened_at': now,
      }, onConflict: 'user_id,source_type,source_id');
    }
  }

  static int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static String? _dateOnly(DateTime? date) {
    if (date == null) return null;
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _friendlyError(Object error) {
    if (error is AuthException) return error.message;
    if (error is PostgrestException) return error.message;
    return 'No se pudo sincronizar. Revisá tu conexión.';
  }
}
