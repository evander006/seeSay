import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:seesay/app/theme/app_theme.dart';
import 'package:seesay/core/accessibility/accessibility_audio_service.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/accessibility/tts_engine.dart';
import 'package:seesay/core/camera/camera_service.dart';
import 'package:seesay/core/camera/capture_gate.dart';
import 'package:seesay/core/camera/frame_compressor.dart';
import 'package:seesay/core/config/app_config.dart';
import 'package:seesay/core/location/location_service.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/permissions/permission_service.dart';
import 'package:seesay/core/storage/response_storage.dart';
import 'package:seesay/core/storage/settings_store.dart';
import 'package:seesay/features/events/domain/glasses_event_repository.dart';
import 'package:seesay/features/events/presentation/events_cubit.dart';
import 'package:seesay/features/glasses/data/mock_glasses_repository.dart';
import 'package:seesay/features/glasses/domain/glasses_use_cases.dart';
import 'package:seesay/features/glasses/presentation/connection_cubit.dart';
import 'package:seesay/features/home/presentation/app_cubit.dart';
import 'package:seesay/features/home/presentation/app_scope.dart';
import 'package:seesay/features/home/presentation/home_page.dart';
import 'package:seesay/features/ocr/presentation/ocr_cubit.dart';
import 'package:seesay/features/settings/presentation/accessibility_cubit.dart';
import 'package:seesay/features/vision/data/mock_vision_api.dart';
import 'package:seesay/features/vision/data/vision_repository_impl.dart';
import 'package:seesay/features/vision/domain/analyze_frame.dart';
import 'package:seesay/features/vision/domain/capture_frame.dart';
import 'package:seesay/features/vision/domain/response_use_cases.dart';
import 'package:seesay/features/vision/presentation/vision_cubit.dart';

import 'fakes.dart';

class ShowableVisionCubit extends VisionCubit {
  ShowableVisionCubit({
    required super.captureFrame,
    required super.analyzeFrame,
    required super.saveLastResponse,
    required super.speakText,
    required super.connectivity,
    required super.location,
    required super.feedback,
    required super.gate,
    required super.logger,
  });

  void show(VisionState next) => emit(next);
}

class HomeHarness {
  HomeHarness() {
    final logger = AppLogger();
    final settings = MemorySettingsStore();
    storage = MemoryResponseStorage();
    connectivity = FakeConnectivity(online: true);
    engine = MockTtsEngine();
    audio = AccessibilityAudioService(engine: engine, logger: logger);
    final glasses = MockGlassesRepository(connectDelay: Duration.zero);
    final capture = CaptureFrame(
      camera: MockCameraService(),
      compressor: FrameCompressor(directory: storageDir),
    );
    final remote = MockVisionRemoteDataSource(delay: Duration.zero);
    final feedback = QuietFeedback();
    final gate = CaptureGate();
    vision = ShowableVisionCubit(
      captureFrame: capture,
      analyzeFrame: AnalyzeFrame(
        VisionRepositoryImpl(remote: remote, connectivity: connectivity),
      ),
      saveLastResponse: SaveLastResponse(storage),
      speakText: SpeakText(audio),
      connectivity: connectivity,
      location: NullLocationService(),
      feedback: feedback,
      gate: gate,
      logger: logger,
    );
    ocr = OcrCubit(
      captureFrame: capture,
      readText: ReadText(
        OcrRepositoryImpl(remote: remote, connectivity: connectivity),
      ),
      saveLastResponse: SaveLastResponse(storage),
      speakText: SpeakText(audio),
      connectivity: connectivity,
      feedback: feedback,
      gate: gate,
      logger: logger,
    );
    connection = ConnectionCubit(
      repository: glasses,
      connectGlasses: ConnectGlasses(
        repository: glasses,
        permissions: PermissionService(logger: logger),
        settings: settings,
        config: AppConfig.defaults,
        logger: logger,
      ),
      disconnectGlasses: DisconnectGlasses(glasses),
      speakText: SpeakText(audio),
      feedback: feedback,
      settings: settings,
      logger: logger,
    );
    appCubit = AppCubit(
      config: AppConfig.defaults,
      connectivity: connectivity,
      glasses: glasses,
      speakText: SpeakText(audio),
      logger: logger,
    );
    accessibility = AccessibilityCubit(settings: settings, audio: audio);
    events = EventsCubit(
      repository: MemoryGlassesEventRepository(),
      speakText: SpeakText(audio),
    );
    final repeat = RepeatLastResponse(storage: storage, audio: audio);
    router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomePage()),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SizedBox(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const SizedBox(),
        ),
      ],
    );
    _repeat = repeat.call;
    _feedback = feedback;
  }

  late final MemoryResponseStorage storage;
  late final FakeConnectivity connectivity;
  late final MockTtsEngine engine;
  late final AccessibilityAudioService audio;
  late final ShowableVisionCubit vision;
  late final OcrCubit ocr;
  late final ConnectionCubit connection;
  late final AppCubit appCubit;
  late final AccessibilityCubit accessibility;
  late final EventsCubit events;
  late final GoRouter router;
  late final Future<void> Function() _repeat;
  late final QuietFeedback _feedback;

  Widget app() {
    return MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) {
        return AppScope(
          audio: audio,
          feedback: _feedback,
          repeatLast: _repeat,
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: appCubit),
              BlocProvider.value(value: connection),
              BlocProvider<VisionCubit>.value(value: vision),
              BlocProvider.value(value: ocr),
              BlocProvider.value(value: accessibility),
              BlocProvider.value(value: events),
            ],
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  Future<void> dispose() async {
    router.dispose();
    await vision.close();
    await ocr.close();
    await connection.close();
    await appCubit.close();
    await accessibility.close();
    await events.close();
  }
}
