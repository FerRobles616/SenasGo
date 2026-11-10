import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/cloud/data/cloud_sync_service.dart';
import 'package:senasgo/shared/widgets/app_ui.dart';

/// Cuenta iniciada y sincronización del progreso.
///
/// La app exige sesión, así que esta sección siempre muestra la cuenta. En
/// debug, sin Supabase configurado, aparece una pista de configuración.
class CloudAccountSection extends StatelessWidget {
  const CloudAccountSection({this.onAccountChanged, super.key});

  /// Se llama al iniciar/cerrar sesión o después de sincronizar, para que la
  /// pantalla que contiene la sección refresque el nombre y el progreso.
  final VoidCallback? onAccountChanged;

  @override
  Widget build(BuildContext context) {
    if (!CloudSyncService.configured && !kDebugMode) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionTitle('Progreso en la nube'),
        const SizedBox(height: 10),
        if (!CloudSyncService.configured)
          AppCard(
            padding: const EdgeInsets.all(15),
            child: Text(
              'Sincronización pendiente de configuración. En este build faltan '
              'SUPABASE_URL y SUPABASE_ANON_KEY.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          )
        else
          _CloudCard(onAccountChanged: onAccountChanged),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _CloudCard extends StatefulWidget {
  const _CloudCard({this.onAccountChanged});

  final VoidCallback? onAccountChanged;

  @override
  State<_CloudCard> createState() => _CloudCardState();
}

class _CloudCardState extends State<_CloudCard> {
  bool _busy = false;

  Future<void> _sync() async {
    setState(() => _busy = true);
    await CloudSyncService.syncNow();
    if (mounted) {
      setState(() => _busy = false);
      widget.onAccountChanged?.call();
    }
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
            'Tu progreso queda guardado en tu cuenta. Para volver a usar la '
            'app vas a tener que iniciar sesión.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    // El router lleva a /auth en cuanto la sesión se cierra.
    await CloudSyncService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = CloudSyncService.user;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: Icons.cloud_done_rounded,
                color: AppColors.success,
                size: 46,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.email ?? 'Cuenta conectada',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                    ValueListenableBuilder<DateTime?>(
                      valueListenable: CloudSyncService.lastSync,
                      builder: (context, date, _) => Text(
                        date == null
                            ? 'Progreso local pendiente de sincronizar'
                            : 'Sincronizado ${_dateLabel(date)}',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _sync,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            label: Text(_busy ? 'SINCRONIZANDO…' : 'SINCRONIZAR AHORA'),
          ),
          TextButton(
            onPressed: _busy ? null : _confirmSignOut,
            child: const Text('Cerrar sesión'),
          ),
          Text(
            'Al cerrar sesión, el progreso queda guardado en tu cuenta y se '
            'borra de este teléfono.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  static String _dateLabel(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return 'hoy a las $h:$m';
  }
}
