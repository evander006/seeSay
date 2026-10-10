import 'package:dio/dio.dart';
import 'package:seesay/core/logging/app_logger.dart';

class ApiClient {
  ApiClient({required String baseUrl, required AppLogger logger})
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          logger.info(
            'API request',
            action: '${options.method} ${options.path}',
          );
          handler.next(options);
        },
        onResponse: (response, handler) {
          logger.info(
            'API success',
            action:
                '${response.requestOptions.path} ${response.statusCode ?? ''}',
          );
          handler.next(response);
        },
        onError: (error, handler) {
          logger.error(
            'API error',
            action: error.requestOptions.path,
            error: error.type,
          );
          handler.next(error);
        },
      ),
    );
  }

  final Dio dio;
}
