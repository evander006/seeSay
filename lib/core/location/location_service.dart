import 'package:geolocator/geolocator.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/permissions/permission_service.dart';

class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

abstract class LocationService {
  Future<GeoPoint?> currentPosition();
}

class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService({required this.permissions, required this.logger});

  final PermissionService permissions;
  final AppLogger logger;

  @override
  Future<GeoPoint?> currentPosition() async {
    try {
      final allowed = await permissions.ensureLocation();
      if (!allowed) return null;
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 3),
        ),
      );
      return GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on Object catch (error) {
      logger.error(
        'location unavailable',
        action: 'gps',
        error: error.runtimeType,
      );
      return null;
    }
  }
}

class NullLocationService implements LocationService {
  @override
  Future<GeoPoint?> currentPosition() async => null;
}
