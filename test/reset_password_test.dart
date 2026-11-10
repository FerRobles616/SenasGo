import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/auth/presentation/widgets/reset_password_sheet.dart';

/// La hoja de recuperación valida los datos antes de llamar al servidor.
void main() {
  Widget host() => MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: ResetPasswordSheet()),
      );

  testWidgets('Pide un correo válido antes de enviar el código',
      (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('Recuperar contraseña'), findsOneWidget);
    expect(find.text('ENVIAR CÓDIGO'), findsOneWidget);

    await tester.tap(find.text('ENVIAR CÓDIGO'));
    await tester.pump();
    expect(find.text('Escribí el correo de tu cuenta.'), findsOneWidget);
  });

  testWidgets('Sin servidor muestra un error claro y no avanza al código',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(find.byType(TextField).first, 'ana@example.com');
    await tester.tap(find.text('ENVIAR CÓDIGO'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('No se pudo enviar el código'), findsOneWidget);
    expect(find.text('CAMBIAR CONTRASEÑA'), findsNothing);
  });
}
