import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/home/domain/learning_path.dart';
import 'package:senasgo/features/home/presentation/widgets/lesson_node.dart';
import 'package:senasgo/features/home/presentation/widgets/top_stats_bar.dart';
import 'package:senasgo/features/learning/data/seed_data.dart';

Widget _statsApp(
  PlayerStats stats, {
  required Size size,
  required ThemeData theme,
  bool reduceMotion = false,
}) {
  return MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(size: size, disableAnimations: reduceMotion),
      child: Scaffold(
        body: CustomScrollView(
          slivers: [TopStatsBar(stats: stats)],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Las estadísticas se actualizan sin desbordar a 360 y 430',
      (tester) async {
    for (final size in const [Size(360, 800), Size(430, 900)]) {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(_statsApp(
          const PlayerStats(streak: 3, practicedToday: true, xp: 30),
          size: size,
          theme: theme,
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(_statsApp(
          const PlayerStats(streak: 4, practicedToday: true, xp: 40),
          size: size,
          theme: theme,
        ));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('40'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 700));
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Con reducir animaciones no se lanza el rebote de estadísticas',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    await tester.pumpWidget(_statsApp(
      const PlayerStats(streak: 3, practicedToday: true, xp: 30),
      size: const Size(360, 800),
      theme: AppTheme.light,
      reduceMotion: true,
    ));
    await tester.pump();
    await tester.pumpWidget(_statsApp(
      const PlayerStats(streak: 9, practicedToday: true, xp: 120),
      size: const Size(360, 800),
      theme: AppTheme.light,
      reduceMotion: true,
    ));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('120'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('El nodo cambia de seña actual a completada con transición',
      (tester) async {
    final sign = SeedData.signs.first;
    PathNode node(NodeStatus status) => PathNode(
          sign: sign,
          lessonId: SeedData.lessons.first.id,
          status: status,
          indexInPath: 0,
        );

    Widget app(PathNode value) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: LessonNode(
                node: value,
                palette: UnitPalette.all.first,
                onTap: () {},
              ),
            ),
          ),
        );

    await tester.pumpWidget(app(node(NodeStatus.current)));
    await tester.pump();
    expect(find.byIcon(Icons.sign_language_rounded), findsOneWidget);

    await tester.pumpWidget(app(node(NodeStatus.completed)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.sign_language_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
