import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/core/accessibility/accessibility_audio_service.dart';
import 'package:seesay/core/accessibility/speech_messages.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/errors/app_exception.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/platform/glasses_channel.dart';
import 'package:seesay/core/storage/settings_store.dart';
import 'package:seesay/features/glasses/domain/glasses_repository.dart';
import 'package:seesay/features/glasses/domain/glasses_use_cases.dart';
import 'package:seesay/features/glasses/presentation/connection_cubit.dart';

import '../../support/fakes.dart';

class _Glasses implements GlassesRepository {
  _Glasses({this.failure});

  final Object? failure;
  final _events = StreamController<GlassesEvent>.broadcast();
  GlassesSnapshot _current = const GlassesSnapshot();

  @override
  GlassesSnapshot get current => _current;

  @override
  Stream<GlassesEvent> get events => _events.stream;

  @override
  Future<bool> isAdapterEnabled() async => failure is! BluetoothException;

  @override
  Future<void> connect({String? deviceAddress}) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    _current = const GlassesSnapshot(
      status: ConnectionStatus.connected,
      deviceAddress: 'MOCK:AIMB-S2',
      battery: 80,
    );
    _events.add(ConnectionChanged(_current));
  }

  @override
  Future<void> disconnect() async {
    _current = const GlassesSnapshot();
    _events.add(ConnectionChanged(_current));
  }

  Future<void> close() => _events.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTtsEngine engine;
  late _Glasses glasses;

  ConnectionCubit build({Object? failure}) {
    glasses = _Glasses(failure: failure);
    final settings = MemorySettingsStore();
    final logger = AppLogger();
    return ConnectionCubit(
      repository: glasses,
      connectGlasses: ConnectGlasses(
        repository: glasses,
        permissions: AllowAllPermissions(),
        settings: settings,
        logger: logger,
      ),
      disconnectGlasses: DisconnectGlasses(glasses),
      speakText: SpeakText(
        AccessibilityAudioService(engine: engine, logger: logger),
      ),
      feedback: QuietFeedback(),
      settings: settings,
      logger: logger,
    );
  }

  setUp(() {
    engine = MockTtsEngine();
  });

  blocTest<ConnectionCubit, ConnectionViewState>(
    'connect moves from connecting to connected',
    build: build,
    act: (cubit) => cubit.connect(),
    expect: () => [
      const ConnectionViewState(status: ConnectionStatus.connecting),
      const ConnectionViewState(
        status: ConnectionStatus.connected,
        deviceAddress: 'MOCK:AIMB-S2',
        battery: 80,
      ),
    ],
    verify: (_) async {
      await pumpEventQueue();
      expect(engine.spoken, isNot(contains(SpeechMessages.glassesConnected)));
    },
  );

  blocTest<ConnectionCubit, ConnectionViewState>(
    'bluetooth failure is spoken',
    build: () =>
        build(failure: BluetoothException(SpeechMessages.bluetoothUnavailable)),
    act: (cubit) => cubit.connect(),
    expect: () => [
      const ConnectionViewState(status: ConnectionStatus.connecting),
      const ConnectionViewState(
        status: ConnectionStatus.error,
        message: SpeechMessages.bluetoothUnavailable,
      ),
    ],
    verify: (_) async {
      await pumpEventQueue();
      expect(engine.spoken, contains(SpeechMessages.bluetoothUnavailable));
    },
  );
}
