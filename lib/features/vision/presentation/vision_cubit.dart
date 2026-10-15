import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seesay/core/accessibility/accessibility_audio_queue.dart';
import 'package:seesay/core/accessibility/haptic_service.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/camera/capture_gate.dart';
import 'package:seesay/core/errors/failure_mapper.dart';
import 'package:seesay/core/location/location_service.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/storage/frame_store.dart';
import 'package:seesay/core/storage/saved_response.dart';
import 'package:seesay/features/vision/domain/analyze_frame.dart';
import 'package:seesay/features/vision/domain/capture_frame.dart';
import 'package:seesay/features/vision/domain/response_use_cases.dart';

enum VisionStatus { idle, capturing, uploading, processing, success, error }

class VisionState extends Equatable {
  const VisionState({
    this.status = VisionStatus.idle,
    this.text,
    this.errorMessage,
  });

  final VisionStatus status;
  final String? text;
  final String? errorMessage;

  VisionState copyWith({
    VisionStatus? status,
    String? text,
    String? errorMessage,
    bool clearText = false,
    bool clearError = false,
  }) {
    return VisionState(
      status: status ?? this.status,
      text: clearText ? null : text ?? this.text,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, text, errorMessage];
}

class VisionCubit extends Cubit<VisionState> {
  VisionCubit({
    required this._captureFrame,
    required this._analyzeFrame,
    required this._saveLastResponse,
    required this._speakText,
    required this._frames,
    required this._location,
    required this._feedback,
    required this._gate,
    required this._logger,
  }) : super(const VisionState());

  final CaptureFrame _captureFrame;
  final AnalyzeFrame _analyzeFrame;
  final SaveLastResponse _saveLastResponse;
  final SpeakText _speakText;
  final FrameStore _frames;
  final LocationService _location;
  final SystemFeedback _feedback;
  final CaptureGate _gate;
  final AppLogger _logger;

  /// Photo → server → speech. [prompt] is the user's own question from the chat.
  Future<void> analyzeWhatIsInFront({String? prompt}) async {
    if (!_gate.tryEnter()) return;
    File? frame;
    try {
      _emit(
        state.copyWith(
          status: VisionStatus.capturing,
          clearText: true,
          clearError: true,
        ),
      );
      await _feedback.haptic(HapticKind.capture);
      await _feedback.beep(HapticKind.capture);
      _logger.info('camera capture', screen: 'home', action: 'analyze');
      frame = await _captureFrame();
      _emit(state.copyWith(status: VisionStatus.uploading));
      final point = await _location.currentPosition();
      _emit(state.copyWith(status: VisionStatus.processing));
      _logger.info('API request', screen: 'home', action: 'analyze-frame');
      final result = await _analyzeFrame(
        image: frame,
        // No words from the user: the server asks its own default question.
        prompt: prompt,
        latitude: point?.latitude,
        longitude: point?.longitude,
      );
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      await _saveLastResponse(
        SavedResponse(
          id: id,
          text: result.text,
          createdAt: DateTime.now(),
          type: ResponseType.scene,
          prompt: prompt,
          imagePath: await _frames.keep(frame, id),
        ),
      );
      _emit(state.copyWith(status: VisionStatus.success, text: result.text));
      await _feedback.haptic(HapticKind.success);
      await _feedback.beep(HapticKind.success);
      _logger.info('API success', screen: 'home', action: 'analyze-frame');
      await _speakText(result.text, kind: SpeechKind.response);
    } on Object catch (error) {
      final failure = FailureMapper.map(error);
      _emit(
        state.copyWith(
          status: VisionStatus.error,
          errorMessage: failure.message,
        ),
      );
      await _feedback.haptic(HapticKind.error);
      await _feedback.beep(HapticKind.error);
      _logger.error(
        'API error',
        screen: 'home',
        action: 'analyze',
        error: error.runtimeType,
      );
      await _speakText(
        failure.message,
        priority: SpeechPriority.high,
        interrupt: true,
      );
    } finally {
      _gate.leave();
      await _delete(frame);
    }
  }

  Future<void> _delete(File? frame) async {
    if (frame == null) return;
    if (await frame.exists()) {
      await frame.delete();
    }
  }

  void _emit(VisionState next) {
    if (!isClosed) emit(next);
  }
}
