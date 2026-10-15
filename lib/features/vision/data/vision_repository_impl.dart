import 'dart:io';

import 'package:seesay/features/vision/data/response_mapper.dart';
import 'package:seesay/features/vision/data/vision_remote_data_source.dart';
import 'package:seesay/features/vision/domain/vision_result.dart';

abstract class VisionRepository {
  Future<AnalyzeResult> analyzeFrame({
    required File image,
    String? prompt,
    double? latitude,
    double? longitude,
  });
}

abstract class OcrRepository {
  Future<OcrResult> readText({required File image});
}

class VisionRepositoryImpl implements VisionRepository {
  VisionRepositoryImpl({required this._remote});

  final VisionRemoteDataSource _remote;

  @override
  Future<AnalyzeResult> analyzeFrame({
    required File image,
    String? prompt,
    double? latitude,
    double? longitude,
  }) async {
    final dto = await _remote.analyzeFrame(
      image: image,
      prompt: prompt,
      latitude: latitude,
      longitude: longitude,
    );
    return ResponseMapper.toAnalyzeResult(dto);
  }
}

class OcrRepositoryImpl implements OcrRepository {
  OcrRepositoryImpl({required this._remote});

  final VisionRemoteDataSource _remote;

  @override
  Future<OcrResult> readText({required File image}) async {
    final dto = await _remote.readText(image: image);
    return ResponseMapper.toOcrResult(dto);
  }
}
