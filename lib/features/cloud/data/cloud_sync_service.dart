import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:senasgo/core/config/supabase_config.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/theme_controller.dart';
import 'package:senasgo/features/support/data/support_repository.dart';
import 'package:senasgo/features/support/domain/support_ticket.dart';

/// Cuenta obligatoria y sincronización del progreso con Supabase/PostgreSQL.
///
/// Para usar la app hay que registrarse o iniciar sesión. La sesión queda
/// guardada en el teléfono, así que después la app funciona sin conexión:
/// Hive sigue siendo la fuente de verdad inmediata y la nube se actualiza
/// cuando hay internet.
class CloudSyncService {
  const CloudSyncService._();

  static bool _ready = false;
  static bool _syncing = false;

  static final ValueNotifier<DateTime?> lastSync =
      ValueNotifier<DateTime?>(null);
  static final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  /// true cuando hay una sesión iniciada. El router la escucha para mandar
  /// a la pantalla de acceso a quien no tiene sesión.
  static final ValueNotifier<bool> session = ValueNotifier<bool>(false);

  static bool _debugSignedIn = false;

  /// Solo para pruebas: simula una sesión iniciada sin servidor.
  @visibleForTesting
  static set debugSignedIn(bool value) {
    _debugSignedIn = value;
    session.value = value || user != null;
  }

  static bool get signedIn => _debugSignedIn || user != null;

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
      session.value = signedIn;
      _client.auth.onAuthStateChange.listen((event) {
        // La entrada la marcan signIn/signUp después de sincronizar, para
        // que el router no decida antes de tener el progreso de la cuenta.
        if (event.event == AuthChangeEvent.signedOut) {
          session.value = _debugSignedIn;
        } else if (event.session != null && session.value) {
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
    await syncNow(existingAccount: true);
    session.value = true;
  }

  /// Crea la cuenta. Devuelve false si Supabase pide confirmar el correo
  /// antes de entrar.
  static Future<bool> signUp(String email, String password, String name) async {
    if (!_ready) throw StateError('La nube no está configurada.');
    final clean = name.trim();
    if (clean.isNotEmpty) await HiveService.updateUsername(clean);
    await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {if (clean.isNotEmpty) 'username': clean},
    );
    final hasSession = _client.auth.currentUser != null;
    if (hasSession) {
      await syncNow();
      session.value = true;
    }
    return hasSession;
  }

  /// Envía un código de 6 dígitos al correo para cambiar la contraseña.
  /// (La plantilla "Reset Password" de Supabase debe mostrar {{ .Token }}.)
  static Future<void> sendPasswordResetCode(String email) async {
    if (!_ready) throw StateError('La nube no está configurada.');
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  /// Valida el código recibido, guarda la contraseña nueva y entra a la app.
  static Future<void> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (!_ready) throw StateError('La nube no está configurada.');
    await _client.auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.recovery,
    );
    await _client.auth.updateUser(UserAttributes(password: newPassword));
    await syncNow(existingAccount: true);
    session.value = true;
  }

  /// Sube lo pendiente, borra el progreso de este teléfono (queda en la
  /// cuenta) y cierra la sesión. Así otra cuenta no hereda datos ajenos.
  static Future<void> signOut() async {
    if (_ready && _client.auth.currentUser != null) {
      await syncNow();
    }
    await HiveService.clearUserData();
    lastSync.value = null;
    if (_ready) await _client.auth.signOut();
    _debugSignedIn = false;
    session.value = false;
  }

  /// Une el progreso del teléfono con el de la cuenta y sube el resultado.
  ///
  /// [existingAccount] se usa al iniciar sesión: una cuenta que ya existía no
  /// repite la bienvenida en este teléfono.
  static Future<void> syncNow({bool existingAccount = false}) async {
    if (!_ready || _syncing) return;
    final current = _client.auth.currentUser;
    if (current == null) return;
    _syncing = true;
    error.value = null;
    try {
      final profile = await _client
          .from('profiles')
          .select('username, xp')
          .eq('user_id', current.id)
          .maybeSingle();
      if (profile != null) {
        await _merge(current.id, profile, existingAccount: existingAccount);
      }
      await _upload(current.id);
      await _sendPendingTickets(current.id);
      await _pullTicketStatus(current.id);
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

  /// Trae lo de la cuenta y lo combina con lo local (nunca se pierde
  /// progreso: se queda el mayor valor o la unión de los conjuntos).
  static Future<void> _merge(String userId, Map<String, dynamic> cloudProfile,
      {required bool existingAccount}) async {
    final localUser = HiveService.currentUser;
    final localProgress = HiveService.progress;

    final cloudSigns = await _client
        .from('user_signs')
        .select('sign_id')
        .eq('user_id', userId);
    final cloudStreak = await _client
        .from('streaks')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    final cloudPrefs = await _client
        .from('preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    final cloudChests = await _client
        .from('user_chests')
        .select('lesson_id')
        .eq('user_id', userId);
    final cloudChallenges = await _client
        .from('user_challenges')
        .select('challenge_id')
        .eq('user_id', userId);

    final cloudXp = _asInt(cloudProfile['xp']);
    if (existingAccount && (cloudXp > 0 || cloudSigns.isNotEmpty)) {
      await HiveService.setOnboardingDone(true);
      await HiveService.prefsBox.put('welcomeRewardClaimed', true);
    }

    // El nivel no se guarda en la nube: se calcula a partir de la XP.
    final xp = math.max(localUser.xp, cloudXp);
    final cloudName = (cloudProfile['username'] as String?)?.trim() ?? '';
    final username = localUser.username == 'Usuario' && cloudName.isNotEmpty
        ? cloudName
        : localUser.username;
    await HiveService.saveUser(localUser.copyWith(
      username: username,
      xp: xp,
      level: HiveService.calculateLevel(xp),
    ));

    final learned = <String>{
      ...localProgress.completedSignIds,
      for (final row in cloudSigns) row['sign_id'] as String,
    };
    await HiveService.progressBox.put(
      localProgress.userId,
      localProgress.copyWith(completedSignIds: learned.toList()),
    );

    if (cloudStreak != null) {
      final days = _asInt(cloudStreak['current_days']);
      if (days > HiveService.streak) {
        await HiveService.gameBox.put('streakDays', days);
        final date = cloudStreak['last_practice_date'] as String?;
        if (date != null) {
          await HiveService.gameBox.put('streakDate', DateTime.tryParse(date));
        }
      }
      final best = _asInt(cloudStreak['best_days']);
      if (best > HiveService.bestStreak) {
        await HiveService.gameBox.put('bestStreak', best);
      }
      final freezes = _asInt(cloudStreak['freezes']);
      if (freezes > HiveService.streakFreezes) {
        await HiveService.gameBox.put('streakFreezes', freezes);
      }
    }

    if (cloudPrefs != null && existingAccount) {
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

    // Cofres: en la app se identifican como 'unit_<lección>'.
    final chests = <String>{
      ...HiveService.claimedChests,
      for (final row in cloudChests) 'unit_${row['lesson_id']}',
    };
    await HiveService.prefsBox.put('claimedChests', chests.toList());

    final challenges = <String>{
      ...HiveService.claimedChallenges,
      for (final row in cloudChallenges) row['challenge_id'] as String,
    };
    await HiveService.gameBox.put('claimedChallenges', challenges.toList());
  }

  /// Sube el estado local a las tablas normalizadas de la cuenta.
  static Future<void> _upload(String userId) async {
    final user = HiveService.currentUser;
    final progress = HiveService.progress;

    await _client.from('profiles').upsert({
      'user_id': userId,
      'username': user.username,
      'xp': user.xp,
    });
    await _client.from('streaks').upsert({
      'user_id': userId,
      'current_days': HiveService.streak,
      'last_practice_date': _dateOnly(HiveService.streakDate),
      'best_days': math.max(HiveService.bestStreak, HiveService.streak),
      'freezes': HiveService.streakFreezes,
    });
    await _client.from('preferences').upsert({
      'user_id': userId,
      'daily_goal': HiveService.dailyGoalMinutes,
      'appearance': ThemeController.instance.preference.name,
      'reminder_weekday': HiveService.reminderWeekday,
      'reminder_hour': HiveService.reminderHour,
      'reminder_minute': HiveService.reminderMinute,
    });

    if (progress.completedSignIds.isNotEmpty) {
      await _client.from('user_signs').upsert([
        for (final signId in progress.completedSignIds)
          {'user_id': userId, 'sign_id': signId},
      ], onConflict: 'user_id,sign_id', ignoreDuplicates: true);
    }

    final attempts = HiveService.recentAttempts;
    if (attempts.isNotEmpty) {
      await _client.from('attempts').upsert([
        for (final a in attempts)
          {
            'user_id': userId,
            'sign_id': a.signId,
            'correct': a.correct,
            'attempted_at': a.at.toUtc().toIso8601String(),
          },
      ], onConflict: 'user_id,sign_id,attempted_at', ignoreDuplicates: true);
    }

    final chests = [
      for (final id in HiveService.claimedChests)
        if (id.startsWith('unit_')) id.substring(5),
    ];
    if (chests.isNotEmpty) {
      await _client.from('user_chests').upsert([
        for (final lessonId in chests)
          {'user_id': userId, 'lesson_id': lessonId},
      ], onConflict: 'user_id,lesson_id', ignoreDuplicates: true);
    }

    final challenges = HiveService.claimedChallenges;
    if (challenges.isNotEmpty) {
      await _client.from('user_challenges').upsert([
        for (final id in challenges) {'user_id': userId, 'challenge_id': id},
      ], onConflict: 'user_id,challenge_id', ignoreDuplicates: true);
    }
  }

  /// Envía un reporte a Soporte. Devuelve false si no se pudo (sin
  /// conexión): queda pendiente y se reintenta al sincronizar.
  static Future<bool> sendTicket(SupportTicket ticket) async {
    final current = _ready ? _client.auth.currentUser : null;
    if (current == null) return false;
    try {
      await _insertTicket(current.id, ticket);
      return true;
    } catch (e) {
      debugPrint('Reporte pendiente de envío: $e');
      return false;
    }
  }

  static Future<void> _insertTicket(String userId, SupportTicket t) async {
    await _client.from('support_tickets').upsert({
      'id': t.id,
      'user_id': userId,
      'category': t.category.name,
      'message': t.message,
      'screen': t.context,
      'app_version': t.appVersion,
      'platform': t.platform,
      'device_tier': t.diagnostics['dispositivo'] ?? '',
      'created_at': t.createdAt.toUtc().toIso8601String(),
    }, onConflict: 'id', ignoreDuplicates: true);
    await SupportRepository.markSent(t.id, DateTime.now());
  }

  static Future<void> _sendPendingTickets(String userId) async {
    for (final ticket in SupportRepository.pending) {
      await _insertTicket(userId, ticket);
    }
  }

  /// Trae qué reportes ya resolvió Soporte.
  static Future<void> _pullTicketStatus(String userId) async {
    final rows = await _client
        .from('support_tickets')
        .select('id, status')
        .eq('user_id', userId);
    for (final row in rows) {
      final resolved = row['status'] == 'resolved';
      final local =
          SupportRepository.tickets.where((t) => t.id == row['id']).firstOrNull;
      if (local != null && local.isResolved != resolved) {
        await SupportRepository.setResolved(local.id, resolved);
      }
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
