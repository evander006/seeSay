import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/network/api_client.dart';
import 'package:seesay/core/storage/settings_store.dart';
import 'package:seesay/features/backend/backend_cubit.dart';
import 'package:seesay/features/backend/backend_probe.dart';

import '../../support/fakes.dart';

void main() {
  group('normalizeBackendUrl', () {
    test('adds http and keeps the port', () {
      expect(normalizeBackendUrl(' 192.168.0.128:8000 '), 'http://192.168.0.128:8000');
    });

    test('keeps https and drops the trailing slash', () {
      expect(normalizeBackendUrl('https://api.seesay.by/'), 'https://api.seesay.by');
    });

    test('rejects text that is not an address', () {
      expect(normalizeBackendUrl(''), isNull);
      expect(normalizeBackendUrl('ftp://host'), isNull);
    });
  });

  group('BackendCubit', () {
    late MemorySettingsStore settings;
    late ApiClient client;
    late FakeProbe probe;
    late BackendCubit cubit;

    setUp(() async {
      settings = MemorySettingsStore();
      client = ApiClient(baseUrl: 'http://10.0.2.2:8000', logger: AppLogger());
      probe = FakeProbe();
      cubit = BackendCubit(
        client: client,
        settings: settings,
        probe: probe,
        fallbackUrl: 'http://10.0.2.2:8000',
      );
      await cubit.start();
    });

    tearDown(() => cubit.close());

    test('a reachable server is saved and used for requests', () async {
      final result = await cubit.apply('192.168.0.50:9000');

      expect(result.ok, isTrue);
      expect(result.message, contains('Адрес сохранён'));
      expect(settings.backendUrl, 'http://192.168.0.50:9000');
      expect(client.baseUrl, 'http://192.168.0.50:9000');
      expect(cubit.state.status, BackendStatus.online);
    });

    test('an unreachable server is not saved', () async {
      probe.ok = false;
      final result = await cubit.apply('192.168.0.77:8000');

      expect(result.ok, isFalse);
      expect(result.message, contains('не сохранён'));
      expect(settings.backendUrl, isNull);
      expect(client.baseUrl, 'http://10.0.2.2:8000');
    });
  });
}
