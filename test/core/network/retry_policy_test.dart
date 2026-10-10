import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/core/errors/app_exception.dart';
import 'package:seesay/core/network/retry_policy.dart';

void main() {
  test('delays grow exponentially and then stop', () {
    final policy = RetryPolicy();
    expect(policy.delayForAttempt(0), const Duration(seconds: 1));
    expect(policy.delayForAttempt(1), const Duration(seconds: 2));
    expect(policy.delayForAttempt(2), const Duration(seconds: 4));
    expect(policy.delayForAttempt(3), const Duration(seconds: 8));
  });

  test('retries only network failures and caps the attempts', () async {
    var calls = 0;
    final policy = RetryPolicy(maxAttempts: 4, initialDelay: Duration.zero);
    await expectLater(
      policy.execute(() async {
        calls += 1;
        throw NetworkException('offline');
      }),
      throwsA(isA<NetworkException>()),
    );
    expect(calls, 4);
  });

  test('does not retry permission failures', () async {
    var calls = 0;
    final policy = RetryPolicy(initialDelay: Duration.zero);
    await expectLater(
      policy.execute(() async {
        calls += 1;
        throw PermissionException('denied');
      }),
      throwsA(isA<PermissionException>()),
    );
    expect(calls, 1);
  });
}
