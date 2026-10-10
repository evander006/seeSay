import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seesay/core/accessibility/accessibility_audio_queue.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/storage/saved_response.dart';
import 'package:seesay/features/vision/domain/response_use_cases.dart';

class HistoryState extends Equatable {
  const HistoryState({this.loading = true, this.items = const []});

  final bool loading;
  final List<SavedResponse> items;

  @override
  List<Object?> get props => [loading, items];
}

class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit({required this._getLastResponses, required this._speakText})
    : super(const HistoryState());

  final GetLastResponses _getLastResponses;
  final SpeakText _speakText;

  Future<void> load() async {
    final items = await _getLastResponses();
    if (!isClosed) emit(HistoryState(loading: false, items: items));
  }

  Future<void> speak(SavedResponse response) {
    return _speakText(
      response.text,
      interrupt: true,
      kind: SpeechKind.response,
    );
  }
}
