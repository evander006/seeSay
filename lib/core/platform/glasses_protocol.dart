abstract final class GlassesProtocol {
  static const methodChannel = 'com.example.seesay/glasses';
  static const eventChannel = 'com.example.seesay/glasses_events';

  static const connectGlasses = 'connectGlasses';
  static const disconnectGlasses = 'disconnectGlasses';
  static const capturePhoto = 'capturePhoto';
  static const speak = 'speak';
  static const stopSpeaking = 'stopSpeaking';
  static const setSpeechRate = 'setSpeechRate';
  static const setLanguage = 'setLanguage';
  static const getConnectionState = 'getConnectionState';
  static const isBluetoothEnabled = 'isBluetoothEnabled';
  static const haptic = 'haptic';
  static const beep = 'beep';
  static const isBackgroundUnrestricted = 'isBackgroundUnrestricted';
  static const requestBackgroundUnrestricted = 'requestBackgroundUnrestricted';

  static const bleConnectionChanged = 'bleConnectionChanged';
  static const blePacketReceived = 'blePacketReceived';
  static const mediaButtonEvent = 'mediaButtonEvent';
  static const batteryChanged = 'batteryChanged';
  static const glassesButton = 'glassesButton';
  static const voiceState = 'voiceState';
  static const voiceCaptured = 'voiceCaptured';
  static const glassesPhoto = 'glassesPhoto';

  static const requestGlassesPhoto = 'requestGlassesPhoto';
  static const playPitch = 'playPitch';
  static const stopPitch = 'stopPitch';
  static const diagLog = 'diagLog';
  static const exportLog = 'exportLog';
  static const openRoute = 'openRoute';
  static const speakChunk = 'speakChunk';

  static const serviceUuid = '0000fa00-0000-1000-8000-00805f9b34fb';
  static const notifyCharacteristicUuid =
      '0000ea01-0000-1000-8000-00805f9b34fb';
  static const cccdUuid = '00002902-0000-1000-8000-00805f9b34fb';
}
