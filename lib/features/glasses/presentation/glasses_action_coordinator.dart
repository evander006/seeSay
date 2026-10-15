import 'dart:async';
import 'dart:io';

import 'package:seesay/core/accessibility/accessibility_audio_queue.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/errors/failure_mapper.dart';
import 'package:seesay/core/location/location_service.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/platform/glasses_channel.dart';
import 'package:seesay/core/storage/frame_store.dart';
import 'package:seesay/core/storage/saved_response.dart';
import 'package:seesay/features/glasses/data/glasses_api.dart';
import 'package:seesay/features/glasses/domain/glasses_repository.dart';
import 'package:seesay/features/vision/domain/response_use_cases.dart';

/// What the glasses buttons do (all over BLE, the phone can stay in a pocket):
///
/// * black ×1 + a spoken question → assistant with memory. The answer is streamed and spoken
///   sentence by sentence; if the question is about what the user sees (`need_image`, known from
///   the first lines of the answer) the glasses take a photo then — never during speech.
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
    required this._location,
    required this._logger,
  });

  final GlassesRepository _glasses;
  final GlassesChannel _channel;
  final GlassesApi _api;
  final SpeakText _speakText;
  final StopSpeech _stopSpeech;
  final SaveLastResponse _saveLastResponse;
  final FrameStore _frames;
  final LocationService _location;
  final AppLogger _logger;

  /// GPS is looked up while the user speaks, so it is ready when the question ends.
  Future<GeoPoint?>? _position;
  GeoPoint? _lastPoint;

  /// Black ×2: completed when the glasses' photo (and its shutter sound) is done.
  Completer<void>? _recognitionShot;

  static const _pitchPresses = 3;
  // The glasses take one photo at a time (~3 s each), so 3 quick presses arrive over ~6 s.
  static const _pitchWindow = Duration(seconds: 10);
  static const _photoWait = Duration(seconds: 4);

  StreamSubscription<GlassesEvent>? _subscription;
  final List<DateTime> _redPresses = [];
  DateTime? _pitchStartedAt;
  bool _pitchPlaying = false;

  /// Photo asked for a visual question; completed by the next `voice` photo.
  Completer<File?>? _voicePhoto;

  /// Increases with every new request: an old answer must not be spoken over a newer one.
  int _generation = 0;

  void start() {
    _subscription ??= _glasses.events.listen((event) {
      unawaited(_onEvent(event));
    });
    // A first GPS fix in advance, so even the first «где я» does not wait for it.
    _refreshPosition();
  }

  Future<void> _onEvent(GlassesEvent event) async {
    try {
      switch (event) {
        case GlassesButtonPressed(button: 'red'):
          _onRed();
        case GlassesButtonPressed(button: 'black', kind: 'double'):
          _log('black button double');
          unawaited(_pitchAfterShutter());
        case GlassesButtonPressed(button: 'black', :final kind):
          _log('black button $kind');
          if (!_pitchPlaying) await _stopSpeech();
        case VoiceStateChanged(:final state, :final reason):
          _log('voice $state${reason == null ? '' : ' ($reason)'}');
          if (state == 'listening') _refreshPosition();
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

  // ---- GPS: looked up while the user speaks, never waited for after the question

  void _refreshPosition() {
    _position = _location.currentPosition().then((point) {
      if (point != null) _lastPoint = point;
      return point;
    });
  }

  Future<GeoPoint?> _quickPosition() async {
    final pending = _position;
    if (pending == null) return _lastPoint;
    return pending.timeout(
      const Duration(milliseconds: 300),
      onTimeout: () => _lastPoint,
    );
  }

  // ---- black ×1: voice question, the answer streamed sentence by sentence

  Future<void> _onVoice(VoiceCaptured voice) async {
    final generation = ++_generation;
    final watch = Stopwatch()..start();
    _log(
      'voice captured: ${voice.packets} packets, ${voice.durationMs} ms, '
      'end: ${voice.reason}',
    );
    final point = await _quickPosition();
    var action = 'speak';
    var transcript = '';
    double? destinationLat;
    double? destinationLon;
    Future<File?>? photo;
    final spoken = <String>[];
    try {
      final stream = _api.voiceStream(
        File(voice.path),
        latitude: point?.latitude,
        longitude: point?.longitude,
      );
      await for (final piece in stream) {
        if (generation != _generation) return;
        switch (piece.type) {
          case 'meta':
            action = piece.action ?? 'speak';
            transcript = piece.transcript ?? '';
            destinationLat = piece.destinationLat;
            destinationLon = piece.destinationLon;
            _log('voice meta in ${watch.elapsedMilliseconds} ms: $action «$transcript»');
            // The question is about what the user sees: the photo is asked for right now, while
            // nothing is being said, so the shutter sound never cuts into an answer.
            if (action == 'need_image') photo = _takePhoto();
            if (action == 'pitch') unawaited(playPitch(reason: 'voice «$transcript»'));
          case 'text':
            final text = piece.text ?? '';
            if (spoken.isEmpty) _log('first words in ${watch.elapsedMilliseconds} ms');
            await _speakChunk(text, first: spoken.isEmpty, generation: generation);
            spoken.add(text);
          case 'done':
            _log('voice done in ${watch.elapsedMilliseconds} ms, server ${piece.serverMs} ms ${piece.timings}');
        }
      }
    } on Object catch (error) {
      if (spoken.isEmpty) {
        await _fail('voice stream', error, generation);
      } else {
        _logger.error('voice stream broke', screen: 'glasses', error: error);
      }
      return;
    }
    if (generation != _generation) return;
    final answer = spoken.join(' ');
    switch (action) {
      case 'need_image':
        await _answerWithPhoto(photo, transcript, generation, watch);
      case 'navigate':
        final lat = destinationLat;
        final lon = destinationLon;
        if (lat != null && lon != null) {
          final opened = await _channel.openRoute(
            lat: lat,
            lon: lon,
            fromLat: point?.latitude,
            fromLon: point?.longitude,
          );
          _log('route in Yandex Maps: ${opened ? 'opened' : 'not opened'}');
        }
        await _remember(transcript, answer, null);
      case 'speak':
        await _remember(transcript, answer, null);
    }
  }

  /// Asks the glasses for a photo (~2 s over BLE) and waits for it; one retry.
  Future<File?> _takePhoto() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final waiting = _voicePhoto = Completer<File?>();
      final asked = await _channel.requestGlassesPhoto(reason: 'voice');
      if (!asked) return null;
      final photo = await waiting.future.timeout(_photoWait, onTimeout: () => null);
      if (photo != null) return photo;
      _log('no photo from the glasses, asking again');
    }
    return null;
  }

  Future<void> _answerWithPhoto(
    Future<File?>? pending,
    String question,
    int generation,
    Stopwatch watch,
  ) async {
    final photo = await (pending ?? _takePhoto());
    if (generation != _generation) return;
    if (photo == null) {
      await _say('Не получилось сделать снимок. Попробуйте ещё раз.', generation);
      return;
    }
    _log('photo for the question after ${watch.elapsedMilliseconds} ms');
    await _frame(photo, question, generation);
  }

  // ---- photos (after a visual question, black ×2, or from the app)

  Future<void> _onPhoto(GlassesPhotoReceived event) async {
    final file = File(event.path);
    _log('photo ${event.reason} after ${event.waitedMs} ms');
    if (event.reason == 'voice') {
      final waiting = _voicePhoto;
      if (waiting != null && !waiting.isCompleted) waiting.complete(file);
      return;
    }
    if (event.reason == 'recognition') {
      // Black ×2: the photo means the glasses' shutter sound is over, the pitch may start.
      final shot = _recognitionShot;
      if (shot != null && !shot.isCompleted) shot.complete();
      return;
    }
    await _frame(file, null, ++_generation);
  }

  Future<void> _frame(File photo, String? question, int generation) async {
    final watch = Stopwatch()..start();
    final spoken = <String>[];
    try {
      await for (final piece in _api.frameStream(photo, prompt: question)) {
        if (generation != _generation) return;
        if (piece.type == 'text') {
          final text = piece.text ?? '';
          if (spoken.isEmpty) _log('frame first words in ${watch.elapsedMilliseconds} ms');
          await _speakChunk(text, first: spoken.isEmpty, generation: generation);
          spoken.add(text);
        } else if (piece.type == 'done') {
          _log('frame done in ${watch.elapsedMilliseconds} ms, server ${piece.serverMs} ms ${piece.timings}');
        }
      }
    } on Object catch (error) {
      if (spoken.isEmpty) await _fail('frame stream', error, generation);
      return;
    }
    if (generation != _generation) return;
    await _remember(
      question == null || question.isEmpty ? 'Что передо мной?' : question,
      spoken.join(' '),
      photo,
    );
  }

  /// One sentence of a streamed answer straight into the Android speech queue: the first one
  /// replaces whatever is being said, the next ones follow without a pause.
  Future<void> _speakChunk(
    String text, {
    required bool first,
    required int generation,
  }) async {
    if (text.isEmpty || generation != _generation) return;
    await _channel.speakChunk(text, flush: first);
  }

  /// Black ×2: the glasses take a photo with a shutter sound; the pitch starts once it is over.
  Future<void> _pitchAfterShutter() async {
    final shot = _recognitionShot = Completer<void>();
    await shot.future.timeout(const Duration(milliseconds: 1600), onTimeout: () {});
    await playPitch(reason: 'black ×2');
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
