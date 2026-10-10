class AnalyzeResult {
  const AnalyzeResult({required this.text, this.executionTimeMs});

  final String text;
  final int? executionTimeMs;
}

class OcrResult {
  const OcrResult({required this.text});

  final String text;
}
