import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/storage/response_storage.dart';
import 'package:seesay/core/storage/saved_response.dart';

class ChatLine extends Equatable {
  const ChatLine({
    required this.id,
    required this.fromUser,
    required this.text,
    required this.at,
    this.imagePath,
  });

  final String id;
  final bool fromUser;
  final String text;
  final DateTime at;

  /// Frame the answer was made from, shown as a small preview.
  final String? imagePath;

  @override
  List<Object?> get props => [id, fromUser, text, at, imagePath];
}

class AssistantState extends Equatable {
  const AssistantState({
    this.messages = const [],
    this.pending,
    this.error,
  });

  final List<ChatLine> messages;

  /// The question being answered right now.
  final String? pending;
  final String? error;

  bool get loading => pending != null;

  @override
  List<Object?> get props => [messages, pending, error];
}

/// Chat over the saved answers. Every request goes through the camera and the server; the
/// vision cubits save and speak the answer, and the chat redraws from storage.
class AssistantCubit extends Cubit<AssistantState> {
  AssistantCubit({
    required this._storage,
    required this._stopSpeech,
    required this._repeatLast,
    required this._ask,
    required this._describe,
    required this._readText,
  }) : super(const AssistantState()) {
    _subscription = _storage.changes.listen((_) => unawaited(load()));
  }

  final ResponseStorage _storage;
  final StopSpeech _stopSpeech;
  final RepeatLastResponse _repeatLast;
  final Future<void> Function(String prompt) _ask;
  final Future<void> Function() _describe;
  final Future<void> Function() _readText;
  late final StreamSubscription<void> _subscription;
  String? _lastPrompt;

  static const describePrompt = 'Что вокруг?';
  static const readPrompt = 'Прочитай текст';

  Future<void> load() async {
    final saved = await _storage.getAll();
    final lines = <ChatLine>[];
    for (final item in saved.reversed) {
      lines
        ..add(
          ChatLine(
            id: 'q-${item.id}',
            fromUser: true,
            text: item.prompt ??
                (item.type == ResponseType.ocr ? readPrompt : describePrompt),
            at: item.createdAt,
          ),
        )
        ..add(
          ChatLine(
            id: 'a-${item.id}',
            fromUser: false,
            text: item.text,
            at: item.createdAt,
            imagePath: item.imagePath,
          ),
        );
    }
    if (!isClosed) {
      emit(AssistantState(messages: lines, pending: state.pending, error: state.error));
    }
  }

  Future<void> send(String prompt) => _run(prompt, () => _ask(prompt));

  Future<void> describe() => _run(describePrompt, _describe);

  Future<void> readText() => _run(readPrompt, _readText);

  Future<void> retry() async {
    final prompt = _lastPrompt;
    if (prompt == null) return;
    if (prompt == describePrompt) return describe();
    if (prompt == readPrompt) return readText();
    await send(prompt);
  }

  Future<void> stop() => _stopSpeech();

  Future<void> repeat() => _repeatLast();

  Future<void> _run(String prompt, Future<void> Function() action) async {
    if (state.loading) return;
    _lastPrompt = prompt;
    emit(AssistantState(messages: state.messages, pending: prompt));
    try {
      await action();
      if (!isClosed) emit(AssistantState(messages: state.messages));
    } on Object catch (error) {
      final text = '$error';
      const prefix = 'Bad state: ';
      final message = text.startsWith(prefix)
          ? text.substring(prefix.length)
          : 'Не удалось получить ответ.';
      if (!isClosed) {
        emit(AssistantState(messages: state.messages, error: message));
      }
    }
    await load();
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
