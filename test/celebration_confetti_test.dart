import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senasgo/shared/widgets/celebration_confetti.dart';

void main() {
  testWidgets('El confeti no bloquea los toques y ocupa el espacio disponible',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: FilledButton(
                  onPressed: () => tapped = true,
                  child: const Text('Continuar'),
                ),
              ),
              const Positioned.fill(
                child: CelebrationConfetti(
                  active: true,
                  duration: Duration(milliseconds: 100),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    expect(
      tester.getSize(find.byType(CelebrationConfetti)).width,
      greaterThan(0),
    );

    await tester.tap(find.text('Continuar'));
    expect(tapped, isTrue);
    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets('El confeti respeta la preferencia de movimiento reducido',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: CelebrationConfetti(active: true),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(
      tester.getSize(find.byType(CelebrationConfetti)).width,
      0,
    );
  });
}
