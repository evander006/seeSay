import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seesay/core/accessibility/accessibility_audio_queue.dart';
import 'package:seesay/core/accessibility/speech_messages.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/network/connectivity_service.dart';
import 'package:seesay/features/glasses/domain/glasses_repository.dart';

class AppState extends Equatable {
  const AppState({
    this.ready = false,
    this.online = true,
    this.bluetoothReady = true,
  });

  final bool ready;
  final bool online;
  final bool bluetoothReady;

  AppState copyWith({bool? ready, bool? online, bool? bluetoothReady}) {
    return AppState(
      ready: ready ?? this.ready,
      online: online ?? this.online,
      bluetoothReady: bluetoothReady ?? this.bluetoothReady,
    );
  }

  @override
  List<Object?> get props => [ready, online, bluetoothReady];
}

class AppCubit extends Cubit<AppState> {
  AppCubit({
    required this._connectivity,
    required this._glasses,
    required this._speakText,
    required this._logger,
  }) : super(const AppState());

  final ConnectivityService _connectivity;
  final GlassesRepository _glasses;
  final SpeakText _speakText;
  final AppLogger _logger;
  StreamSubscription<bool>? _subscription;
  var _sawOffline = false;

  Future<void> start() async {
    final online = await _connectivity.isOnline;
    final bluetooth = await _glasses.isAdapterEnabled();
    if (!isClosed) {
      emit(
        state.copyWith(ready: true, online: online, bluetoothReady: bluetooth),
      );
    }
    _logger.info('app started', screen: 'boot', action: 'start');
    if (!online) {
      _sawOffline = true;
      await _speakText(
        SpeechMessages.networkUnavailable,
        priority: SpeechPriority.high,
        interrupt: true,
      );
    }
    if (!bluetooth) {
      await _speakText(
        SpeechMessages.bluetoothUnavailable,
        priority: SpeechPriority.high,
        interrupt: true,
      );
    }
    _subscription = _connectivity.onStatusChanged.listen((isOnline) {
      unawaited(_onNetwork(isOnline));
    });
  }

  Future<void> _onNetwork(bool online) async {
    if (isClosed || online == state.online) return;
    emit(state.copyWith(online: online));
    if (!online) {
      _sawOffline = true;
      await _speakText(
        SpeechMessages.networkUnavailable,
        priority: SpeechPriority.high,
        interrupt: true,
      );
      return;
    }
    if (_sawOffline) {
      await _speakText(
        SpeechMessages.networkRestored,
        priority: SpeechPriority.low,
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
