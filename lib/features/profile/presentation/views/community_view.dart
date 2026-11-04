import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/support/presentation/support_actions.dart';
import 'package:senasgo/shared/models/practice_attempt.dart';
import 'package:senasgo/shared/widgets/app_ui.dart';
import 'package:senasgo/shared/widgets/jaguarete_mascot.dart';

/// Novedades y comunidad offline.
///
/// La app no crea cuentas ni muestra perfiles de otras personas. Acá se ve la
/// actividad propia y se ofrece una invitación para compartir la app por
/// fuera. Es la versión honesta de la pantalla social de Duolingo.
class CommunityView extends StatelessWidget {
  const CommunityView({super.key});

  Future<void> _copyInvite(BuildContext context) async {
    const message = 'Estoy aprendiendo Lengua de Señas Paraguaya con SeñasGo. '
        'Tiene un profesor 3D, lecciones cortas y funciona sin internet. '
        '¿Me acompañás?';
    await Clipboard.setData(const ClipboardData(text: message));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Invitación copiada. Pegala donde quieras compartirla.'),
      ));
  }

  Future<void> _copyProgress(BuildContext context) async {
    final user = HiveService.currentUser;
    final progress = HiveService.progress;
    final message =
        'Mi progreso en SeñasGo: nivel ${user.level}, ${user.xp} XP y '
        '${progress.completedSignIds.length} señas aprendidas. '
        'Aprender LSPy también puede ser parte de tu día.';
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Progreso copiado. Compartilo cuando quieras.'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final user = HiveService.currentUser;
    final progress = HiveService.progress;
    final attempts = HiveService.recentAttempts;
    final feed = _buildFeed(user.username, progress.completedSignIds.length,
        HiveService.streak, user.level, attempts);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novedades'),
        actions: [
          IconButton(
            tooltip: 'Ayuda y comentarios',
            onPressed: () => SupportSheet.show(context,
                contextLabel: 'Novedades y comunidad'),
            icon: const Icon(Icons.support_agent_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          AppHeroHeader(
            colors: const [
              Color(0xFF4338CA),
              Color(0xFF6366F1),
              Color(0xFF38BDF8)
            ],
            child: Row(
              children: [
                const JaguareteMascot(size: 76, mood: MascotMood.happy),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tu comunidad LSPy',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sin cuentas ni datos en la nube. Compartí la app y '
                        'tu progreso cuando vos quieras.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppIconBadge(
                      icon: Icons.person_add_alt_1_rounded,
                      color: AppColors.indigo,
                      size: 46,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invitá a un amigo',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'SeñasGo se comparte por mensaje, sin registro.',
                            style: TextStyle(
                              color: AppColors.muted.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, box) {
                    final invite = FilledButton.icon(
                      onPressed: () => _copyInvite(context),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('COPIAR INVITACIÓN'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        textStyle: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    );
                    final progress = OutlinedButton.icon(
                      onPressed: () => _copyProgress(context),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('MI PROGRESO'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    );
                    // En 320 px los dos botones no entran lado a lado sin
                    // cortar "COPIAR INVITACIÓN"; se apilan a ancho completo.
                    if (box.maxWidth < 300) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          invite,
                          const SizedBox(height: 8),
                          progress,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: invite),
                        const SizedBox(width: 8),
                        progress,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const AppSectionTitle(
            'Novedades',
            subtitle: 'Tus hitos y prácticas recientes, solo en este teléfono.',
          ),
          const SizedBox(height: 10),
          if (feed.isEmpty)
            const AppEmptyState(
              icon: Icons.auto_awesome_rounded,
              title: 'Tu historia empieza hoy',
              message: 'Cuando practiques una seña, acá vas a ver tus avances, '
                  'rachas y logros.',
            )
          else
            for (final item in feed) ...[
              _FeedCard(item: item),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.all(16),
            color: AppColors.surfaceAlt,
            borderColor: AppColors.border,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        color: AppColors.primary, size: 20),
                    SizedBox(width: 7),
                    Text(
                      'Privacidad por diseño',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'SeñasGo no pide tu nombre real, no sube fotos y no crea '
                  'una cuenta. La cámara analiza la forma de tu mano en el '
                  'momento y descarta los fotogramas.',
                  style: TextStyle(
                    color: AppColors.muted.withValues(alpha: 0.95),
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person_rounded, size: 18),
            label: const Text('Editar mi perfil'),
          ),
        ],
      ),
    );
  }

  static List<_FeedItem> _buildFeed(
    String name,
    int learned,
    int streak,
    int level,
    List<PracticeAttempt> attempts,
  ) {
    final items = <_FeedItem>[];
    if (streak > 0) {
      items.add(_FeedItem(
        icon: Icons.local_fire_department_rounded,
        color: AppColors.streak,
        title: 'Racha de $streak ${streak == 1 ? 'día' : 'días'}',
        subtitle: 'La constancia está dando frutos.',
        at: DateTime.now(),
      ));
    }
    if (learned > 0) {
      items.add(_FeedItem(
        icon: Icons.sign_language_rounded,
        color: AppColors.primary,
        title:
            '$learned ${learned == 1 ? 'seña aprendida' : 'señas aprendidas'}',
        subtitle: 'Cada seña abre una conversación nueva.',
        at: DateTime.now(),
      ));
    }
    if (level > 1) {
      items.add(_FeedItem(
        icon: Icons.workspace_premium_rounded,
        color: AppColors.gold,
        title: 'Nivel $level alcanzado',
        subtitle: 'Seguí practicando para desbloquear más.',
        at: DateTime.now(),
      ));
    }
    for (final attempt in attempts.take(6)) {
      final sign = HiveService.signById(attempt.signId);
      items.add(_FeedItem(
        icon: attempt.correct
            ? Icons.check_circle_rounded
            : Icons.refresh_rounded,
        color: attempt.correct ? AppColors.success : AppColors.warning,
        title: attempt.correct
            ? 'Practicaste ${sign?.name ?? attempt.signId}'
            : 'Repasaste ${sign?.name ?? attempt.signId}',
        subtitle: attempt.correct
            ? '¡Bien! Seguí así.'
            : 'Equivocarse también es aprender.',
        at: attempt.at,
      ));
    }
    items.sort((a, b) => b.at.compareTo(a.at));
    return items;
  }
}

class _FeedItem {
  const _FeedItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.at,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final DateTime at;
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item});

  final _FeedItem item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Row(
        children: [
          AppIconBadge(
              icon: item.icon, color: item.color, size: 42, radius: 13),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _relative(item.at),
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static String _relative(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'ayer';
    return 'hace ${diff.inDays} d';
  }
}
