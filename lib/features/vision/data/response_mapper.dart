import 'package:seesay/core/accessibility/speech_messages.dart';
import 'package:seesay/core/errors/app_exception.dart';
import 'package:seesay/features/vision/data/dto/vision_dto.dart';
import 'package:seesay/features/vision/domain/vision_result.dart';

abstract final class ResponseMapper {
  static AnalyzeResult toAnalyzeResult(AnalyzeFrameResponse dto) {
    if (dto.status != 'success' || dto.textResponse.trim().isEmpty) {
      // On errors the server sends a phrase meant to be spoken; prefer it to a generic one.
      final spoken = dto.textResponse.trim();
      throw ApiException(spoken.isEmpty ? SpeechMessages.apiUnavailable : spoken);
    }
    return AnalyzeResult(
      text: dto.textResponse.trim(),
      executionTimeMs: dto.executionTimeMs,
    );
  }

  static OcrResult toOcrResult(ReadTextResponse dto) {
    if (dto.status != 'success' || dto.rawText.trim().isEmpty) {
      final spoken = dto.rawText.trim();
      throw ApiException(
        dto.status != 'success' && spoken.isNotEmpty
            ? spoken
            : 'Текст на изображении не найден.',
      );
    }
    return OcrResult(text: dto.rawText.trim());
  }
}
