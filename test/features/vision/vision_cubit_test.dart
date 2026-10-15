import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/core/accessibility/accessibility_audio_service.dart';
import 'package:seesay/core/accessibility/speech_messages.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/camera/capture_gate.dart';
import 'package:seesay/core/storage/frame_store.dart';
import 'package:seesay/core/location/location_service.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/storage/response_storage.dart';
import 'package:seesay/features/vision/data/vision_repository_impl.dart';
import 'package:seesay/features/vision/domain/analyze_frame.dart';
import 'package:seesay/features/vision/domain/capture_frame.dart';
import 'package:seesay/features/vision/domain/response_use_cases.dart';
import 'package:seesay/features/vision/presentation/vision_cubit.dart';
import 'package:seesay/features/ocr/presentation/ocr_cubit.dart';

import '../../support/fake_vision_api.dart';
import '../../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTtsEngine engine;
  late MemoryResponseStorage storage;

  setUp(() {
    engine = MockTtsEngine();
    storage = MemoryResponseStorage();
  });

  AccessibilityAudioService audio() {
    return AccessibilityAudioService(engine: engine, logger: AppLogger());
  }

  CaptureFrame capture() {
    return CaptureFrame(camera: MockCameraService());
  }

  test('vision analyze speaks the backend response and stores it', () async {
    final remote = MockVisionRemoteDataSource(delay: Duration.zero);
    final cubit = VisionCubit(
      captureFrame: capture(),
      analyzeFrame: AnalyzeFrame(
        VisionRepositoryImpl(remote: remote),
      ),
      saveLastResponse: SaveLastResponse(storage),
      speakText: SpeakText(audio()),
      frames: FrameStore(directory: storageDir),
      location: NullLocationService(),
      feedback: QuietFeedback(),
      gate: CaptureGate(),
      logger: AppLogger(),
    );

    await cubit.analyzeWhatIsInFront();

    expect(cubit.state.status, VisionStatus.success);
    expect(cubit.state.text, fakeSceneResponse);
    expect((await storage.getAll()).single.text, fakeSceneResponse);
    expect(engine.spoken, contains(fakeSceneResponse));
    expect(engine.spoken, isNot(contains(SpeechMessages.capturing)));
    expect(engine.spoken, isNot(contains(SpeechMessages.analysisStarted)));
    await cubit.close();
  });

  test('camera failure is spoken and nothing is stored', () async {
    final cubit = VisionCubit(
      captureFrame: CaptureFrame(camera: MockCameraService(fail: true)),
      analyzeFrame: AnalyzeFrame(
        VisionRepositoryImpl(
          remote: MockVisionRemoteDataSource(delay: Duration.zero),
        ),
      ),
      saveLastResponse: SaveLastResponse(storage),
      speakText: SpeakText(audio()),
      frames: FrameStore(directory: storageDir),
      location: NullLocationService(),
      feedback: QuietFeedback(),
      gate: CaptureGate(),
      logger: AppLogger(),
    );

    await cubit.analyzeWhatIsInFront();

    expect(cubit.state.status, VisionStatus.error);
    expect(cubit.state.errorMessage, SpeechMessages.unexpectedError);
    expect(await storage.getAll(), isEmpty);
    expect(engine.spoken, contains(SpeechMessages.unexpectedError));
    await cubit.close();
  });

  test('chat question is sent as the prompt and the frame is kept', () async {
    final cubit = VisionCubit(
      captureFrame: capture(),
      analyzeFrame: AnalyzeFrame(
        VisionRepositoryImpl(
          remote: MockVisionRemoteDataSource(delay: Duration.zero),
        ),
      ),
      saveLastResponse: SaveLastResponse(storage),
      speakText: SpeakText(audio()),
      frames: FrameStore(directory: storageDir),
      location: NullLocationService(),
      feedback: QuietFeedback(),
      gate: CaptureGate(),
      logger: AppLogger(),
    );

    await cubit.analyzeWhatIsInFront(prompt: 'Что на табличке?');

    final saved = (await storage.getAll()).single;
    expect(saved.prompt, 'Что на табличке?');
    expect(saved.imagePath, isNotNull);
    await cubit.close();
  });

  test('ocr reads text and stores the response', () async {
    final cubit = OcrCubit(
      captureFrame: capture(),
      readText: ReadText(
        OcrRepositoryImpl(remote: MockVisionRemoteDataSource(delay: Duration.zero)),
      ),
      saveLastResponse: SaveLastResponse(storage),
      speakText: SpeakText(audio()),
      frames: FrameStore(directory: storageDir),
      feedback: QuietFeedback(),
      gate: CaptureGate(),
      logger: AppLogger(),
    );

    await cubit.readTextInFront();

    expect(cubit.state.status, OcrStatus.success);
    expect(cubit.state.text, fakeOcrResponse);
    expect(engine.spoken, contains(fakeOcrResponse));
    expect(engine.spoken, isNot(contains(SpeechMessages.textRecognized)));
    await cubit.close();
  });
}
