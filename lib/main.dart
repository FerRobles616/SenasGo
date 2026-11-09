import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as prov;
import 'package:senasgo/core/config/hive_config.dart';
import 'package:senasgo/core/services/camera_service.dart';
import 'package:senasgo/core/services/device_performance.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/features/cloud/data/cloud_sync_service.dart';
import 'package:senasgo/core/services/inference_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/core/theme/theme_controller.dart';
import 'package:senasgo/features/avatar/presentation/views/teacher_view.dart';
import 'package:senasgo/features/challenges/presentation/views/challenges_view.dart';
import 'package:senasgo/features/chests/presentation/views/reward_chest_view.dart';
import 'package:senasgo/features/home/presentation/views/learning_path_view.dart';
import 'package:senasgo/features/learning/presentation/views/lesson_guide_view.dart';
import 'package:senasgo/features/learning/presentation/views/lesson_list_view.dart';
import 'package:senasgo/features/learning/presentation/views/lesson_view.dart';
import 'package:senasgo/features/onboarding/presentation/views/onboarding_view.dart';
import 'package:senasgo/features/onboarding/presentation/views/welcome_reward_view.dart';
import 'package:senasgo/features/practice/presentation/controllers/practice_controller.dart';
import 'package:senasgo/features/practice/presentation/views/practice_view.dart';
import 'package:senasgo/features/profile/presentation/views/community_view.dart';
import 'package:senasgo/features/profile/presentation/views/home_shortcut_view.dart';
import 'package:senasgo/features/profile/presentation/views/league_view.dart';
import 'package:senasgo/features/profile/presentation/views/profile_view.dart';
import 'package:senasgo/features/progress/presentation/views/progress_view.dart';
import 'package:senasgo/features/quiz/presentation/views/quiz_view.dart';
import 'package:senasgo/features/streak/presentation/views/streak_view.dart';
import 'package:senasgo/features/support/domain/support_ticket.dart';
import 'package:senasgo/features/support/presentation/views/help_view.dart';
import 'package:senasgo/features/support/presentation/views/support_form_view.dart';
import 'package:senasgo/shared/models/user_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Vertical fijo: el recorte del recuadro guía asume la app en portrait.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // RAM del equipo -> fallback visual del avatar y FPS de análisis.
  await DevicePerformance.init();

  // Persistencia local (Hive) - 100% offline
  await HiveConfig.init();
  await HiveService.registerAdapters();
  await HiveService.initBoxes();
  await HiveService.seedIfEmpty();
  if (HiveService.userBox.isEmpty) {
    await HiveService.saveUser(UserModel.initial());
  }
  ThemeController.init();
  await CloudSyncService.initialize();

  // Cámara disponible en el dispositivo (si falla, la app sigue navegable)
  List<CameraDescription> cameras;
  try {
    cameras = await availableCameras();
  } catch (_) {
    cameras = <CameraDescription>[];
  }

  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatefulWidget {
  const MyApp({required this.cameras, super.key});

  final List<CameraDescription> cameras;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Se crea una sola vez: si se recreara en cada build (p. ej. cuando
  // ScreenUtilInit reacciona a un cambio de MediaQuery) la navegación
  // volvería al inicio y se cerraría la pantalla de práctica.
  late final GoRouter _router = _buildRouter(widget.cameras);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) => ListenableBuilder(
        listenable: ThemeController.instance,
        builder: (context, _) => MaterialApp.router(
          title: 'SeñasGo',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeController.instance.mode,
          // Sin fundido: las pantallas leen la paleta de AppColors y no
          // pueden mezclarse con un tema a medio camino.
          themeAnimationDuration: Duration.zero,
          routerConfig: _router,
          builder: (context, child) {
            // Fija la paleta del tema activo antes de construir las
            // pantallas.
            final dark = Theme.of(context).brightness == Brightness.dark;
            final palette = dark ? AppPalette.dark : AppPalette.light;
            if (!identical(AppColors.palette, palette)) {
              AppColors.use(palette);
              // GoRouter conserva su Navigator (GlobalKey): los widgets
              // const y los pintores no se reconstruirían solos y quedarían
              // con la paleta anterior. Igual que el hot reload, se marca
              // todo el árbol para construir y pintar de nuevo.
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => WidgetsBinding.instance.reassembleApplication());
            }
            return JungleBackdrop(child: child!);
          },
        ),
      ),
    );
  }
}

GoRouter _buildRouter(List<CameraDescription> cameras) {
  return GoRouter(
    initialLocation: HiveService.onboardingDone ? '/' : '/welcome',
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('SeñasGo')),
      body: Center(child: Text('Pantalla no encontrada: ${state.uri}')),
    ),
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const OnboardingView(),
      ),
      GoRoute(
        path: '/welcome-reward',
        builder: (context, state) => const WelcomeRewardView(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const LearningPathView(),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) => const LessonListView(),
      ),
      GoRoute(
        path: '/lesson-guide/:id',
        builder: (context, state) =>
            LessonGuideView(lessonId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/lesson/:id',
        builder: (context, state) => LessonView(
          lessonId: state.pathParameters['id']!,
          initialSignId: state.uri.queryParameters['sign'],
        ),
      ),
      GoRoute(
        path: '/teacher/:signId',
        builder: (context, state) =>
            TeacherView(signId: state.pathParameters['signId']!),
      ),
      GoRoute(
        path: '/chest/:lessonId',
        builder: (context, state) =>
            RewardChestView(lessonId: state.pathParameters['lessonId']!),
      ),
      GoRoute(
        path: '/challenges',
        builder: (context, state) => const ChallengesView(),
      ),
      GoRoute(
        path: '/streak',
        builder: (context, state) => const StreakView(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileView(),
      ),
      GoRoute(
        path: '/league',
        builder: (context, state) => const LeagueView(),
      ),
      GoRoute(
        path: '/community',
        builder: (context, state) => const CommunityView(),
      ),
      GoRoute(
        path: '/shortcut',
        builder: (context, state) => const HomeShortcutView(),
      ),
      GoRoute(
        path: '/progress',
        builder: (context, state) => const ProgressView(),
      ),
      GoRoute(
        path: '/help',
        builder: (context, state) => const HelpView(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => SupportFormView(
          initialCategory:
              SupportCategory.fromName(state.uri.queryParameters['category']),
          contextLabel: state.uri.queryParameters['context'],
        ),
      ),
      GoRoute(
        path: '/quiz',
        builder: (context, state) =>
            QuizView(lessonId: state.uri.queryParameters['lesson']),
      ),
      GoRoute(
        path: '/practice',
        builder: (context, state) => prov.MultiProvider(
          providers: [
            prov.ChangeNotifierProvider(
              create: (_) => CameraService(cameras),
            ),
            prov.ChangeNotifierProvider(
              create: (_) => InferenceService(),
            ),
            prov.ChangeNotifierProxyProvider2<CameraService, InferenceService,
                PracticeController>(
              create: (context) => PracticeController(
                cameraService: context.read<CameraService>(),
                inferenceService: context.read<InferenceService>(),
              ),
              update: (context, camera, inference, previous) =>
                  previous ??
                  PracticeController(
                    cameraService: camera,
                    inferenceService: inference,
                  ),
            ),
          ],
          child: PracticeView(
            lessonId: state.uri.queryParameters['lesson'],
            startSignId: state.uri.queryParameters['sign'],
          ),
        ),
      ),
    ],
  );
}
