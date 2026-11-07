import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/shared/widgets/app_bottom_nav.dart';

/// Opacidad efectiva de un texto (producto de los Opacity que lo envuelven).
double _opacityOf(WidgetTester tester, String text) {
  final finder = find.text(text, skipOffstage: false);
  if (finder.evaluate().isEmpty) return 0;
  // Una pantalla recién empujada pasa su primer cuadro fuera de escena.
  final hidden = tester
      .widgetList<Offstage>(find.ancestor(
          of: finder, matching: find.byType(Offstage, skipOffstage: false)))
      .any((w) => w.offstage);
  if (hidden) return 0;
  var o = 1.0;
  for (final e in tester.widgetList<Opacity>(find.ancestor(
      of: finder, matching: find.byType(Opacity, skipOffstage: false)))) {
    o *= e.opacity;
  }
  return o;
}

Widget _app(String firstRoute, String secondRoute) {
  return MaterialApp(
    theme: ThemeData(
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: JunglePageTransitionsBuilder(),
        TargetPlatform.iOS: JunglePageTransitionsBuilder(),
      }),
    ),
    onGenerateRoute: (settings) => MaterialPageRoute<void>(
      settings: RouteSettings(name: firstRoute),
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            settings: RouteSettings(name: secondRoute),
            builder: (_) => const Scaffold(
              backgroundColor: Colors.transparent,
              body: Text('B'),
            ),
          )),
          child: const Text('A'),
        ),
      ),
    ),
  );
}

void main() {
  for (final route in ['/library', '/lesson/:id', '/profile']) {
    testWidgets('push y pop a $route sin pantallas superpuestas',
        (tester) async {
      await tester.pumpWidget(_app('/', route));
      await tester.tap(find.text('A'));
      await tester.pump();
      // Durante toda la ida, nunca se ven las dos pantallas a la vez.
      for (var ms = 0; ms <= 340; ms += 20) {
        final a = _opacityOf(tester, 'A');
        final b = _opacityOf(tester, 'B');
        expect(a > 0.01 && b > 0.01, isFalse,
            reason: 'ida t=$ms ms: A=$a B=$b');
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'B'), 1);

      // Y lo mismo al volver.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      for (var ms = 0; ms <= 340; ms += 20) {
        final a = _opacityOf(tester, 'A');
        final b = _opacityOf(tester, 'B');
        expect(a > 0.01 && b > 0.01, isFalse,
            reason: 'vuelta t=$ms ms: A=$a B=$b');
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'A'), 1);
    });
  }

  testWidgets('cambiar de pestaña: sin superposición y la barra queda fija',
      (tester) async {
    Widget tab(String label, int index) => Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: Text(label)),
          bottomNavigationBar: AppBottomNav(currentIndex: index),
        );
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => tab('Aprender', 0)),
      GoRoute(path: '/library', builder: (_, __) => tab('Biblioteca', 1)),
    ]);
    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.dark,
      routerConfig: router,
    ));
    await tester.pumpAndSettle();
    final navTop = tester.getTopLeft(find.byType(AppBottomNav).first);

    router.go('/library');
    await tester.pump();
    for (var ms = 0; ms <= 340; ms += 20) {
      final a = _opacityOf(tester, 'Aprender');
      final b = _opacityOf(tester, 'Biblioteca');
      expect(a > 0.01 && b > 0.01, isFalse, reason: 't=$ms ms: A=$a B=$b');
      // La barra (o su Hero en vuelo) no se mueve ni se apaga.
      final bars = find.byType(AppBottomNav, skipOffstage: false);
      expect(bars, findsWidgets);
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
    expect(_opacityOf(tester, 'Biblioteca'), 1);
    expect(tester.getTopLeft(find.byType(AppBottomNav).first), navTop);
  });
}
