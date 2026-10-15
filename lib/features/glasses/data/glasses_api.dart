import 'dart:io';

import 'package:dio/dio.dart';
import 'package:seesay/core/errors/app_exception.dart';
import 'package:seesay/core/network/api_client.dart';

/// Answer of the glasses endpoints. [action]: speak, need_image, pitch, silence.
class GlassesReply {
  const GlassesReply({
    required this.status,
    required this.text,
    required this.action,
    required this.transcript,
    required this.serverMs,
  });

  factory GlassesReply.fromJson(Map<String, dynamic> json) {
    return GlassesReply(
      status: json['status'] as String? ?? 'error',
      text: (json['text_response'] as String? ?? '').trim(),
      action: json['action'] as String? ?? 'speak',
      transcript: (json['transcript'] as String? ?? '').trim(),
      serverMs: (json['execution_time_ms'] as num?)?.round() ?? 0,
    );
  }

  final String status;
  final String text;
  final String action;
  final String transcript;
  final int serverMs;
}

/// Server side of the glasses buttons (backend: src/api/v1/glasses.py).
class GlassesApi {
  GlassesApi(this._client);

  final ApiClient _client;

  /// The question as Opus packets from the glasses mic.
  Future<GlassesReply> voice(File audio) {
    return _post('/api/v1/glasses/voice', {
      'audio': MultipartFile.fromFileSync(
        audio.path,
        filename: 'voice.opus',
        contentType: DioMediaType('application', 'octet-stream'),
      ),
    });
  }

  /// A photo from the glasses camera, with the user's question when there is one.
  Future<GlassesReply> frame(File photo, {String? prompt}) {
    return _post('/api/v1/glasses/frame', {
      'file': MultipartFile.fromFileSync(
        photo.path,
        filename: 'glasses.jpg',
        contentType: DioMediaType('image', 'jpeg'),
      ),
      if (prompt != null && prompt.trim().isNotEmpty) 'prompt': prompt.trim(),
    });
  }

  /// Uploads the app's diagnostic log; returns the file name on the server.
  Future<String> uploadLog(File log) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/api/v1/glasses/logs',
        data: FormData.fromMap({
          'file': MultipartFile.fromFileSync(log.path, filename: 'seesay.log'),
        }),
      );
      return response.data?['saved'] as String? ?? '';
    } on DioException catch (error) {
      throw _map(error);
    }
  }

  Future<GlassesReply> _post(String path, Map<String, Object> fields) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        path,
        data: FormData.fromMap(fields),
        options: Options(receiveTimeout: const Duration(seconds: 25)),
      );
      return GlassesReply.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _map(error);
    }
  }

  AppException _map(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.connectionError ||
      DioExceptionType.unknown => NetworkException('Нет связи с сервером.'),
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => ApiException('Сервер долго отвечает. Попробуйте ещё раз.'),
      _ => ApiException('Сервер ответил ошибкой ${error.response?.statusCode ?? ''}.'),
    };
  }
}
