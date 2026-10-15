import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/core/errors/app_exception.dart';
import 'package:seesay/features/vision/data/dto/vision_dto.dart';
import 'package:seesay/features/vision/data/response_mapper.dart';

void main() {
  test('maps a successful scene response', () {
    final result = ResponseMapper.toAnalyzeResult(
      const AnalyzeFrameResponse(
        status: 'success',
        textResponse: 'Перед вами вход в аптеку.',
        executionTimeMs: 1100,
      ),
    );
    expect(result.text, 'Перед вами вход в аптеку.');
    expect(result.executionTimeMs, 1100);
  });

  test('maps recognized text', () {
    final result = ResponseMapper.toOcrResult(
      const ReadTextResponse(status: 'success', rawText: 'Аптека Вита.'),
    );
    expect(result.text, 'Аптека Вита.');
  });

  test('rejects an empty analysis payload', () {
    expect(
      () => ResponseMapper.toAnalyzeResult(
        const AnalyzeFrameResponse(status: 'error', textResponse: ''),
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('reads the server JSON with a fractional execution time', () {
    // smart-glasses backend answers like this: execution_time_ms is a float.
    final dto = AnalyzeFrameResponse.fromJson({
      'status': 'success',
      'text_response': 'Перед вами стол.',
      'execution_time_ms': 780.5,
      'spatial_cues': <Object>[],
      'mode': 'general',
    });
    expect(dto.executionTimeMs, 781);
    expect(ResponseMapper.toAnalyzeResult(dto).text, 'Перед вами стол.');
  });

  test('speaks the server error phrase instead of a generic one', () {
    expect(
      () => ResponseMapper.toAnalyzeResult(
        const AnalyzeFrameResponse(
          status: 'error',
          textResponse: 'Время ожидания зрительной модели истекло.',
        ),
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Время ожидания зрительной модели истекло.',
        ),
      ),
    );
  });
}
