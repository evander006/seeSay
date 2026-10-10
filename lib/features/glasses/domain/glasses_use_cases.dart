import 'package:seesay/core/config/app_config.dart';
import 'package:seesay/core/errors/app_exception.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/permissions/permission_service.dart';
import 'package:seesay/core/storage/settings_store.dart';
import 'package:seesay/features/glasses/domain/glasses_repository.dart';

class ConnectGlasses {
  ConnectGlasses({
    required this._repository,
    required this._permissions,
    required this._settings,
    required this._config,
    required this._logger,
  });

  final GlassesRepository _repository;
  final PermissionService _permissions;
  final SettingsStore _settings;
  final AppConfig _config;
  final AppLogger _logger;

  Future<void> call() async {
    if (!_config.useMockGlasses) {
      final allowed = await _permissions.ensureGlassesLink();
      if (!allowed) {
        _logger.warning('permission denied', action: 'bluetooth');
        throw PermissionException('Нет необходимого разрешения.');
      }
    }
    final enabled = await _repository.isAdapterEnabled();
    if (!enabled) {
      throw BluetoothException('Bluetooth недоступен.');
    }
    await _repository.connect(deviceAddress: _settings.lastDeviceAddress);
  }
}

class DisconnectGlasses {
  DisconnectGlasses(this._repository);

  final GlassesRepository _repository;

  Future<void> call() => _repository.disconnect();
}
