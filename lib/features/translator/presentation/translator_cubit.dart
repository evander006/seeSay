import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/features/translator/data/translator_api.dart';
import 'package:seesay/features/translator/data/translator_channel.dart';

/// Languages offered for the partner; `auto` takes the language the partner last spoke.
const translatorLanguages = <String, String>{
  'auto': 'Авто',
  'en': 'English',
  'zh': '中文',
  'de': 'Deutsch',
  'fr': 'Français',
  'es': 'Español',
  'it': 'Italiano',
  'tr': 'Türkçe',
  'ar': 'العربية',
  'ja': '日本語',
  'ko': '한국어',
  'hi': 'हिन्दी',
};

String languageName(String code) => translatorLanguages[code] ?? code.toUpperCase();

class TranslatorLine extends Equatable {
  const TranslatorLine({
    required this.id,
    this.fromUser = false,
    this.original = '',
    this.translation = '',
    this.lang = '',
    this.pending = true,
    this.failed = false,
  });

  final int id;
  final bool fromUser;
  final String original;
  final String translation;
  final String lang;
  final bool pending;
  final bool failed;

  @override
  List<Object?> get props => [id, fromUser, original, translation, lang, pending, failed];
}

class TranslatorState extends Equatable {
  const TranslatorState({
    this.active = false,
    this.busy = false,
    this.speaking = false,
    this.level = 0,
    this.partner = 'auto',
    this.detected,
    this.lines = const [],
    this.message,
  });

  final bool active;
  final bool busy;

  /// Someone is talking right now (a phrase is being recorded).
  final bool speaking;

  /// Mic loudness 0..1 for the meter.
  final double level;
  final String partner;
  final String? detected;
  final List<TranslatorLine> lines;
  final String? message;

  /// Language the user's phrases are translated into.
  String get partnerLanguage => partner == 'auto' ? (detected ?? 'en') : partner;

  TranslatorState copyWith({
    bool? active,
    bool? busy,
    bool? speaking,
    double? level,
    String? partner,
    String? detected,
    List<TranslatorLine>? lines,
    String? message,
    bool clearMessage = false,
  }) {
    return TranslatorState(
      active: active ?? this.active,
      busy: busy ?? this.busy,
      speaking: speaking ?? this.speaking,
      level: level ?? this.level,
      partner: partner ?? this.partner,
      detected: detected ?? this.detected,
      lines: lines ?? this.lines,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [active, busy, speaking, level, partner, detected, lines, message];
}

/// Interpreter mode: the phone mic hears the conversation phrase by phrase. The partner's phrases
/// are spoken into the glasses in Russian; the user's Russian is played on the phone speaker in the
/// partner's language. Phrases are translated in parallel but always voiced in order.
class TranslatorCubit extends Cubit<TranslatorState> {
  TranslatorCubit({required this._channel, required this._api, required this._logger})
    : super(const TranslatorState());

  final TranslatorChannel _channel;
  final TranslatorApi _api;
  final AppLogger _logger;
  StreamSubscription<Map<String, dynamic>>? _events;
  Future<void> _voiced = Future.value();
  var _nextId = 0;

  /// What was said into the glasses lately: if the phone mic hears it back, it is not a new phrase.
  final _recentGlasses = <(DateTime, Set<String>)>[];

  Future<void> toggle() => state.active ? stop() : start();

  Future<void> start() async {
    if (state.active || state.busy) return;
    _emit(state.copyWith(busy: true, clearMessage: true));
    try {
      if (!await Permission.microphone.request().isGranted) {
        throw StateError('Разрешите SeeSay доступ к микрофону.');
      }
      _events ??= _channel.events().listen(_onEvent, onError: (_) {});
      await _channel.start();
      _emit(state.copyWith(active: true, busy: false));
      _log('translator on');
      unawaited(_api.warm());
      unawaited(_channel.speakToGlasses('Переводчик включён.'));
    } on Object catch (error) {
      final text = error is StateError ? error.message : 'Не удалось включить переводчик.';
      _emit(state.copyWith(busy: false, message: text));
    }
  }

  Future<void> stop() async {
    if (!state.active) return;
    await _channel.stop();
    _emit(state.copyWith(active: false, speaking: false, level: 0));
    _log('translator off');
    unawaited(_channel.speakToGlasses('Переводчик выключен.'));
  }

  void setPartner(String code) => _emit(state.copyWith(partner: code));

  void clear() => _emit(state.copyWith(lines: const []));

  void _onEvent(Map<String, dynamic> event) {
    switch (event['event']) {
      case 'level':
        final rms = (event['rms'] as num?)?.toDouble() ?? 0;
        _emit(state.copyWith(level: (rms / 4000).clamp(0, 1), speaking: event['speaking'] == true));
      case 'phrase':
        final path = event['path'] as String?;
        if (path != null) _onPhrase(File(path), (event['ms'] as num?)?.toInt() ?? 0);
      case 'error':
        _emit(state.copyWith(message: event['text'] as String?));
    }
  }

  void _onPhrase(File wav, int ms) {
    final id = _nextId++;
    _emit(state.copyWith(speaking: false, lines: [...state.lines, TranslatorLine(id: id)]));
    final watch = Stopwatch()..start();
    final translated = _api.phrase(wav, partner: state.partnerLanguage);
    // Each phrase is translated at once, but voiced only after the previous one.
    _voiced = _voiced.then((_) async {
      TranslatedPhrase? phrase;
      try {
        phrase = await translated;
      } on Object catch (error) {
        _logger.error('translate failed', screen: 'translator', error: error);
        _update(id, (line) => TranslatorLine(id: id, pending: false, failed: true));
        return;
      }
      _log('phrase $ms ms → ${phrase?.lang}→${phrase?.to} in ${watch.elapsedMilliseconds} ms');
      if (phrase == null || phrase.translation.isEmpty || _isEcho(phrase)) {
        _remove(id);
        return;
      }
      if (!phrase.fromUser && state.partner == 'auto' && phrase.lang.length == 2) {
        _emit(state.copyWith(detected: phrase.lang));
      }
      final done = phrase;
      _update(
        id,
        (line) => TranslatorLine(
          id: id,
          fromUser: done.fromUser,
          original: done.text,
          translation: done.translation,
          lang: done.lang,
          pending: false,
        ),
      );
      if (!state.active) return;
      if (done.fromUser) {
        final audio = done.audio;
        if (audio != null) {
          final file = File('${wav.parent.path}/speaker_$id.mp3');
          await file.writeAsBytes(audio);
          await _channel.playOnSpeaker(file.path);
        }
      } else {
        _recentGlasses.add((DateTime.now(), _words(done.translation)));
        await _channel.speakToGlasses(done.translation);
      }
    });
  }

  /// The phone mic may catch the glasses' own Russian speech: such a «phrase» is dropped.
  bool _isEcho(TranslatedPhrase phrase) {
    if (!phrase.fromUser) return false;
    final now = DateTime.now();
    _recentGlasses.removeWhere((e) => now.difference(e.$1) > const Duration(seconds: 25));
    final words = _words(phrase.text);
    if (words.isEmpty) return false;
    for (final (_, said) in _recentGlasses) {
      final common = words.intersection(said).length;
      if (common / words.length >= 0.6) {
        _log('echo of the glasses dropped: «${phrase.text}»');
        return true;
      }
    }
    return false;
  }

  Set<String> _words(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((w) => w.length > 2)
      .toSet();

  void _update(int id, TranslatorLine Function(TranslatorLine) change) {
    _emit(state.copyWith(lines: [for (final l in state.lines) l.id == id ? change(l) : l]));
  }

  void _remove(int id) {
    _emit(state.copyWith(lines: state.lines.where((l) => l.id != id).toList()));
  }

  void _emit(TranslatorState next) {
    if (!isClosed) emit(next);
  }

  void _log(String message) => _logger.info(message, screen: 'translator');

  @override
  Future<void> close() async {
    await _events?.cancel();
    if (state.active) await _channel.stop();
    return super.close();
  }
}
