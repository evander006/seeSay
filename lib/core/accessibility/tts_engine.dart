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
