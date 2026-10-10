import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seesay/core/accessibility/accessibility_audio_queue.dart';
import 'package:seesay/core/accessibility/haptic_service.dart';
import 'package:seesay/core/accessibility/speech_messages.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/errors/failure_mapper.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/platform/glasses_channel.dart';
import 'package:seesay/core/storage/settings_store.dart';
import 'package:seesay/features/glasses/domain/glasses_repository.dart';
import 'package:seesay/features/glasses/domain/glasses_use_cases.dart';

class ConnectionViewState extends Equatable {
  const ConnectionViewState({
    this.status = ConnectionStatus.disconnected,
    this.message,
    this.deviceAddress,
    this.battery,
  });

  final ConnectionStatus status;
  final String? message;
  final String? deviceAddress;
  final int? battery;

  ConnectionViewState copyWith({
    ConnectionStatus? status,
    String? message,
    String? deviceAddress,
    int? battery,
    bool clearMessage = false,
  }) {
    return ConnectionViewState(
      status: status ?? this.status,
      message: clearMessage ? null : message ?? this.message,
      deviceAddress: deviceAddress ?? this.deviceAddress,
      battery: battery ?? this.battery,
    );
  }

  @override
  List<Object?> get props => [status, message, deviceAddress, battery];
}

class ConnectionCubit extends Cubit<ConnectionViewState> {
  ConnectionCubit({
    required this._repository,
    required this._connectGlasses,
    required this._disconnectGlasses,
    required this._speakText,
    required this._feedback,
    required this._settings,
    required this._logger,
  }) : super(const ConnectionViewState()) {
    _subscription = _repository.events.listen((event) {
      unawaited(_onEvent(event));
    });
  }

  final GlassesRepository _repository;
  final ConnectGlasses _connectGlasses;
  final DisconnectGlasses _disconnectGlasses;
  final SpeakText _speakText;
  final SystemFeedback _feedback;
  final SettingsStore _settings;
  final AppLogger _logger;
  late final StreamSubscription<GlassesEvent> _subscription;

  Future<void> connect() async {
    if (state.status == ConnectionStatus.connecting) return;
    _emit(
      state.copyWith(status: ConnectionStatus.connecting, clearMessage: true),
    );
    try {
      await _connectGlasses();
    } on Object catch (error) {
      final failure = FailureMapper.map(error);
      _emit(
        state.copyWith(
          status: ConnectionStatus.error,
          message: failure.message,
        ),
      );
      await _feedback.haptic(HapticKind.error);
      await _feedback.beep(HapticKind.error);
      await _speakText(
        failure.message,
        priority: SpeechPriority.high,
        interrupt: true,
      );
      _logger.error(
        'BLE disconnected',
        action: 'connect',
        error: error.runtimeType,
      );
    }
  }

  Future<void> disconnect() async {
    try {
      await _disconnectGlasses();
    } on Object catch (error) {
      final failure = FailureMapper.map(error);
      _emit(
        state.copyWith(
          status: ConnectionStatus.error,
          message: failure.message,
        ),
      );
      await _speakText(
        failure.message,
        priority: SpeechPriority.high,
        interrupt: true,
      );
    }
  }

  Future<void> simulatePhotoTrigger() => _repository.simulatePhotoTrigger();

  Future<void> _onEvent(GlassesEvent event) async {
    if (event is ConnectionChanged) {
      final snapshot = event.snapshot;
      _emit(
        ConnectionViewState(
          status: snapshot.status,
          message: snapshot.message,
          deviceAddress: snapshot.deviceAddress ?? state.deviceAddress,
          battery: snapshot.battery ?? state.battery,
        ),
      );
      await _settings.setLastConnectionState(snapshot.status.name);
      if (snapshot.deviceAddress != null) {
        await _settings.setLastDeviceAddress(snapshot.deviceAddress);
      }
      if (snapshot.status == ConnectionStatus.connected) {
        await _feedback.haptic(HapticKind.connection);
        await _feedback.beep(HapticKind.connection);
      } else if (snapshot.status == ConnectionStatus.error) {
        await _feedback.haptic(HapticKind.error);
        await _speakText(
          snapshot.message ?? SpeechMessages.glassesLinkFailed,
          priority: SpeechPriority.high,
          interrupt: true,
        );
      }
    } else if (event is BatteryChanged) {
      _emit(state.copyWith(battery: event.level));
    }
  }

  void _emit(ConnectionViewState next) {
    if (!isClosed) emit(next);
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
