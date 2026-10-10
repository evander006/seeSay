import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seesay/core/accessibility/accessibility_audio_queue.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/events/recorded_event.dart';
import 'package:seesay/features/assistant/domain/ai_assistant_repository.dart';
import 'package:seesay/features/events/domain/glasses_event_repository.dart';

class ChatLine extends Equatable {
  const ChatLine({
    required this.id,
    required this.fromUser,
    required this.text,
    required this.at,
    this.simulated = false,
    this.failed = false,
  });

  final String id;
  final bool fromUser;
  final String text;
  final DateTime at;
  final bool simulated;
  final bool failed;

  @override
  List<Object?> get props => [id, fromUser, text, at, simulated, failed];
}

class AssistantState extends Equatable {
  const AssistantState({
    this.messages = const [],
    this.loading = false,
    this.error,
  });

  final List<ChatLine> messages;
  final bool loading;
  final String? error;

  AssistantState copyWith({
    List<ChatLine>? messages,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [messages, loading, error];
}

class AssistantCubit extends Cubit<AssistantState> {
  AssistantCubit({
    required this._assistant,
    required this._events,
    required this._speakText,
    required this._stopSpeech,
    required this._repeatLast,
    required this._describe,
    required this._readText,
  }) : super(const AssistantState());

  final AiAssistantRepository _assistant;
  final GlassesEventRepository _events;
  final SpeakText _speakText;
  final StopSpeech _stopSpeech;
  final RepeatLastResponse _repeatLast;
  final Future<AssistantReply> Function() _describe;
  final Future<AssistantReply> Function() _readText;
  String? _lastPrompt;

  Future<void> load() async {
    final events = await _events.recent();
    final lines = events
        .where(
          (event) =>
              event.text != null &&
              (event.type == RecordedEventType.textRecognized ||
                  event.type == RecordedEventType.sceneAnalysisReady),
        )
        .map(
          (event) => ChatLine(
            id: event.eventId,
            fromUser: false,
            text: event.text!,
            at: event.timestamp,
            simulated: event.simulated,
          ),
        )
        .toList();
    if (!isClosed) emit(state.copyWith(messages: lines, clearError: true));
  }

  Future<void> send(String prompt) => _run(prompt, () => _assistant.reply(prompt));

  Future<void> describe() => _run('Опиши, что вокруг', _describe);

  Future<void> readText() => _run('Прочитай текст', _readText);

  Future<void> retry() async {
    final prompt = _lastPrompt;
    if (prompt == null) return;
    await send(prompt);
  }

  Future<void> stop() => _stopSpeech();

  Future<void> repeat() => _repeatLast();

  Future<void> _run(
    String prompt,
    Future<AssistantReply> Function() action,
  ) async {
    _lastPrompt = prompt;
    final now = DateTime.now();
    final user = ChatLine(
      id: 'user-${now.microsecondsSinceEpoch}',
      fromUser: true,
      text: prompt,
      at: now,
    );
    emit(
      state.copyWith(
        loading: true,
        clearError: true,
        messages: [...state.messages, user],
      ),
    );
    try {
      final reply = await action();
      final line = ChatLine(
        id: 'ai-${DateTime.now().microsecondsSinceEpoch}',
        fromUser: false,
        text: reply.text,
        at: DateTime.now(),
        simulated: reply.simulated,
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            loading: false,
            messages: [...state.messages, line],
          ),
        );
      }
      await _speakText(reply.text, kind: SpeechKind.response);
    } on Object catch (error) {
      final text = '$error';
      const prefix = 'Bad state: ';
      final message = text.startsWith(prefix)
          ? text.substring(prefix.length)
          : 'Не удалось получить ответ.';
      if (!isClosed) {
        emit(state.copyWith(loading: false, error: message));
      }
    }
  }
}
