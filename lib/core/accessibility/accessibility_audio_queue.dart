enum SpeechPriority { low, normal, high, critical }

enum SpeechKind { status, response, hint, system }

class SpeechRequest {
  const SpeechRequest({
    required this.text,
    required this.priority,
    required this.interrupt,
  });

  final String text;
  final SpeechPriority priority;
  final bool interrupt;
}

class AccessibilityAudioQueue {
  AccessibilityAudioQueue({required this._speak, required this._stop});

  final Future<void> Function(String text) _speak;
  final Future<void> Function() _stop;

  final List<SpeechRequest> _pending = [];
  var _draining = false;
  var generation = 0;

  bool interrupts(SpeechRequest request) {
    return request.interrupt ||
        request.priority == SpeechPriority.high ||
        request.priority == SpeechPriority.critical;
  }

  Future<void> enqueue(SpeechRequest request) async {
    if (interrupts(request)) {
      _pending.clear();
      generation += 1;
      await _stop();
    }
    _pending.add(request);
    if (!_draining) {
      await _drain();
    }
  }

  Future<void> clear() async {
    _pending.clear();
    generation += 1;
    await _stop();
  }

  Future<void> _drain() async {
    _draining = true;
    try {
      while (_pending.isNotEmpty) {
        final seenGeneration = generation;
        final request = _pending.removeAt(0);
        await _speak(request.text);
        if (seenGeneration != generation) {
          continue;
        }
      }
    } finally {
      _draining = false;
    }
  }
}
