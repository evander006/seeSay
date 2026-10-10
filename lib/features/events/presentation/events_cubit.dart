import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seesay/core/accessibility/accessibility_audio_queue.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/errors/app_exception.dart';
import 'package:seesay/core/errors/failure_mapper.dart';
import 'package:seesay/core/events/recorded_event.dart';
import 'package:seesay/features/events/domain/glasses_event_repository.dart';

class EventsState extends Equatable {
  const EventsState({
    this.monitoring = false,
    this.mockMode = true,
    this.events = const [],
    this.error,
  });

  final bool monitoring;
  final bool mockMode;
  final List<RecordedEvent> events;
  final String? error;

  EventsState copyWith({
    bool? monitoring,
    bool? mockMode,
    List<RecordedEvent>? events,
    String? error,
    bool clearError = false,
  }) {
    return EventsState(
      monitoring: monitoring ?? this.monitoring,
      mockMode: mockMode ?? this.mockMode,
      events: events ?? this.events,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [monitoring, mockMode, events, error];
}

class EventsCubit extends Cubit<EventsState> {
  EventsCubit({
    required this._repository,
    required this._speakText,
    this._prepareMonitoring,
    this._onFailure,
  }) : super(
        EventsState(
          monitoring: _repository.monitoring,
          mockMode: _repository.mockMode,
        ),
      ) {
    _subscription = _repository.live.listen(_accept);
  }

  final GlassesEventRepository _repository;
  final SpeakText _speakText;
  final Future<bool> Function()? _prepareMonitoring;
  final void Function(String message)? _onFailure;
  late final StreamSubscription<RecordedEvent> _subscription;
  final _seen = <String>{};

  Future<void> refresh() async {
    final events = await _repository.recent();
    final pending = await _repository.pending();
    if (!isClosed) {
      emit(
        state.copyWith(
          monitoring: _repository.monitoring,
          mockMode: _repository.mockMode,
          events: events,
          clearError: true,
        ),
      );
    }
    for (final event in pending) {
      await _accept(event);
    }
  }

  Future<void> setMonitoring(bool enabled) async {
    try {
      if (enabled && _prepareMonitoring != null) {
        final allowed = await _prepareMonitoring();
        if (!allowed) {
          _report(
            _repository.mockMode
                ? 'Нет разрешения на уведомления. Мониторинг не запущен.'
                : 'Нужны разрешения Bluetooth и уведомлений. Мониторинг не запущен.',
          );
          return;
        }
      }
      if (enabled) {
        await _repository.startMonitoring();
      } else {
        await _repository.stopMonitoring();
      }
      await refresh();
    } on Object catch (error) {
      _report(_readable(error));
    }
  }

  Future<void> setMockMode(bool enabled) async {
    try {
      await _repository.setMockMode(enabled);
      await refresh();
    } on Object catch (error) {
      _report(_readable(error));
    }
  }

  Future<void> trigger(RecordedEventType type) async {
    try {
      final event = await _repository.trigger(type);
      if (event == null) {
        _report(
          _repository.monitoring
              ? 'Демонстрационный режим выключен.'
              : 'Сначала включите фоновый мониторинг.',
        );
        return;
      }
      await refresh();
    } on Object catch (error) {
      _report(_readable(error));
    }
  }

  void _report(String message) {
    if (!isClosed) emit(state.copyWith(error: message));
    _onFailure?.call(message);
  }

  String _readable(Object error) {
    if (error is AppException) return FailureMapper.map(error).message;
    final text = '$error';
    const prefix = 'Bad state: ';
    if (text.startsWith(prefix)) return text.substring(prefix.length);
    return 'Действие не выполнено.';
  }

  Future<void> _accept(RecordedEvent event) async {
    if (!_seen.add(event.eventId)) return;
    final events = await _repository.recent();
    if (!isClosed) emit(state.copyWith(events: events, clearError: true));
    await _speak(event);
    await _repository.acknowledge(event.eventId);
  }

  Future<void> _speak(RecordedEvent event) async {
    final phrase = switch (event.type) {
      RecordedEventType.textRecognized when event.text != null =>
        'На табличке написано: ${event.text}',
      RecordedEventType.sceneAnalysisReady when event.text != null =>
        event.text,
      RecordedEventType.glassesConnected => 'Очки подключены.',
      RecordedEventType.deviceError => event.error,
      _ => null,
    };
    if (phrase == null || phrase.isEmpty) return;
    await _speakText(
      phrase,
      priority: SpeechPriority.high,
      interrupt: true,
      kind: SpeechKind.response,
    );
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
