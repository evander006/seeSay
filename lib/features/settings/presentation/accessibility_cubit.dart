import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seesay/core/accessibility/accessibility_audio_service.dart';
import 'package:seesay/core/storage/settings_store.dart';

class AccessibilityState extends Equatable {
  const AccessibilityState({
    this.speechRate = 1,
    this.language = 'ru-RU',
    this.customTouchSpeech = true,
  });

  final double speechRate;
  final String language;
  final bool customTouchSpeech;

  AccessibilityState copyWith({
    double? speechRate,
    String? language,
    bool? customTouchSpeech,
  }) {
    return AccessibilityState(
      speechRate: speechRate ?? this.speechRate,
      language: language ?? this.language,
      customTouchSpeech: customTouchSpeech ?? this.customTouchSpeech,
    );
  }

  @override
  List<Object?> get props => [speechRate, language, customTouchSpeech];
}

class AccessibilityCubit extends Cubit<AccessibilityState> {
  AccessibilityCubit({required this._settings, required this._audio})
    : super(const AccessibilityState());

  final SettingsStore _settings;
  final AccessibilityAudioService _audio;

  Future<void> load() async {
    final rate = _settings.speechRate;
    final language = _settings.language;
    await _audio.setSpeechRate(rate);
    await _audio.setLanguage(language);
    if (!isClosed) {
      emit(
        AccessibilityState(
          speechRate: rate,
          language: language,
          customTouchSpeech: _settings.customTouchSpeech,
        ),
      );
    }
  }

  Future<void> setSpeechRate(double rate) async {
    final clamped = rate.clamp(0.5, 2.0);
    await _settings.setSpeechRate(clamped);
    await _audio.setSpeechRate(clamped);
    if (!isClosed) emit(state.copyWith(speechRate: clamped));
  }

  Future<void> setLanguage(String language) async {
    await _settings.setLanguage(language);
    await _audio.setLanguage(language);
    if (!isClosed) emit(state.copyWith(language: language));
  }

  Future<void> setCustomTouchSpeech(bool enabled) async {
    await _settings.setCustomTouchSpeech(enabled);
    if (!isClosed) emit(state.copyWith(customTouchSpeech: enabled));
  }
}
