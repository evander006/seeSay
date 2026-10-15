class AnalyzeFrameResponse {
  const AnalyzeFrameResponse({
    required this.status,
    required this.textResponse,
    this.executionTimeMs,
  });

  final String status;
  final String textResponse;
  final int? executionTimeMs;

  factory AnalyzeFrameResponse.fromJson(Map<String, dynamic> json) {
    return AnalyzeFrameResponse(
      status: json['status'] as String? ?? '',
      textResponse: json['text_response'] as String? ?? '',
      // The server may send 780.5 as well as 780.
      executionTimeMs: (json['execution_time_ms'] as num?)?.round(),
    );
  }
}

class ReadTextResponse {
  const ReadTextResponse({required this.status, required this.rawText});

  final String status;
  final String rawText;

  factory ReadTextResponse.fromJson(Map<String, dynamic> json) {
    return ReadTextResponse(
      status: json['status'] as String? ?? '',
      rawText: json['raw_text'] as String? ?? '',
    );
  }
}
