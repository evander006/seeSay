import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

abstract class ConnectivityService {
  Future<bool> get isOnline;

  Stream<bool> get onStatusChanged;
}

class DeviceConnectivityService implements ConnectivityService {
  DeviceConnectivityService({
    Connectivity? connectivity,
    InternetConnection? internet,
  }) : _connectivity = connectivity ?? Connectivity(),
       _internet = internet ?? InternetConnection();

  final Connectivity _connectivity;
  final InternetConnection _internet;

  @override
  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    if (results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none)) {
      return false;
    }
    return _internet.hasInternetAccess;
  }

  @override
  Stream<bool> get onStatusChanged {
    return _connectivity.onConnectivityChanged.asyncMap((results) async {
      if (results.isEmpty ||
          results.every((result) => result == ConnectivityResult.none)) {
        return false;
      }
      return _internet.hasInternetAccess;
    });
  }
}
