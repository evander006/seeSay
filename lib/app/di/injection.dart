import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:seesay/app/app.dart';
import 'package:seesay/core/accessibility/accessibility_audio_service.dart';
import 'package:seesay/core/accessibility/haptic_service.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/accessibility/tts_engine.dart';
import 'package:seesay/core/bluetooth/ble_packet_parser.dart';
import 'package:seesay/core/camera/camera_service.dart';
import 'package:seesay/core/camera/capture_gate.dart';
import 'package:seesay/core/config/app_config.dart';
import 'package:seesay/core/location/location_service.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/network/api_client.dart';
import 'package:seesay/core/network/connectivity_service.dart';
import 'package:seesay/core/network/retry_policy.dart';
import 'package:seesay/core/permissions/permission_service.dart';
import 'package:seesay/core/platform/background_access.dart';
import 'package:seesay/core/platform/glasses_channel.dart';
import 'package:seesay/core/storage/frame_store.dart';
import 'package:seesay/core/storage/response_storage.dart';
import 'package:seesay/core/storage/settings_store.dart';
import 'package:seesay/features/assistant/presentation/assistant_cubit.dart';
import 'package:seesay/features/backend/backend_cubit.dart';
import 'package:seesay/features/backend/backend_probe.dart';
import 'package:seesay/features/gallery/presentation/gallery_cubit.dart';
import 'package:seesay/features/glasses/data/glasses_repository_impl.dart';
import 'package:seesay/features/glasses/domain/glasses_repository.dart';
import 'package:seesay/features/glasses/domain/glasses_use_cases.dart';
import 'package:seesay/features/glasses/presentation/connection_cubit.dart';
import 'package:seesay/features/glasses/data/glasses_api.dart';
import 'package:seesay/features/glasses/presentation/glasses_action_coordinator.dart';
import 'package:seesay/features/home/presentation/app_cubit.dart';
import 'package:seesay/features/ocr/presentation/ocr_cubit.dart';
import 'package:seesay/features/settings/presentation/accessibility_cubit.dart';
import 'package:seesay/features/vision/data/vision_remote_data_source.dart';
import 'package:seesay/features/vision/data/vision_remote_data_source_impl.dart';
import 'package:seesay/features/vision/data/vision_repository_impl.dart';
import 'package:seesay/features/vision/domain/analyze_frame.dart';
import 'package:seesay/features/vision/domain/capture_frame.dart';
import 'package:seesay/features/vision/domain/response_use_cases.dart';
import 'package:seesay/features/vision/presentation/vision_cubit.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies({AppConfig? config}) async {
  await _shutdown();
  final effective = config ?? await AppConfig.load();
  getIt.registerSingleton<AppConfig>(effective);
  final channel = GlassesChannel();
  final logger = AppLogger(sink: (level, line) => channel.diagLog(level, line));
  getIt.registerSingleton<AppLogger>(logger);

  final permissions = PermissionService(logger: logger);
  getIt
    ..registerSingleton<GlassesChannel>(channel)
    ..registerSingleton<PermissionService>(permissions)
    ..registerSingleton<BlePacketParser>(BlePacketParser())
    ..registerSingleton<CaptureGate>(CaptureGate())
    ..registerSingleton<ConnectivityService>(DeviceConnectivityService())
    ..registerSingleton<ApiClient>(
      ApiClient(baseUrl: effective.apiBaseUrl, logger: logger),
    )
    ..registerSingleton<ResponseStorage>(HiveResponseStorage())
    ..registerSingleton<SettingsStore>(SharedPrefsSettingsStore())
    ..registerSingleton<FrameStore>(FrameStore())
    ..registerSingleton<BackgroundAccess>(BackgroundAccess(channel))
    ..registerSingleton<TtsEngine>(ChannelTtsEngine(channel))
    ..registerSingleton<SystemFeedback>(
      ChannelSystemFeedback(channel: channel.methods, logger: logger),
    );
  getIt
    ..registerSingleton<AccessibilityAudioService>(
      AccessibilityAudioService(engine: getIt<TtsEngine>(), logger: logger),
    )
    ..registerSingleton<CameraService>(
      NativeCameraService(channel: channel, permissions: permissions),
    )
    ..registerSingleton<LocationService>(
      GeolocatorLocationService(permissions: permissions, logger: logger),
    )
    ..registerSingleton<GlassesRepository>(
      GlassesRepositoryImpl(
        channel: channel,
        parser: getIt<BlePacketParser>(),
        logger: logger,
      ),
    )
    ..registerSingleton<VisionRemoteDataSource>(
      VisionRemoteDataSourceImpl(
        client: getIt<ApiClient>(),
        // One retry for a dropped connection; slow answers are not repeated.
        retryPolicy: RetryPolicy(maxAttempts: 2),
      ),
    );
  getIt
    ..registerSingleton<VisionRepository>(
      VisionRepositoryImpl(remote: getIt<VisionRemoteDataSource>()),
    )
    ..registerSingleton<OcrRepository>(
      OcrRepositoryImpl(remote: getIt<VisionRemoteDataSource>()),
    )
    ..registerFactory(() => CaptureFrame(camera: getIt<CameraService>()))
    ..registerFactory(() => AnalyzeFrame(getIt<VisionRepository>()))
    ..registerFactory(() => ReadText(getIt<OcrRepository>()))
    ..registerFactory(() => SaveLastResponse(getIt<ResponseStorage>()))
    ..registerFactory(() => GetLastResponses(getIt<ResponseStorage>()))
    ..registerFactory(() => SpeakText(getIt<AccessibilityAudioService>()))
    ..registerFactory(() => StopSpeech(getIt<AccessibilityAudioService>()))
    ..registerFactory(
      () => RepeatLastResponse(
        storage: getIt<ResponseStorage>(),
        audio: getIt<AccessibilityAudioService>(),
      ),
    )
    ..registerFactory(
      () => ConnectGlasses(
        repository: getIt<GlassesRepository>(),
        permissions: permissions,
        settings: getIt<SettingsStore>(),
        logger: logger,
      ),
    )
    ..registerFactory(() => DisconnectGlasses(getIt<GlassesRepository>()));

  getIt
    ..registerLazySingleton(
      () => AppCubit(
        connectivity: getIt<ConnectivityService>(),
        glasses: getIt<GlassesRepository>(),
        speakText: getIt<SpeakText>(),
        logger: logger,
      ),
    )
    ..registerLazySingleton(
      () => BackendCubit(
        client: getIt<ApiClient>(),
        settings: getIt<SettingsStore>(),
        probe: BackendProbe(),
        fallbackUrl: effective.apiBaseUrl,
      ),
    )
    ..registerLazySingleton(
      () => ConnectionCubit(
        repository: getIt<GlassesRepository>(),
        connectGlasses: getIt<ConnectGlasses>(),
        disconnectGlasses: getIt<DisconnectGlasses>(),
        speakText: getIt<SpeakText>(),
        feedback: getIt<SystemFeedback>(),
        settings: getIt<SettingsStore>(),
        logger: logger,
        onConnected: getIt<BackgroundAccess>().askOnce,
      ),
    )
    ..registerLazySingleton(
      () => VisionCubit(
        captureFrame: getIt<CaptureFrame>(),
        analyzeFrame: getIt<AnalyzeFrame>(),
        saveLastResponse: getIt<SaveLastResponse>(),
        speakText: getIt<SpeakText>(),
        frames: getIt<FrameStore>(),
        location: getIt<LocationService>(),
        feedback: getIt<SystemFeedback>(),
        gate: getIt<CaptureGate>(),
        logger: logger,
      ),
    )
    ..registerLazySingleton(
      () => OcrCubit(
        captureFrame: getIt<CaptureFrame>(),
        readText: getIt<ReadText>(),
        saveLastResponse: getIt<SaveLastResponse>(),
        speakText: getIt<SpeakText>(),
        frames: getIt<FrameStore>(),
        feedback: getIt<SystemFeedback>(),
        gate: getIt<CaptureGate>(),
        logger: logger,
      ),
    )
    ..registerLazySingleton(
      () => AccessibilityCubit(
        settings: getIt<SettingsStore>(),
        audio: getIt<AccessibilityAudioService>(),
      ),
    )
    ..registerLazySingleton(
      () => GlassesApi(getIt<ApiClient>()),
    )
    ..registerLazySingleton(
      () => GlassesActionCoordinator(
        glasses: getIt<GlassesRepository>(),
        channel: getIt<GlassesChannel>(),
        api: getIt<GlassesApi>(),
        speakText: getIt<SpeakText>(),
        stopSpeech: getIt<StopSpeech>(),
        saveLastResponse: getIt<SaveLastResponse>(),
        frames: getIt<FrameStore>(),
        location: getIt<LocationService>(),
        logger: logger,
      ),
    )
    ..registerFactory(
      () => AssistantCubit(
        storage: getIt<ResponseStorage>(),
        stopSpeech: getIt<StopSpeech>(),
        repeatLast: getIt<RepeatLastResponse>(),
        ask: (prompt) => _describe(prompt: prompt),
        describe: _describe,
        readText: _readText,
      ),
    )
    ..registerFactory(
      () => GalleryCubit(
        storage: getIt<ResponseStorage>(),
        speakText: getIt<SpeakText>(),
      ),
    )
    ..registerSingleton<GoRouter>(buildRouter())
    ..registerSingleton<AppBootstrap>(AppBootstrap());
}

Future<void> _describe({String? prompt}) async {
  final vision = getIt<VisionCubit>();
  await vision.analyzeWhatIsInFront(prompt: prompt);
  if (vision.state.status == VisionStatus.error) {
    throw StateError(vision.state.errorMessage ?? 'Не удалось описать сцену.');
  }
}

Future<void> _readText() async {
  final ocr = getIt<OcrCubit>();
  await ocr.readTextInFront();
  if (ocr.state.status == OcrStatus.error) {
    throw StateError(ocr.state.errorMessage ?? 'Не удалось прочитать текст.');
  }
}

class AppBootstrap {
  Future<void> start() async {
    await Hive.initFlutter();
    await getIt<ResponseStorage>().init();
    await getIt<SettingsStore>().init();
    getIt<ApiClient>().deviceId = await getIt<SettingsStore>().deviceId();
    await getIt<AccessibilityCubit>().load();
    getIt<GlassesActionCoordinator>().start();
    unawaited(getIt<BackendCubit>().start());
    await getIt<AppCubit>().start();
  }
}

Future<void> _shutdown() async {
  if (!getIt.isRegistered<AppLogger>()) return;
  if (getIt.isRegistered<GlassesActionCoordinator>()) {
    await getIt<GlassesActionCoordinator>().dispose();
  }
  for (final close in [
    if (getIt.isRegistered<ConnectionCubit>()) getIt<ConnectionCubit>().close,
    if (getIt.isRegistered<AppCubit>()) getIt<AppCubit>().close,
    if (getIt.isRegistered<BackendCubit>()) getIt<BackendCubit>().close,
    if (getIt.isRegistered<VisionCubit>()) getIt<VisionCubit>().close,
    if (getIt.isRegistered<OcrCubit>()) getIt<OcrCubit>().close,
    if (getIt.isRegistered<AccessibilityCubit>())
      getIt<AccessibilityCubit>().close,
  ]) {
    await close();
  }
  if (getIt.isRegistered<AccessibilityAudioService>()) {
    await getIt<AccessibilityAudioService>().dispose();
  }
  final glasses = getIt.isRegistered<GlassesRepository>()
      ? getIt<GlassesRepository>()
      : null;
  if (glasses is GlassesRepositoryImpl) {
    await glasses.dispose();
  }
  await getIt.reset();
}
