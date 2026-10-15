import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seesay/core/accessibility/accessibility_audio_queue.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/storage/response_storage.dart';
import 'package:seesay/core/storage/saved_response.dart';

class GalleryState extends Equatable {
  const GalleryState({this.items = const [], this.selected});

  final List<SavedResponse> items;
  final SavedResponse? selected;

  GalleryState copyWith({
    List<SavedResponse>? items,
    SavedResponse? selected,
    bool clearSelected = false,
  }) {
    return GalleryState(
      items: items ?? this.items,
      selected: clearSelected ? null : selected ?? this.selected,
    );
  }

  @override
  List<Object?> get props => [items, selected];
}

class GalleryCubit extends Cubit<GalleryState> {
  GalleryCubit({required this._storage, required this._speakText})
    : super(const GalleryState()) {
    _subscription = _storage.changes.listen((_) => unawaited(load()));
  }

  final ResponseStorage _storage;
  final SpeakText _speakText;
  late final StreamSubscription<void> _subscription;

  Future<void> load() async {
    final items = await _storage.getAll();
    if (!isClosed) emit(state.copyWith(items: items));
  }

  void open(SavedResponse item) {
    emit(state.copyWith(selected: item));
  }

  void closeDetail() {
    emit(state.copyWith(clearSelected: true));
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }

  Future<void> replay(SavedResponse item) {
    return _speakText(
      item.text,
      kind: SpeechKind.response,
      interrupt: true,
    );
  }
}
