import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/cloud/data/cloud_sync_service.dart';

/// Recuperar contraseña en dos pasos, sin salir de la app:
/// 1) correo → Supabase envía un código de 6 dígitos;
/// 2) código + contraseña nueva → se valida, se guarda y se inicia sesión.
class ResetPasswordSheet extends StatefulWidget {
  const ResetPasswordSheet({this.initialEmail = '', super.key});

  final String initialEmail;

  static Future<void> show(BuildContext context, {String email = ''}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => ResetPasswordSheet(initialEmail: email),
    );
  }

  @override
  State<ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<ResetPasswordSheet> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Escribí el correo de tu cuenta.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await CloudSyncService.sendPasswordResetCode(email);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _codeSent = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(e,
            fallback: 'No se pudo enviar el código. Revisá tu conexión.');
      });
    }
  }

  Future<void> _confirm() async {
    final code = _code.text.trim();
    final password = _password.text;
    if (code.length < 6) {
      setState(() => _error = 'Escribí el código de 6 dígitos del correo.');
      return;
    }
    if (password.length < 6) {
      setState(() =>
          _error = 'La contraseña nueva debe tener al menos 6 caracteres.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await CloudSyncService.resetPasswordWithCode(
        email: _email.text,
        code: code,
        newPassword: password,
      );
      // Con la sesión iniciada, el router lleva a la app.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(e,
            fallback: 'El código no es válido o ya venció. Pedí uno nuevo.');
      });
    }
  }

  String _message(Object e, {required String fallback}) {
    if (e is AuthException) {
      final m = e.message.toLowerCase();
      if (m.contains('expired') || m.contains('invalid')) {
        return 'El código no es válido o ya venció. Pedí uno nuevo.';
      }
      if (m.contains('rate') || m.contains('seconds')) {
        return 'Esperá un minuto antes de pedir otro código.';
      }
      if (m.contains('same') || m.contains('different')) {
        return 'La contraseña nueva tiene que ser distinta a la anterior.';
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 14, 20, 18 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
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
                'Recuperar contraseña',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _codeSent
                    ? 'Te enviamos un código de 6 dígitos a '
                        '${_email.text.trim()}. Escribilo junto con tu '
                        'contraseña nueva.'
                    : 'Escribí el correo de tu cuenta y te enviamos un '
                        'código para crear una contraseña nueva.',
                style: TextStyle(
                    color: AppColors.muted, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                enabled: !_loading && !_codeSent,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _code,
                  enabled: !_loading,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: const InputDecoration(
                    labelText: 'Código del correo',
                    counterText: '',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _password,
                  enabled: !_loading,
                  obscureText: _hidePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _confirm(),
                  decoration: InputDecoration(
                    labelText: 'Contraseña nueva',
                    helperText: 'Al menos 6 caracteres',
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                    suffixIcon: IconButton(
                      tooltip: _hidePassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(_hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(_error!,
                      style: TextStyle(
                          color: AppColors.error, fontSize: 13, height: 1.35)),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : (_codeSent ? _confirm : _sendCode),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Text(_codeSent ? 'CAMBIAR CONTRASEÑA' : 'ENVIAR CÓDIGO'),
              ),
              if (_codeSent)
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _codeSent = false;
                            _code.clear();
                            _error = null;
                          }),
                  child: const Text('No me llegó: pedir otro código'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
