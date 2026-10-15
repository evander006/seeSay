import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:seesay/app/theme/app_theme.dart';
import 'package:seesay/core/accessibility/accessibility_audio_service.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/camera/capture_gate.dart';
import 'package:seesay/core/location/location_service.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/network/api_client.dart';
import 'package:seesay/core/storage/frame_store.dart';
import 'package:seesay/core/storage/response_storage.dart';
import 'package:seesay/core/storage/settings_store.dart';
import 'package:seesay/features/backend/backend_cubit.dart';
import 'package:seesay/features/glasses/domain/glasses_use_cases.dart';
import 'package:seesay/features/glasses/presentation/connection_cubit.dart';
import 'package:seesay/features/home/presentation/app_cubit.dart';
import 'package:seesay/features/home/presentation/app_scope.dart';
import 'package:seesay/features/home/presentation/home_page.dart';
import 'package:seesay/features/ocr/presentation/ocr_cubit.dart';
import 'package:seesay/features/settings/presentation/accessibility_cubit.dart';
import 'package:seesay/features/vision/data/vision_repository_impl.dart';
import 'package:seesay/features/vision/domain/analyze_frame.dart';
import 'package:seesay/features/vision/domain/capture_frame.dart';
import 'package:seesay/features/vision/domain/response_use_cases.dart';
import 'package:seesay/features/vision/presentation/vision_cubit.dart';

import 'fake_glasses_repository.dart';
import 'fake_vision_api.dart';
import 'fakes.dart';

class ShowableVisionCubit extends VisionCubit {
  ShowableVisionCubit({
    required super.captureFrame,
    required super.analyzeFrame,
    required super.saveLastResponse,
    required super.speakText,
    required super.frames,
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
    settings = MemorySettingsStore();
    storage = MemoryResponseStorage();
    connectivity = FakeConnectivity(online: true);
    engine = MockTtsEngine();
    audio = AccessibilityAudioService(engine: engine, logger: logger);
    glasses = MockGlassesRepository(connectDelay: Duration.zero);
    final capture = CaptureFrame(camera: MockCameraService());
    final remote = MockVisionRemoteDataSource(delay: Duration.zero);
    final feedback = QuietFeedback();
    final gate = CaptureGate();
    final frames = FrameStore(directory: storageDir);
    vision = ShowableVisionCubit(
      captureFrame: capture,
      analyzeFrame: AnalyzeFrame(VisionRepositoryImpl(remote: remote)),
      saveLastResponse: SaveLastResponse(storage),
      speakText: SpeakText(audio),
      frames: frames,
      location: NullLocationService(),
      feedback: feedback,
      gate: gate,
      logger: logger,
    );
    ocr = OcrCubit(
      captureFrame: capture,
      readText: ReadText(OcrRepositoryImpl(remote: remote)),
      saveLastResponse: SaveLastResponse(storage),
      speakText: SpeakText(audio),
      frames: frames,
      feedback: feedback,
      gate: gate,
      logger: logger,
    );
    connection = ConnectionCubit(
      repository: glasses,
      connectGlasses: ConnectGlasses(
        repository: glasses,
        permissions: AllowAllPermissions(),
        settings: settings,
        logger: logger,
      ),
      disconnectGlasses: DisconnectGlasses(glasses),
      speakText: SpeakText(audio),
      feedback: feedback,
      settings: settings,
      logger: logger,
    );
    appCubit = AppCubit(
      connectivity: connectivity,
      glasses: glasses,
      speakText: SpeakText(audio),
      logger: logger,
    );
    probe = FakeProbe();
    backend = BackendCubit(
      client: ApiClient(baseUrl: 'http://192.168.0.128:8000', logger: logger),
      settings: settings,
      probe: probe,
      fallbackUrl: 'http://192.168.0.128:8000',
    );
    accessibility = AccessibilityCubit(settings: settings, audio: audio);
    final repeat = RepeatLastResponse(storage: storage, audio: audio);
    router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomePage()),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SizedBox(),
        ),
      ],
    );
    _repeat = repeat.call;
    _feedback = feedback;
  }

  late final MemorySettingsStore settings;
  late final MemoryResponseStorage storage;
  late final FakeConnectivity connectivity;
  late final MockTtsEngine engine;
  late final AccessibilityAudioService audio;
  late final MockGlassesRepository glasses;
  late final ShowableVisionCubit vision;
  late final OcrCubit ocr;
  late final ConnectionCubit connection;
  late final AppCubit appCubit;
  late final FakeProbe probe;
  late final BackendCubit backend;
  late final AccessibilityCubit accessibility;
  late final GoRouter router;
  late final Future<void> Function() _repeat;
  late final QuietFeedback _feedback;

  Widget wrap(Widget child) {
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
          BlocProvider.value(value: backend),
        ],
        child: child,
      ),
    );
  }

  Widget app() {
    return MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) => wrap(child ?? const SizedBox.shrink()),
    );
  }

  Future<void> dispose() async {
    router.dispose();
    await vision.close();
    await ocr.close();
    await connection.close();
    await appCubit.close();
    await backend.close();
    await accessibility.close();
  }
}
