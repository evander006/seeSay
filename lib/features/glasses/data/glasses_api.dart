import 'dart:convert';
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
    this.destinationLat,
    this.destinationLon,
  });

  factory GlassesReply.fromJson(Map<String, dynamic> json) {
    final destination = json['destination'];
    return GlassesReply(
      destinationLat: destination is Map ? (destination['lat'] as num?)?.toDouble() : null,
      destinationLon: destination is Map ? (destination['lon'] as num?)?.toDouble() : null,
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

  /// Where a walking route leads (action `navigate`).
  final double? destinationLat;
  final double? destinationLon;
}

/// One line of a streamed answer: `meta` (what to do), `text` (a sentence to speak), `done`.
class AnswerPiece {
  const AnswerPiece({
    required this.type,
    this.action,
    this.transcript,
    this.text,
    this.serverMs,
    this.timings,
    this.destinationLat,
    this.destinationLon,
  });

  factory AnswerPiece.fromJson(Map<String, dynamic> json) {
    final destination = json['destination'];
    return AnswerPiece(
      type: json['type'] as String? ?? '',
      action: json['action'] as String?,
      transcript: json['transcript'] as String?,
      text: (json['text'] as String?)?.trim(),
      serverMs: (json['execution_time_ms'] as num?)?.round(),
      timings: json['timings'] is Map ? Map<String, dynamic>.from(json['timings'] as Map) : null,
      destinationLat: destination is Map ? (destination['lat'] as num?)?.toDouble() : null,
      destinationLon: destination is Map ? (destination['lon'] as num?)?.toDouble() : null,
    );
  }

  final String type;
  final String? action;
  final String? transcript;
  final String? text;
  final int? serverMs;
  final Map<String, dynamic>? timings;
  final double? destinationLat;
  final double? destinationLon;
}

/// Server side of the glasses buttons (backend: src/api/v1/glasses.py).
class GlassesApi {
  GlassesApi(this._client);

  final ApiClient _client;

  /// The question as Opus packets from the glasses mic, with the phone GPS when known.
  Future<GlassesReply> voice(File audio, {double? latitude, double? longitude}) {
    return _post('/api/v1/glasses/voice', {
      'audio': MultipartFile.fromFileSync(
        audio.path,
        filename: 'voice.opus',
        contentType: DioMediaType('application', 'octet-stream'),
      ),
      if (latitude != null && longitude != null) ...{
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      },
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

  /// The question as Opus packets; the answer comes back sentence by sentence.
  Stream<AnswerPiece> voiceStream(File audio, {double? latitude, double? longitude}) {
    return _stream('/api/v1/glasses/voice-stream', {
      'audio': MultipartFile.fromFileSync(
        audio.path,
        filename: 'voice.opus',
        contentType: DioMediaType('application', 'octet-stream'),
      ),
      if (latitude != null && longitude != null) ...{
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      },
    });
  }

  /// A photo from the glasses (+ the question); the answer comes back sentence by sentence.
  Stream<AnswerPiece> frameStream(File photo, {String? prompt}) {
    return _stream('/api/v1/glasses/frame-stream', {
      'file': MultipartFile.fromFileSync(
        photo.path,
        filename: 'glasses.jpg',
        contentType: DioMediaType('image', 'jpeg'),
      ),
      if (prompt != null && prompt.trim().isNotEmpty) 'prompt': prompt.trim(),
    });
  }

  Stream<AnswerPiece> _stream(String path, Map<String, Object> fields) async* {
    final Response<ResponseBody> response;
    try {
      response = await _client.dio.post<ResponseBody>(
        path,
        data: FormData.fromMap(fields),
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 25),
        ),
      );
    } on DioException catch (error) {
      throw _map(error);
    }
    final lines = response.data!.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (line.trim().isEmpty) continue;
      yield AnswerPiece.fromJson(jsonDecode(line) as Map<String, dynamic>);
    }
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
