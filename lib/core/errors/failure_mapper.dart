import 'package:seesay/core/accessibility/speech_messages.dart';
import 'package:seesay/core/errors/app_exception.dart';
import 'package:seesay/core/errors/failure.dart';

abstract final class FailureMapper {
  static Failure map(Object error) {
    final exception = error is AppException
        ? error
        : ApiException(SpeechMessages.apiUnavailable);
    final message = switch (exception) {
      NetworkException() => SpeechMessages.networkUnavailable,
      BluetoothException(:final message) =>
        message.isEmpty ? SpeechMessages.bluetoothUnavailable : message,
      PermissionException() => SpeechMessages.permissionDenied,
      CameraException(:final message) =>
        message.isEmpty ? SpeechMessages.cameraFailed : message,
      ApiException(:final message) =>
        message.isEmpty ? SpeechMessages.apiUnavailable : message,
      SpeechException(:final message) =>
        message.isEmpty ? SpeechMessages.speechFailed : message,
    };
    return Failure(message: message, cause: exception);
  }
}
