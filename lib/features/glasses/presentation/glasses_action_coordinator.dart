import 'dart:async';
import 'dart:io';

import 'package:seesay/core/accessibility/accessibility_audio_queue.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/errors/failure_mapper.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/platform/glasses_channel.dart';
import 'package:seesay/core/storage/frame_store.dart';
import 'package:seesay/core/storage/saved_response.dart';
import 'package:seesay/features/glasses/data/glasses_api.dart';
import 'package:seesay/features/glasses/domain/glasses_repository.dart';
import 'package:seesay/features/vision/domain/response_use_cases.dart';

/// What the glasses buttons do (all over BLE, the phone can stay in a pocket):
///
/// * black ×1 + a spoken question → assistant with memory. The voice goes to the server; if the
///   question is about what the user sees, the photo the glasses take right after the question
///   is sent too (action `need_image`).
/// * black ×2 → the competitors pitch at full volume, at once (the glasses report a double press
///   as one event, 120A 02; the photo they take with it is ignored).
/// * red ×3 within 10 s → the same pitch, as a backup (the glasses take one photo at a time,
///   so the presses arrive ~3 s apart; one or two presses do nothing here).
/// * temple tap (play/pause) → stop speaking.
class GlassesActionCoordinator {
  GlassesActionCoordinator({
    required this._glasses,
    required this._channel,
    required this._api,
    required this._speakText,
    required this._stopSpeech,
    required this._saveLastResponse,
    required this._frames,
    required this._logger,
  });

  final GlassesRepository _glasses;
  final GlassesChannel _channel;
  final GlassesApi _api;
  final SpeakText _speakText;
  final StopSpeech _stopSpeech;
  final SaveLastResponse _saveLastResponse;
  final FrameStore _frames;
  final AppLogger _logger;

  static const _pitchPresses = 3;
  // The glasses take one photo at a time (~3 s each), so 3 quick presses arrive over ~6 s.
  static const _pitchWindow = Duration(seconds: 10);
  static const _photoWait = Duration(seconds: 4);

  StreamSubscription<GlassesEvent>? _subscription;
  final List<DateTime> _redPresses = [];
  DateTime? _pitchStartedAt;
  bool _pitchPlaying = false;

  /// Photo the glasses take right after a question; completed by the next `voice` photo.
  Completer<File?>? _voicePhoto;

  /// Increases with every new request: an old answer must not be spoken over a newer one.
  int _generation = 0;

  void start() {
    _subscription ??= _glasses.events.listen((event) {
      unawaited(_onEvent(event));
    });
  }

  Future<void> _onEvent(GlassesEvent event) async {
    try {
      switch (event) {
        case GlassesButtonPressed(button: 'red'):
          _onRed();
        case GlassesButtonPressed(button: 'black', kind: 'double'):
          _log('black button double');
          unawaited(playPitch(reason: 'black ×2'));
        case GlassesButtonPressed(button: 'black', :final kind):
          _log('black button $kind');
          if (!_pitchPlaying) await _stopSpeech();
        case VoiceStateChanged(:final state, :final reason):
          _log('voice $state${reason == null ? '' : ' ($reason)'}');
        case VoiceCaptured():
          await _onVoice(event);
        case GlassesPhotoReceived():
          await _onPhoto(event);
        case MediaButtonReceived(action: MediaButtonAction.playPause):
          _log('temple tap: stop');
          await stopAll();
        default:
          break;
      }
    } on Object catch (error) {
      _logger.error('glasses flow failed', screen: 'glasses', error: error);
    }
  }

  // ---- black ×1: voice question

  Future<void> _onVoice(VoiceCaptured voice) async {
    final generation = ++_generation;
    _voicePhoto = Completer<File?>();
    final watch = Stopwatch()..start();
    _log(
      'voice captured: ${voice.packets} packets, ${voice.durationMs} ms, '
      'end: ${voice.reason}',
    );
    final GlassesReply reply;
    try {
      reply = await _api.voice(File(voice.path));
    } on Object catch (error) {
      await _fail('voice upload', error, generation);
      return;
    }
    _log(
      'voice reply in ${watch.elapsedMilliseconds} ms (server ${reply.serverMs}): '
      '${reply.action} «${reply.transcript}» → «${reply.text}»',
    );
    if (generation != _generation) return;
    switch (reply.action) {
      case 'pitch':
        await playPitch(reason: 'voice «${reply.transcript}»');
      case 'need_image':
        await _answerWithVoicePhoto(reply.transcript, generation, watch);
      default:
        await _say(reply.text, generation);
        if (reply.action == 'speak') {
          await _remember(reply.transcript, reply.text, null);
        }
    }
  }

  Future<void> _answerWithVoicePhoto(
    String question,
    int generation,
    Stopwatch watch,
  ) async {
    var photo = await _voicePhoto?.future.timeout(
      _photoWait,
      onTimeout: () => null,
    );
    if (photo == null && generation == _generation) {
      _log('no photo after the question, asking again');
      _voicePhoto = Completer<File?>();
      await _channel.requestGlassesPhoto(reason: 'voice');
      photo = await _voicePhoto?.future.timeout(_photoWait, onTimeout: () => null);
    }
    if (generation != _generation) return;
    if (photo == null) {
      await _say('Не получилось сделать снимок. Попробуйте ещё раз.', generation);
      return;
    }
    _log('photo for the question after ${watch.elapsedMilliseconds} ms');
    await _frame(photo, question, generation);
  }

  // ---- photos (black ×2, after a question, or from the app)

  Future<void> _onPhoto(GlassesPhotoReceived event) async {
    final file = File(event.path);
    _log('photo ${event.reason} after ${event.waitedMs} ms');
    if (event.reason == 'voice') {
      final waiting = _voicePhoto;
      if (waiting != null && !waiting.isCompleted) waiting.complete(file);
      return;
    }
    // Black ×2 starts the pitch; the photo the glasses take with it is not needed.
    if (event.reason == 'recognition') return;
    await _frame(file, null, ++_generation);
  }

  Future<void> _frame(File photo, String? question, int generation) async {
    final watch = Stopwatch()..start();
    final GlassesReply reply;
    try {
      reply = await _api.frame(photo, prompt: question);
    } on Object catch (error) {
      await _fail('frame upload', error, generation);
      return;
    }
    _log(
      'frame reply in ${watch.elapsedMilliseconds} ms (server ${reply.serverMs}): '
      '«${reply.text}»',
    );
    if (generation != _generation) return;
    await _say(reply.text, generation);
    await _remember(
      question == null || question.isEmpty ? 'Что передо мной?' : question,
      reply.text,
      photo,
    );
  }

  /// «Снимок с очков» on the settings screen: same as black ×2.
  Future<bool> requestFrame() => _channel.requestGlassesPhoto(reason: 'request');

  // ---- red ×3: pitch

  void _onRed() {
    final now = DateTime.now();
    _redPresses
      ..add(now)
      ..removeWhere((t) => now.difference(t) > _pitchWindow);
    _log('red button (${_redPresses.length} in ${_pitchWindow.inSeconds} s)');
    if (_redPresses.length >= _pitchPresses) {
      _redPresses.clear();
      unawaited(playPitch(reason: 'red ×3'));
    }
  }

  Future<void> playPitch({String reason = 'app'}) async {
    final started = _pitchStartedAt;
    final now = DateTime.now();
    if (_pitchPlaying ||
        (started != null && now.difference(started) < const Duration(seconds: 5))) {
      _log('pitch already playing ($reason)');
      return;
    }
    _generation++;
    _pitchStartedAt = now;
    _pitchPlaying = true;
    _log('pitch start ($reason)');
    try {
      await _stopSpeech();
      final ok = await _channel.playPitch();
      _log('pitch ${ok ? 'done' : 'failed'}');
    } finally {
      _pitchPlaying = false;
    }
  }

  Future<void> stopAll() async {
    _generation++;
    if (_pitchPlaying) await _channel.stopPitch();
    await _stopSpeech();
  }

  /// Sends the diagnostic log to the server; returns its name there.
  Future<String> uploadLog() async {
    final path = await _channel.exportLog();
    if (path == null) throw StateError('Журнал не найден.');
    final saved = await _api.uploadLog(File(path));
    _log('log uploaded as $saved');
    return saved;
  }

  // ---- helpers

  Future<void> _say(String text, int generation) async {
    if (text.isEmpty || generation != _generation) return;
    await _speakText(
      text,
      kind: SpeechKind.response,
      priority: SpeechPriority.high,
      interrupt: true,
    );
  }

  Future<void> _fail(String what, Object error, int generation) async {
    final failure = FailureMapper.map(error);
    _logger.error('$what failed', screen: 'glasses', error: error);
    await _say(failure.message, generation);
  }

  Future<void> _remember(String question, String answer, File? photo) async {
    if (answer.isEmpty) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _saveLastResponse(
      SavedResponse(
        id: id,
        text: answer,
        createdAt: DateTime.now(),
        type: ResponseType.scene,
        prompt: question.isEmpty ? null : question,
        imagePath: photo == null ? null : await _frames.keep(photo, id),
      ),
    );
  }

  void _log(String message) => _logger.info(message, screen: 'glasses');

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
