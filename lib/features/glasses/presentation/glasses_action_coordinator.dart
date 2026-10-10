import 'dart:async';

import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/bluetooth/ble_packet.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/platform/glasses_channel.dart';
import 'package:seesay/features/glasses/domain/glasses_repository.dart';
import 'package:seesay/features/ocr/presentation/ocr_cubit.dart';
import 'package:seesay/features/vision/presentation/vision_cubit.dart';

class GlassesActionCoordinator {
  GlassesActionCoordinator({
    required this._glasses,
    required this._vision,
    required this._ocr,
    required this._repeatLastResponse,
    required this._logger,
  });

  final GlassesRepository _glasses;
  final VisionCubit _vision;
  final OcrCubit _ocr;
  final RepeatLastResponse _repeatLastResponse;
  final AppLogger _logger;

  StreamSubscription<GlassesEvent>? _subscription;
  DateTime? _lastPhoto;

  void start() {
    _subscription ??= _glasses.events.listen((event) {
      unawaited(_onEvent(event));
    });
  }

  Future<void> _onEvent(GlassesEvent event) async {
    if (event is BlePacketReceived) {
      switch (event.packet.type) {
        case BleEventType.photoTrigger:
          _logger.info('photo trigger', screen: 'glasses', action: 'ble');
          await _photo();
        case BleEventType.doubleTap:
          await _repeatLastResponse();
        case BleEventType.captureStarted:
        case BleEventType.videoInitialization:
        case BleEventType.recording:
        case BleEventType.idle:
        case BleEventType.unknown:
          _logger.info(
            'photo trigger',
            screen: 'glasses',
            action: event.packet.type.name,
          );
      }
    } else if (event is MediaButtonReceived) {
      _logger.info(
        'photo trigger',
        screen: 'glasses',
        action: event.action.name,
      );
      if (event.action == MediaButtonAction.playPause) {
        await _photo();
      }
    }
  }

  Future<void> _photo() async {
    final now = DateTime.now();
    if (_lastPhoto != null &&
        now.difference(_lastPhoto!) < const Duration(milliseconds: 800)) {
      return;
    }
    _lastPhoto = now;
    if (_ocr.state.status == OcrStatus.capturing) return;
    await _vision.analyzeWhatIsInFront();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
