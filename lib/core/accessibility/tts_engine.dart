abstract class TtsEngine {
  Future<void> speak(
    String text, {
    required double rate,
    required String language,
  });

  Future<void> stop();

  Future<void> setSpeechRate(double rate);

  Future<void> setLanguage(String language);

  Future<void> dispose();
}

class MockTtsEngine implements TtsEngine {
  final List<String> spoken = [];
  var stopCount = 0;
  double rate = 1;
  String language = 'ru-RU';
  var disposed = false;

  @override
  Future<void> speak(
    String text, {
    required double rate,
    required String language,
  }) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    this.rate = rate;
  }

  @override
  Future<void> setLanguage(String language) async {
    this.language = language;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
