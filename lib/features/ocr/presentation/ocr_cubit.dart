import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seesay/core/accessibility/accessibility_audio_queue.dart';
import 'package:seesay/core/accessibility/haptic_service.dart';
import 'package:seesay/core/accessibility/speech_messages.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/camera/capture_gate.dart';
import 'package:seesay/core/errors/app_exception.dart';
import 'package:seesay/core/errors/failure_mapper.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/network/connectivity_service.dart';
import 'package:seesay/core/storage/saved_response.dart';
import 'package:seesay/features/vision/domain/analyze_frame.dart';
import 'package:seesay/features/vision/domain/capture_frame.dart';
import 'package:seesay/features/vision/domain/response_use_cases.dart';

enum OcrStatus { idle, capturing, uploading, processing, success, error }

class OcrState extends Equatable {
  const OcrState({this.status = OcrStatus.idle, this.text, this.errorMessage});

  final OcrStatus status;
  final String? text;
  final String? errorMessage;

  OcrState copyWith({
    OcrStatus? status,
    String? text,
    String? errorMessage,
    bool clearText = false,
    bool clearError = false,
  }) {
    return OcrState(
      status: status ?? this.status,
      text: clearText ? null : text ?? this.text,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, text, errorMessage];
}

class OcrCubit extends Cubit<OcrState> {
  OcrCubit({
    required this._captureFrame,
    required this._readText,
    required this._saveLastResponse,
    required this._speakText,
    required this._connectivity,
    required this._feedback,
    required this._gate,
    required this._logger,
  }) : super(const OcrState());

  final CaptureFrame _captureFrame;
  final ReadText _readText;
  final SaveLastResponse _saveLastResponse;
  final SpeakText _speakText;
  final ConnectivityService _connectivity;
  final SystemFeedback _feedback;
  final CaptureGate _gate;
  final AppLogger _logger;

  Future<void> readTextInFront() async {
    if (!_gate.tryEnter()) return;
    File? frame;
    try {
      _emit(
        state.copyWith(
          status: OcrStatus.capturing,
          clearText: true,
          clearError: true,
        ),
      );
      await _feedback.haptic(HapticKind.capture);
      _logger.info('camera capture', screen: 'home', action: 'ocr');
      frame = await _captureFrame();
      if (!await _connectivity.isOnline) {
        throw NetworkException(SpeechMessages.networkUnavailable);
      }
      _emit(state.copyWith(status: OcrStatus.uploading));
      _emit(state.copyWith(status: OcrStatus.processing));
      _logger.info('API request', screen: 'home', action: 'read-text');
      final result = await _readText(image: frame);
      await _saveLastResponse(
        SavedResponse(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          text: result.text,
          createdAt: DateTime.now(),
          type: ResponseType.ocr,
        ),
      );
      _emit(state.copyWith(status: OcrStatus.success, text: result.text));
      await _feedback.haptic(HapticKind.success);
      _logger.info('API success', screen: 'home', action: 'read-text');
      await _speakText(result.text, kind: SpeechKind.response);
    } on Object catch (error) {
      final failure = FailureMapper.map(error);
      _emit(
        state.copyWith(status: OcrStatus.error, errorMessage: failure.message),
      );
      await _feedback.haptic(HapticKind.error);
      _logger.error(
        'API error',
        screen: 'home',
        action: 'ocr',
        error: error.runtimeType,
      );
      await _speakText(
        failure.message,
        priority: SpeechPriority.high,
        interrupt: true,
      );
    } finally {
      _gate.leave();
      if (frame != null && await frame.exists()) {
        await frame.delete();
      }
    }
  }

  void _emit(OcrState next) {
    if (!isClosed) emit(next);
  }
}
