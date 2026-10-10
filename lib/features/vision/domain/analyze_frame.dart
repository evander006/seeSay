import 'dart:io';

import 'package:seesay/features/vision/data/vision_repository_impl.dart';
import 'package:seesay/features/vision/domain/vision_result.dart';

class AnalyzeFrame {
  AnalyzeFrame(this._repository);

  final VisionRepository _repository;

  Future<AnalyzeResult> call({
    required File image,
    String? prompt,
    double? latitude,
    double? longitude,
  }) {
    return _repository.analyzeFrame(
      image: image,
      prompt: prompt,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

class ReadText {
  ReadText(this._repository);

  final OcrRepository _repository;

  Future<OcrResult> call({required File image}) {
    return _repository.readText(image: image);
  }
}
