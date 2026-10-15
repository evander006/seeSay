import 'dart:io';

import 'package:seesay/features/vision/data/dto/vision_dto.dart';
import 'package:seesay/features/vision/data/vision_remote_data_source.dart';

const fakeSceneResponse =
    'Перед вами вход в аптеку. Дверь справа. Перед дверью две ступени.';
const fakeOcrResponse = 'Аптека Вита. Режим работы с 8:00 до 21:00.';

class MockVisionRemoteDataSource implements VisionRemoteDataSource {
  MockVisionRemoteDataSource({this.delay = const Duration(milliseconds: 250)});

  final Duration delay;

  @override
  Future<AnalyzeFrameResponse> analyzeFrame({
    required File image,
    String? prompt,
    double? latitude,
    double? longitude,
  }) async {
    await Future<void>.delayed(delay);
    return const AnalyzeFrameResponse(
      status: 'success',
      textResponse: fakeSceneResponse,
      executionTimeMs: 1100,
    );
  }

  @override
  Future<ReadTextResponse> readText({required File image}) async {
    await Future<void>.delayed(delay);
    return const ReadTextResponse(
      status: 'success',
      rawText: fakeOcrResponse,
    );
  }
}
