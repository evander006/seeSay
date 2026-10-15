import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seesay/core/network/api_client.dart';
import 'package:seesay/core/storage/settings_store.dart';
import 'package:seesay/features/backend/backend_probe.dart';

enum BackendStatus { unknown, checking, online, offline }

class BackendState extends Equatable {
  const BackendState({
    this.url = '',
    this.status = BackendStatus.unknown,
    this.message,
  });

  /// The saved server the app sends frames to.
  final String url;
  final BackendStatus status;

  /// Result of the last check, in plain words.
  final String? message;

  @override
  List<Object?> get props => [url, status, message];
}

/// Which server the app talks to, and whether it answers.
class BackendCubit extends Cubit<BackendState> {
  BackendCubit({
    required this._client,
    required this._settings,
    required this._probe,
    required this._fallbackUrl,
  }) : super(const BackendState());

  final ApiClient _client;
  final SettingsStore _settings;
  final BackendProbe _probe;
  final String _fallbackUrl;

  /// Applies the saved server (or the build default) and checks it quietly.
  Future<void> start() async {
    final url = _settings.backendUrl ?? _fallbackUrl;
    _client.baseUrl = url;
    _emit(BackendState(url: url));
    await refresh();
  }

  Future<void> refresh() async {
    final url = state.url;
    if (url.isEmpty) return;
    _emit(BackendState(url: url, status: BackendStatus.checking));
    final result = await _probe.check(url);
    if (state.url != url) return;
    _emit(
      BackendState(
        url: url,
        status: result.ok ? BackendStatus.online : BackendStatus.offline,
        message: result.message,
      ),
    );
  }

  /// Checks [input] and saves it only if a SeeSay server answers there.
  /// The returned result is what the user should be told.
  Future<ProbeResult> apply(String input) async {
    final url = normalizeBackendUrl(input);
    if (url == null) {
      return const ProbeResult(
        ok: false,
        message:
            'Это не похоже на адрес. Пример: 192.168.0.128:8000 или https://api.example.com',
      );
    }
    final previous = state;
    _emit(BackendState(url: previous.url, status: BackendStatus.checking));
    final result = await _probe.check(url);
    if (!result.ok) {
      _emit(previous);
      return ProbeResult(
        ok: false,
        message: '${result.message} Адрес не сохранён.',
      );
    }
    await _settings.setBackendUrl(url);
    _client.baseUrl = url;
    _emit(
      BackendState(
        url: url,
        status: BackendStatus.online,
        message: result.message,
      ),
    );
    return ProbeResult(ok: true, message: '${result.message} Адрес сохранён.');
  }

  void _emit(BackendState next) {
    if (!isClosed) emit(next);
  }
}
