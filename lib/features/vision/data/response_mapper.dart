import 'package:seesay/core/accessibility/speech_messages.dart';
import 'package:seesay/core/errors/app_exception.dart';
import 'package:seesay/features/vision/data/dto/vision_dto.dart';
import 'package:seesay/features/vision/domain/vision_result.dart';

abstract final class ResponseMapper {
  static AnalyzeResult toAnalyzeResult(AnalyzeFrameResponse dto) {
    if (dto.status != 'success' || dto.textResponse.trim().isEmpty) {
      throw ApiException(SpeechMessages.apiUnavailable);
    }
    return AnalyzeResult(
      text: dto.textResponse.trim(),
      executionTimeMs: dto.executionTimeMs,
    );
  }

  static OcrResult toOcrResult(ReadTextResponse dto) {
    if (dto.status != 'success' || dto.rawText.trim().isEmpty) {
      throw ApiException('Текст на изображении не найден.');
    }
    return OcrResult(text: dto.rawText.trim());
  }
}
