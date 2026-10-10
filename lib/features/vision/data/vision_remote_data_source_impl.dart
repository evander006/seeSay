import 'dart:io';

import 'package:dio/dio.dart';
import 'package:seesay/core/errors/app_exception.dart';
import 'package:seesay/core/network/api_client.dart';
import 'package:seesay/core/network/retry_policy.dart';
import 'package:seesay/features/vision/data/dto/vision_dto.dart';
import 'package:seesay/features/vision/data/vision_remote_data_source.dart';

class VisionRemoteDataSourceImpl implements VisionRemoteDataSource {
  VisionRemoteDataSourceImpl({
    required this._client,
    required this._retryPolicy,
  });

  final ApiClient _client;
  final RetryPolicy _retryPolicy;

  @override
  Future<AnalyzeFrameResponse> analyzeFrame({
    required File image,
    String? prompt,
    double? latitude,
    double? longitude,
  }) {
    return _retryPolicy.execute(() async {
      try {
        final form = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            image.path,
            filename: 'frame.jpg',
            contentType: DioMediaType('image', 'jpeg'),
          ),
          'prompt': ?prompt,
          'latitude': ?latitude,
          'longitude': ?longitude,
        });
        final response = await _client.dio.post<Map<String, dynamic>>(
          '/api/v1/analyze-frame',
          data: form,
        );
        return AnalyzeFrameResponse.fromJson(response.data ?? const {});
      } on DioException catch (error) {
        throw _mapDio(error);
      }
    });
  }

  @override
  Future<ReadTextResponse> readText({required File image}) {
    return _retryPolicy.execute(() async {
      try {
        final form = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            image.path,
            filename: 'frame.jpg',
            contentType: DioMediaType('image', 'jpeg'),
          ),
        });
        final response = await _client.dio.post<Map<String, dynamic>>(
          '/api/v1/read-text',
          data: form,
        );
        return ReadTextResponse.fromJson(response.data ?? const {});
      } on DioException catch (error) {
        throw _mapDio(error);
      }
    });
  }

  AppException _mapDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return NetworkException(
          'Нет подключения к интернету. Попробуйте ещё раз.',
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
        return ApiException('Сервис анализа временно недоступен.');
    }
  }
}
