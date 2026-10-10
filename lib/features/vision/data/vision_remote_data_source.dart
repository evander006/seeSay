import 'dart:io';

import 'package:seesay/features/vision/data/dto/vision_dto.dart';

abstract interface class VisionRemoteDataSource {
  Future<AnalyzeFrameResponse> analyzeFrame({
    required File image,
    String? prompt,
    double? latitude,
    double? longitude,
  });

  Future<ReadTextResponse> readText({required File image});
}
