import 'package:dio/dio.dart';

class ProbeResult {
  const ProbeResult({required this.ok, required this.message});

  final bool ok;
  final String message;
}

/// Turns what the user typed into a base URL: `192.168.0.5:8000` → `http://192.168.0.5:8000`.
/// Returns null when it cannot be an address.
String? normalizeBackendUrl(String input) {
  var text = input.trim();
  if (text.isEmpty) return null;
  if (!text.contains('://')) text = 'http://$text';
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  var normalized = Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
  ).toString();
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

/// Asks `GET {url}/api/v1/health` and explains the outcome in plain words.
class BackendProbe {
  BackendProbe({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
              sendTimeout: const Duration(seconds: 5),
              validateStatus: (_) => true,
            ),
          );

  final Dio _dio;

  Future<ProbeResult> check(String baseUrl) async {
    final started = DateTime.now();
    try {
      final response = await _dio.get<Object?>('$baseUrl/api/v1/health');
      final ms = DateTime.now().difference(started).inMilliseconds;
      final code = response.statusCode ?? 0;
      final data = response.data;
      if (code == 200 && data is Map && data['status'] == 'ok') {
        return ProbeResult(
          ok: true,
          message: 'Сервер SeeSay на связи, ответ за $ms мс.',
        );
      }
      if (code == 404 || code == 200) {
        return const ProbeResult(
          ok: false,
          message:
              'По этому адресу отвечает другой сервер, а не SeeSay. Проверьте порт.',
        );
      }
      return ProbeResult(ok: false, message: 'Сервер ответил ошибкой $code.');
    } on DioException catch (error) {
      final host = Uri.tryParse(baseUrl)?.authority ?? baseUrl;
      final message = switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout =>
          'Сервер $host не ответил за 5 секунд. Проверьте, что он запущен и доступен из этой сети.',
        DioExceptionType.badCertificate =>
          'У сервера $host неверный HTTPS-сертификат.',
        _ =>
          'Не удалось подключиться к $host. Проверьте адрес, порт и что сервер запущен.',
      };
      return ProbeResult(ok: false, message: message);
    } on Object {
      return const ProbeResult(
        ok: false,
        message: 'Не удалось проверить сервер.',
      );
    }
  }
}
