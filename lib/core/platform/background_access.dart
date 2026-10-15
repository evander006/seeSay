import 'package:seesay/core/platform/glasses_channel.dart';

/// Android battery optimisation can pause SeeSay in background; this asks to lift it.
class BackgroundAccess {
  BackgroundAccess(this._channel);

  final GlassesChannel _channel;
  var _askedThisRun = false;

  Future<bool> isUnrestricted() => _channel.isBackgroundUnrestricted();

  /// Shows the system dialog. Does nothing when the app is already unrestricted.
  Future<void> request() async {
    if (await isUnrestricted()) return;
    await _channel.requestBackgroundUnrestricted();
  }

  /// Asks once per app run, right after the glasses connect.
  Future<void> askOnce() async {
    if (_askedThisRun) return;
    _askedThisRun = true;
    try {
      await request();
    } on Object {
      // The dialog is a convenience; the link works without it.
    }
  }
}
