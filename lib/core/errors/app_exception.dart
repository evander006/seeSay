sealed class AppException implements Exception {
  AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BluetoothException extends AppException {
  BluetoothException(super.message);
}

class CameraException extends AppException {
  CameraException(super.message);
}

class NetworkException extends AppException {
  NetworkException(super.message);
}

class ApiException extends AppException {
  ApiException(super.message);
}

class PermissionException extends AppException {
  PermissionException(super.message);
}

class SpeechException extends AppException {
  SpeechException(super.message);
}
