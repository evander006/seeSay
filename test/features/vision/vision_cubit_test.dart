import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/core/accessibility/accessibility_audio_service.dart';
import 'package:seesay/core/accessibility/speech_messages.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/accessibility/tts_engine.dart';
import 'package:seesay/core/camera/camera_service.dart';
import 'package:seesay/core/camera/capture_gate.dart';
import 'package:seesay/core/camera/frame_compressor.dart';
import 'package:seesay/core/config/demo_content.dart';
import 'package:seesay/core/location/location_service.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/storage/response_storage.dart';
import 'package:seesay/features/vision/data/mock_vision_api.dart';
import 'package:seesay/features/vision/data/vision_repository_impl.dart';
import 'package:seesay/features/vision/domain/analyze_frame.dart';
import 'package:seesay/features/vision/domain/capture_frame.dart';
import 'package:seesay/features/vision/domain/response_use_cases.dart';
import 'package:seesay/features/vision/presentation/vision_cubit.dart';
import 'package:seesay/features/ocr/presentation/ocr_cubit.dart';

import '../../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTtsEngine engine;
  late MemoryResponseStorage storage;
  late FakeConnectivity connectivity;

  setUp(() {
    engine = MockTtsEngine();
    storage = MemoryResponseStorage();
    connectivity = FakeConnectivity(online: true);
  });

  AccessibilityAudioService audio() {
    return AccessibilityAudioService(engine: engine, logger: AppLogger());
  }

  CaptureFrame capture() {
    return CaptureFrame(
      camera: MockCameraService(),
      compressor: FrameCompressor(directory: storageDir),
    );
  }

  test('vision analyze speaks the backend response and stores it', () async {
    final remote = MockVisionRemoteDataSource(delay: Duration.zero);
    final cubit = VisionCubit(
      captureFrame: capture(),
      analyzeFrame: AnalyzeFrame(
        VisionRepositoryImpl(remote: remote, connectivity: connectivity),
      ),
      saveLastResponse: SaveLastResponse(storage),
      speakText: SpeakText(audio()),
      connectivity: connectivity,
      location: NullLocationService(),
      feedback: QuietFeedback(),
      gate: CaptureGate(),
      logger: AppLogger(),
    );

    await cubit.analyzeWhatIsInFront();

    expect(cubit.state.status, VisionStatus.success);
    expect(cubit.state.text, DemoContent.sceneResponse);
    expect((await storage.getAll()).single.text, DemoContent.sceneResponse);
    expect(engine.spoken, contains(DemoContent.sceneResponse));
    expect(engine.spoken, isNot(contains(SpeechMessages.capturing)));
    expect(engine.spoken, isNot(contains(SpeechMessages.analysisStarted)));
    await cubit.close();
  });

  test('vision analyze stays offline without calling storage', () async {
    connectivity.online = false;
    final cubit = VisionCubit(
      captureFrame: capture(),
      analyzeFrame: AnalyzeFrame(
        VisionRepositoryImpl(
          remote: MockVisionRemoteDataSource(delay: Duration.zero),
          connectivity: connectivity,
        ),
      ),
      saveLastResponse: SaveLastResponse(storage),
      speakText: SpeakText(audio()),
      connectivity: connectivity,
      location: NullLocationService(),
      feedback: QuietFeedback(),
      gate: CaptureGate(),
      logger: AppLogger(),
    );

    await cubit.analyzeWhatIsInFront();

    expect(cubit.state.status, VisionStatus.error);
    expect(cubit.state.errorMessage, SpeechMessages.networkUnavailable);
    expect(await storage.getAll(), isEmpty);
    expect(engine.spoken, contains(SpeechMessages.networkUnavailable));
    await cubit.close();
  });

  test('ocr reads text and stores the response', () async {
    final cubit = OcrCubit(
      captureFrame: capture(),
      readText: ReadText(
        OcrRepositoryImpl(
          remote: MockVisionRemoteDataSource(delay: Duration.zero),
          connectivity: connectivity,
        ),
      ),
      saveLastResponse: SaveLastResponse(storage),
      speakText: SpeakText(audio()),
      connectivity: connectivity,
      feedback: QuietFeedback(),
      gate: CaptureGate(),
      logger: AppLogger(),
    );

    await cubit.readTextInFront();

    expect(cubit.state.status, OcrStatus.success);
    expect(cubit.state.text, DemoContent.ocrResponse);
    expect(engine.spoken, contains(DemoContent.ocrResponse));
    expect(engine.spoken, isNot(contains(SpeechMessages.textRecognized)));
    await cubit.close();
  });
}
