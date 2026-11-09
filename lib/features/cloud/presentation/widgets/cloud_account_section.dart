import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/cloud/data/cloud_sync_service.dart';
import 'package:senasgo/shared/widgets/app_ui.dart';

/// Sección de cuenta y sincronización opcional.
///
/// En release, si Supabase no está configurado, no se muestra nada. En debug
/// sí aparece una pista de configuración para no ocultar el estado del build.
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

  Future<void> _authenticate({required bool create}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AuthSheet(create: create),
    );
    if (result == true && mounted) {
      setState(() {});
      widget.onAccountChanged?.call();
    }
  }

  Future<void> _sync() async {
    setState(() => _busy = true);
    await CloudSyncService.syncNow();
    if (mounted) {
      setState(() => _busy = false);
      widget.onAccountChanged?.call();
    }
  }

  Future<void> _signOut() async {
    await CloudSyncService.signOut();
    if (mounted) {
      setState(() {});
      widget.onAccountChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = CloudSyncService.user;
    if (user == null) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppIconBadge(
                  icon: Icons.cloud_outlined,
                  color: AppColors.primary,
                  size: 46,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guardá tu progreso',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Estás como invitado. Recuperá XP, rachas y señas en otro teléfono.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _authenticate(create: false),
              child: const Text('INICIAR SESIÓN'),
            ),
            TextButton(
              onPressed: () => _authenticate(create: true),
              child: const Text('Crear una cuenta'),
            ),
          ],
        ),
      );
    }

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
                      user.email ?? 'Cuenta conectada',
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
            onPressed: _busy ? null : _signOut,
            child: const Text('Cerrar sesión'),
          ),
          Text(
            'Tu progreso local se conserva al cerrar sesión.',
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

class _AuthSheet extends StatefulWidget {
  const _AuthSheet({required this.create});

  final bool create;

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@') || password.length < 6) {
      setState(
          () => _error = 'Usá un correo válido y una clave de 6 caracteres.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.create) {
        final hasSession = await CloudSyncService.signUp(email, password);
        if (!mounted) return;
        if (!hasSession) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          messenger.showSnackBar(const SnackBar(
            content: Text('Revisá tu correo para confirmar la cuenta.'),
          ));
          return;
        }
      } else {
        await CloudSyncService.signIn(email, password);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = CloudSyncService.error.value ??
              'No se pudo conectar. Revisá los datos e intentá de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.locked,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.create ? 'Crear cuenta' : 'Iniciar sesión',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tu progreso se sincroniza sin guardar imágenes ni reportes. '
              'Si ya tenés un apodo local, se conserva.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Correo',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: [
                widget.create
                    ? AutofillHints.newPassword
                    : AutofillHints.password
              ],
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: TextStyle(color: AppColors.error, fontSize: 12.5)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading
                  ? 'CONECTANDO…'
                  : widget.create
                      ? 'CREAR CUENTA'
                      : 'ENTRAR'),
            ),
            TextButton(
              onPressed: _loading ? null : () => Navigator.pop(context),
              child: const Text('Ahora no'),
            ),
          ],
        ),
      ),
    );
  }
}
