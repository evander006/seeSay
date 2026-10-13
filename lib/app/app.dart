import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:seesay/app/app_messenger.dart';
import 'package:seesay/app/di/injection.dart';
import 'package:seesay/app/failure_toaster.dart';
import 'package:seesay/app/theme/app_theme.dart';
import 'package:seesay/core/accessibility/accessibility_audio_service.dart';
import 'package:seesay/core/accessibility/haptic_service.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/permissions/permission_service.dart';
import 'package:seesay/features/glasses/presentation/connection_cubit.dart';
import 'package:seesay/features/home/presentation/app_cubit.dart';
import 'package:seesay/features/home/presentation/app_scope.dart';
import 'package:seesay/features/events/presentation/events_cubit.dart';
import 'package:seesay/features/shell/main_shell.dart';
import 'package:seesay/features/ocr/presentation/ocr_cubit.dart';
import 'package:seesay/features/settings/presentation/accessibility_cubit.dart';
import 'package:seesay/features/settings/presentation/history_cubit.dart';
import 'package:seesay/features/settings/presentation/history_page.dart';
import 'package:seesay/features/settings/presentation/settings_page.dart';
import 'package:seesay/features/vision/presentation/vision_cubit.dart';

class SeeSayApp extends StatelessWidget {
  const SeeSayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SeeSay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scaffoldMessengerKey: appMessengerKey,
      routerConfig: getIt<GoRouter>(),
      builder: (context, child) {
        return AppScope(
            audio: getIt<AccessibilityAudioService>(),
            feedback: getIt<SystemFeedback>(),
            repeatLast: getIt<RepeatLastResponse>().call,
            child: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: getIt<AppCubit>()),
                BlocProvider.value(value: getIt<ConnectionCubit>()),
                BlocProvider.value(value: getIt<VisionCubit>()),
                BlocProvider.value(value: getIt<OcrCubit>()),
                BlocProvider.value(value: getIt<AccessibilityCubit>()),
                BlocProvider.value(value: getIt<EventsCubit>()),
              ],
              child: FailureToaster(child: child ?? const SizedBox.shrink()),
            ),
        );
      },
    );
  }
}

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/home'),
      GoRoute(path: '/home', builder: (context, state) => const MainShell()),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: SettingsPage(
            onOpenSystemSettings: () =>
                getIt<PermissionService>().openSettings(),
          ),
        ),
      ),
      GoRoute(
        path: '/history',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: BlocProvider(
            create: (_) => getIt<HistoryCubit>()..load(),
            child: const HistoryPage(),
          ),
        ),
      ),
    ],
  );
}
