abstract final class GlassesProtocol {
  static const methodChannel = 'com.example.seesay/glasses';
  static const eventChannel = 'com.example.seesay/glasses_events';

  static const connectGlasses = 'connectGlasses';
  static const disconnectGlasses = 'disconnectGlasses';
  static const startCapture = 'startCapture';
  static const stopCapture = 'stopCapture';
  static const speak = 'speak';
  static const stopSpeaking = 'stopSpeaking';
  static const setSpeechRate = 'setSpeechRate';
  static const setLanguage = 'setLanguage';
  static const getConnectionState = 'getConnectionState';
  static const isBluetoothEnabled = 'isBluetoothEnabled';
  static const haptic = 'haptic';
  static const beep = 'beep';
  static const startBackgroundMonitoring = 'startBackgroundMonitoring';
  static const stopBackgroundMonitoring = 'stopBackgroundMonitoring';
  static const getBackgroundMonitoringStatus = 'getBackgroundMonitoringStatus';
  static const enableMockMode = 'enableMockMode';
  static const disableMockMode = 'disableMockMode';
  static const triggerMockEvent = 'triggerMockEvent';
  static const getPendingGlassesEvents = 'getPendingGlassesEvents';
  static const acknowledgeGlassesEvent = 'acknowledgeGlassesEvent';
  static const getRecentGlassesEvents = 'getRecentGlassesEvents';

  static const bleConnectionChanged = 'bleConnectionChanged';
  static const blePacketReceived = 'blePacketReceived';
  static const mediaButtonEvent = 'mediaButtonEvent';
  static const batteryChanged = 'batteryChanged';
  static const glassesEvent = 'glassesEvent';

  static const serviceUuid = '0000fa00-0000-1000-8000-00805f9b34fb';
  static const notifyCharacteristicUuid =
      '0000ea01-0000-1000-8000-00805f9b34fb';
  static const cccdUuid = '00002902-0000-1000-8000-00805f9b34fb';
}
