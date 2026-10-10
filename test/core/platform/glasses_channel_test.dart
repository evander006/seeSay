import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/core/errors/app_exception.dart';
import 'package:seesay/core/platform/glasses_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing Android channel fails closed', () async {
    final channel = GlassesChannel();
    expect(await channel.recentGlassesEvents(), isEmpty);
    expect(await channel.pendingGlassesEvents(), isEmpty);
    expect(await channel.backgroundMonitoringStatus(), isFalse);
    expect(
      channel.startBackgroundMonitoring(),
      throwsA(isA<BluetoothException>()),
    );
  });
}
