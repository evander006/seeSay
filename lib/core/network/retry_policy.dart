import 'package:seesay/core/errors/app_exception.dart';

class RetryPolicy {
  RetryPolicy({
    this.maxAttempts = 4,
    this.initialDelay = const Duration(seconds: 1),
    bool Function(Object error)? shouldRetry,
  }) : _shouldRetry = shouldRetry ?? _defaultShouldRetry;

  final int maxAttempts;
  final Duration initialDelay;
  final bool Function(Object error) _shouldRetry;

  static bool _defaultShouldRetry(Object error) => error is NetworkException;

  Duration delayForAttempt(int attempt) {
    return initialDelay * (1 << attempt);
  }

  Future<T> execute<T>(Future<T> Function() action) async {
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await action();
      } on Object catch (error) {
        lastError = error;
        final retry = _shouldRetry(error) && attempt < maxAttempts - 1;
        if (!retry) rethrow;
        await Future<void>.delayed(delayForAttempt(attempt));
      }
    }
    throw lastError ?? StateError('Retry failed');
  }
}
