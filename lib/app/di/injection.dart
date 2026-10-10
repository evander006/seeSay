import 'dart:async';
import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:seesay/app/app.dart';
import 'package:seesay/app/app_messenger.dart';
import 'package:seesay/core/accessibility/accessibility_audio_service.dart';
import 'package:seesay/core/accessibility/haptic_service.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/accessibility/tts_engine.dart';
import 'package:seesay/core/bluetooth/ble_packet_parser.dart';
import 'package:seesay/core/camera/camera_service.dart';
import 'package:seesay/core/camera/capture_gate.dart';
import 'package:seesay/core/camera/frame_compressor.dart';
import 'package:seesay/core/config/app_config.dart';
import 'package:seesay/core/location/location_service.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/network/api_client.dart';
import 'package:seesay/core/network/connectivity_service.dart';
import 'package:seesay/core/network/retry_policy.dart';
import 'package:seesay/core/permissions/permission_service.dart';
import 'package:seesay/core/platform/glasses_channel.dart';
import 'package:seesay/core/storage/response_storage.dart';
import 'package:seesay/core/storage/settings_store.dart';
import 'package:seesay/features/assistant/domain/ai_assistant_repository.dart';
import 'package:seesay/features/assistant/presentation/assistant_cubit.dart';
import 'package:seesay/features/events/data/channel_event_repository.dart';
import 'package:seesay/features/events/domain/glasses_event_repository.dart';
import 'package:seesay/features/events/presentation/events_cubit.dart';
import 'package:seesay/features/gallery/presentation/gallery_cubit.dart';
import 'package:seesay/features/glasses/data/glasses_repository_impl.dart';
import 'package:seesay/features/glasses/data/mock_glasses_repository.dart';
import 'package:seesay/features/glasses/domain/glasses_repository.dart';
import 'package:seesay/features/glasses/domain/glasses_use_cases.dart';
import 'package:seesay/features/glasses/presentation/connection_cubit.dart';
import 'package:seesay/features/glasses/presentation/glasses_action_coordinator.dart';
import 'package:seesay/features/home/presentation/app_cubit.dart';
import 'package:seesay/features/ocr/presentation/ocr_cubit.dart';
import 'package:seesay/features/settings/presentation/accessibility_cubit.dart';
import 'package:seesay/features/settings/presentation/history_cubit.dart';
import 'package:seesay/features/vision/data/mock_vision_api.dart';
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
  final loaded = config ?? await AppConfig.load();
  final android = Platform.isAndroid;
  final effective = AppConfig(
    apiBaseUrl: loaded.apiBaseUrl,
    useMockGlasses: loaded.useMockGlasses || !android,
    useMockApi: loaded.useMockApi,
    useMockCamera: loaded.useMockCamera || !android,
    useMockTts: loaded.useMockTts || !android,
  );

  getIt.registerSingleton<AppConfig>(effective);
  final logger = AppLogger();
  getIt.registerSingleton<AppLogger>(logger);
  if (!android && !loaded.useMockGlasses) {
    logger.info('app started', action: 'mock-glasses-desktop');
  }

  getIt.registerSingleton<BlePacketParser>(BlePacketParser());
  getIt.registerSingleton<RetryPolicy>(RetryPolicy());
  getIt.registerSingleton<CaptureGate>(CaptureGate());
  getIt.registerSingleton<GlassesChannel>(GlassesChannel());
  getIt.registerSingleton<PermissionService>(PermissionService(logger: logger));
  getIt.registerSingleton<ConnectivityService>(DeviceConnectivityService());
  getIt.registerSingleton<ApiClient>(
    ApiClient(baseUrl: effective.apiBaseUrl, logger: logger),
  );
  getIt.registerSingleton<FrameCompressor>(FrameCompressor());
  getIt.registerSingleton<ResponseStorage>(HiveResponseStorage());
  getIt.registerSingleton<SettingsStore>(SharedPrefsSettingsStore());

  final channel = getIt<GlassesChannel>();
  getIt.registerSingleton<TtsEngine>(
    effective.useMockTts ? MockTtsEngine() : ChannelTtsEngine(channel),
  );
  getIt.registerSingleton<SystemFeedback>(
    android
        ? ChannelSystemFeedback(channel: channel.methods, logger: logger)
        : FallbackSystemFeedback(),
  );
  getIt.registerSingleton<AccessibilityAudioService>(
    AccessibilityAudioService(engine: getIt<TtsEngine>(), logger: logger),
  );

  getIt.registerSingleton<CameraService>(
    effective.useMockCamera
        ? MockCameraService()
        : PhoneCameraService(permissions: getIt<PermissionService>()),
  );
  getIt.registerSingleton<LocationService>(
    android
        ? GeolocatorLocationService(
            permissions: getIt<PermissionService>(),
            logger: logger,
          )
        : NullLocationService(),
  );
  getIt.registerSingleton<GlassesRepository>(
    effective.useMockGlasses
        ? MockGlassesRepository(parser: getIt<BlePacketParser>())
        : GlassesRepositoryImpl(
            channel: channel,
            parser: getIt<BlePacketParser>(),
            logger: logger,
          ),
  );
  getIt.registerSingleton<VisionRemoteDataSource>(
    effective.useMockApi
        ? MockVisionRemoteDataSource()
        : VisionRemoteDataSourceImpl(
            client: getIt<ApiClient>(),
            retryPolicy: getIt<RetryPolicy>(),
          ),
  );
  getIt.registerSingleton<VisionRepository>(
    VisionRepositoryImpl(
      remote: getIt<VisionRemoteDataSource>(),
      connectivity: getIt<ConnectivityService>(),
    ),
  );
  getIt.registerSingleton<OcrRepository>(
    OcrRepositoryImpl(
      remote: getIt<VisionRemoteDataSource>(),
      connectivity: getIt<ConnectivityService>(),
    ),
  );

  getIt.registerFactory(
    () => CaptureFrame(
      camera: getIt<CameraService>(),
      compressor: getIt<FrameCompressor>(),
    ),
  );
  getIt.registerFactory(() => AnalyzeFrame(getIt<VisionRepository>()));
  getIt.registerFactory(() => ReadText(getIt<OcrRepository>()));
  getIt.registerFactory(() => SaveLastResponse(getIt<ResponseStorage>()));
  getIt.registerFactory(() => GetLastResponses(getIt<ResponseStorage>()));
  getIt.registerFactory(() => SpeakText(getIt<AccessibilityAudioService>()));
  getIt.registerFactory(() => StopSpeech(getIt<AccessibilityAudioService>()));
  getIt.registerFactory(
    () => RepeatLastResponse(
      storage: getIt<ResponseStorage>(),
      audio: getIt<AccessibilityAudioService>(),
    ),
  );
  getIt.registerFactory(
    () => ConnectGlasses(
      repository: getIt<GlassesRepository>(),
      permissions: getIt<PermissionService>(),
      settings: getIt<SettingsStore>(),
      config: getIt<AppConfig>(),
      logger: logger,
    ),
  );
  getIt.registerFactory(() => DisconnectGlasses(getIt<GlassesRepository>()));

  getIt.registerLazySingleton(
    () => AppCubit(
      config: effective,
      connectivity: getIt<ConnectivityService>(),
      glasses: getIt<GlassesRepository>(),
      speakText: getIt<SpeakText>(),
      logger: logger,
    ),
  );
  getIt.registerLazySingleton(
    () => ConnectionCubit(
      repository: getIt<GlassesRepository>(),
      connectGlasses: getIt<ConnectGlasses>(),
      disconnectGlasses: getIt<DisconnectGlasses>(),
      speakText: getIt<SpeakText>(),
      feedback: getIt<SystemFeedback>(),
      settings: getIt<SettingsStore>(),
      logger: logger,
    ),
  );
  getIt.registerLazySingleton(
    () => VisionCubit(
      captureFrame: getIt<CaptureFrame>(),
      analyzeFrame: getIt<AnalyzeFrame>(),
      saveLastResponse: getIt<SaveLastResponse>(),
      speakText: getIt<SpeakText>(),
      connectivity: getIt<ConnectivityService>(),
      location: getIt<LocationService>(),
      feedback: getIt<SystemFeedback>(),
      gate: getIt<CaptureGate>(),
      logger: logger,
    ),
  );
  getIt.registerLazySingleton(
    () => OcrCubit(
      captureFrame: getIt<CaptureFrame>(),
      readText: getIt<ReadText>(),
      saveLastResponse: getIt<SaveLastResponse>(),
      speakText: getIt<SpeakText>(),
      connectivity: getIt<ConnectivityService>(),
      feedback: getIt<SystemFeedback>(),
      gate: getIt<CaptureGate>(),
      logger: logger,
    ),
  );
  getIt.registerLazySingleton(
    () => AccessibilityCubit(
      settings: getIt<SettingsStore>(),
      audio: getIt<AccessibilityAudioService>(),
    ),
  );
  getIt.registerFactory(
    () => HistoryCubit(
      getLastResponses: getIt<GetLastResponses>(),
      speakText: getIt<SpeakText>(),
    ),
  );
  getIt.registerLazySingleton(
    () => GlassesActionCoordinator(
      glasses: getIt<GlassesRepository>(),
      vision: getIt<VisionCubit>(),
      ocr: getIt<OcrCubit>(),
      repeatLastResponse: getIt<RepeatLastResponse>(),
      logger: logger,
    ),
  );
  getIt.registerSingleton<GlassesEventRepository>(
    android
        ? ChannelGlassesEventRepository(channel)
        : MemoryGlassesEventRepository(),
  );
  getIt.registerLazySingleton(
    () => EventsCubit(
      repository: getIt<GlassesEventRepository>(),
      speakText: getIt<SpeakText>(),
      prepareMonitoring: android
          ? () async {
              final permissions = getIt<PermissionService>();
              final notifications = await permissions.ensureNotifications();
              if (!notifications) return false;
              if (getIt<GlassesEventRepository>().mockMode) return true;
              return permissions.ensureGlassesLink();
            }
          : null,
      onFailure: showAppMessage,
    ),
  );
  getIt.registerFactory(
    () => AssistantCubit(
      assistant: const MockAiAssistantRepository(),
      events: getIt<GlassesEventRepository>(),
      speakText: getIt<SpeakText>(),
      stopSpeech: StopSpeech(getIt<AccessibilityAudioService>()),
      repeatLast: getIt<RepeatLastResponse>(),
      describe: () async {
        final vision = getIt<VisionCubit>();
        await vision.analyzeWhatIsInFront();
        final state = vision.state;
        if (state.status == VisionStatus.error) {
          throw StateError(state.errorMessage ?? 'Не удалось описать сцену.');
        }
        return AssistantReply(
          text: state.text ?? '',
          simulated: getIt<AppConfig>().useMockApi,
        );
      },
      readText: () async {
        final ocr = getIt<OcrCubit>();
        await ocr.readTextInFront();
        final state = ocr.state;
        if (state.status == OcrStatus.error) {
          throw StateError(state.errorMessage ?? 'Не удалось прочитать текст.');
        }
        return AssistantReply(
          text: state.text ?? '',
          simulated: getIt<AppConfig>().useMockApi,
        );
      },
    ),
  );
  getIt.registerFactory(
    () => GalleryCubit(
      storage: getIt<ResponseStorage>(),
      speakText: getIt<SpeakText>(),
    ),
  );
  getIt.registerSingleton<GoRouter>(buildRouter());
  getIt.registerSingleton<AppBootstrap>(AppBootstrap());
}

class AppBootstrap {
  Future<void> start() async {
    await Hive.initFlutter();
    await getIt<ResponseStorage>().init();
    await getIt<SettingsStore>().init();
    await getIt<AccessibilityCubit>().load();
    getIt<GlassesActionCoordinator>().start();
    await getIt<AppCubit>().start();
    await getIt<EventsCubit>().refresh();
  }
}

Future<void> _shutdown() async {
  if (!getIt.isRegistered<AppLogger>()) return;
  if (getIt.isRegistered<GlassesActionCoordinator>()) {
    await getIt<GlassesActionCoordinator>().dispose();
  }
  if (getIt.isRegistered<ConnectionCubit>()) {
    await getIt<ConnectionCubit>().close();
  }
  if (getIt.isRegistered<AppCubit>()) await getIt<AppCubit>().close();
  if (getIt.isRegistered<VisionCubit>()) await getIt<VisionCubit>().close();
  if (getIt.isRegistered<OcrCubit>()) await getIt<OcrCubit>().close();
  if (getIt.isRegistered<EventsCubit>()) {
    await getIt<EventsCubit>().close();
  }
  if (getIt.isRegistered<GlassesEventRepository>()) {
    final events = getIt<GlassesEventRepository>();
    if (events is ChannelGlassesEventRepository) await events.dispose();
  }
  if (getIt.isRegistered<AccessibilityCubit>()) {
    await getIt<AccessibilityCubit>().close();
  }
  if (getIt.isRegistered<AccessibilityAudioService>()) {
    await getIt<AccessibilityAudioService>().dispose();
  }
  if (getIt.isRegistered<CameraService>()) {
    await getIt<CameraService>().dispose();
  }
  final glasses = getIt.isRegistered<GlassesRepository>()
      ? getIt<GlassesRepository>()
      : null;
  if (glasses is GlassesRepositoryImpl) {
    await glasses.dispose();
  }
  await getIt.reset();
}
