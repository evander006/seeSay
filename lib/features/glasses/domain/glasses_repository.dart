import 'package:seesay/core/platform/glasses_channel.dart';

abstract class GlassesRepository {
  Stream<GlassesEvent> get events;

  GlassesSnapshot get current;

  Future<bool> isAdapterEnabled();

  Future<void> connect({String? deviceAddress});

  Future<void> disconnect();
}
