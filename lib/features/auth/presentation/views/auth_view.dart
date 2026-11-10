import 'package:flutter/material.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/auth/presentation/widgets/reset_password_sheet.dart';
import 'package:senasgo/features/cloud/data/cloud_sync_service.dart';
import 'package:senasgo/shared/widgets/jaguarete_mascot.dart';

/// Acceso obligatorio: crear cuenta o iniciar sesión.
///
/// Es la primera pantalla de la app. Cuando la sesión queda iniciada,
/// [CloudSyncService.session] cambia y el router lleva a la bienvenida (cuenta
/// nueva) o al camino (cuenta existente). La sesión se guarda en el teléfono.
class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _create = true;
  bool _loading = false;
  bool _hidePassword = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _switchMode(bool create) {
    if (_loading || create == _create) return;
    setState(() {
      _create = create;
      _error = null;
      _info = null;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (_create && name.isEmpty) {
      setState(() => _error = 'Escribí tu nombre.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Escribí un correo válido.');
      return;
    }
    if (password.length < 6) {
      setState(
          () => _error = 'La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      if (_create) {
        final hasSession = await CloudSyncService.signUp(email, password, name);
        if (!mounted) return;
        if (!hasSession) {
          // Supabase pide confirmar el correo antes de la primera entrada.
          setState(() {
            _loading = false;
            _create = false;
            _password.clear();
            _info = 'Te enviamos un correo a $email. Confirmá tu cuenta y '
                'después iniciá sesión.';
          });
        }
      } else {
        await CloudSyncService.signIn(email, password);
      }
      // Con sesión, el router cambia de pantalla solo.
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = CloudSyncService.error.value ??
            (_create
                ? 'No se pudo crear la cuenta. Revisá tu conexión o probá '
                    'con otro correo.'
                : 'Correo o contraseña incorrectos, o no hay conexión.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = CloudSyncService.configured;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF04120F),
              AppColors.primary,
              const Color(0xFF2DD4BF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: JaguareteMascot(size: 96)),
                    const SizedBox(height: 12),
                    Text(
                      _create ? 'Creá tu cuenta' : 'Bienvenido de nuevo',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _create
                          ? 'Tu progreso queda guardado en tu cuenta y lo '
                              'recuperás en cualquier teléfono.'
                          : 'Iniciá sesión para seguir donde lo dejaste.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 14.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _card(configured),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(bool configured) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: configured ? _form() : _notConfigured(),
    );
  }

  Widget _notConfigured() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 36),
        const SizedBox(height: 10),
        Text(
          'Falta configurar el servidor',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Esta versión de la app se compiló sin los datos de Supabase '
          '(SUPABASE_URL y SUPABASE_ANON_KEY), por eso no puede crear cuentas '
          'ni iniciar sesión. Ver docs/SUPABASE.md.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }

  Widget _form() {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Crear cuenta')),
              ButtonSegment(value: false, label: Text('Iniciar sesión')),
            ],
            selected: {_create},
            showSelectedIcon: false,
            onSelectionChanged: (s) => _switchMode(s.first),
          ),
          const SizedBox(height: 16),
          if (_create) ...[
            TextField(
              controller: _name,
              enabled: !_loading,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              maxLength: 24,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                counterText: '',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _email,
            enabled: !_loading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Correo',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _password,
            enabled: !_loading,
            obscureText: _hidePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            autofillHints: [
              _create ? AutofillHints.newPassword : AutofillHints.password
            ],
            decoration: InputDecoration(
              labelText: 'Contraseña',
              helperText: _create ? 'Al menos 6 caracteres' : null,
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip:
                    _hidePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
                icon: Icon(_hidePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
              ),
            ),
          ),
          if (!_create)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading
                    ? null
                    : () => ResetPasswordSheet.show(context,
                        email: _email.text.trim()),
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _Message(text: _error!, color: AppColors.error),
          ],
          if (_info != null) ...[
            const SizedBox(height: 12),
            _Message(text: _info!, color: AppColors.success),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Text(_create ? 'CREAR CUENTA' : 'INICIAR SESIÓN'),
          ),
          const SizedBox(height: 10),
          Text(
            'No guardamos imágenes de la cámara ni tus reportes en la nube.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 13, height: 1.35),
      ),
    );
  }
}
