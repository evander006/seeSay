import 'dart:async';

import 'package:hive/hive.dart';
import 'package:seesay/core/storage/saved_response.dart';

abstract class ResponseStorage {
  Future<void> init();

  /// Fires after every add or clear, so the chat and gallery refresh by themselves.
  Stream<void> get changes;

  Future<List<SavedResponse>> getAll();

  Future<void> add(SavedResponse response);

  Future<void> clear();
}

class HiveResponseStorage implements ResponseStorage {
  HiveResponseStorage({this.boxName = 'responses'});

  final String boxName;
  Box<dynamic>? _box;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> init() async {
    if (Hive.isBoxOpen(boxName)) {
      _box = Hive.box<dynamic>(boxName);
      return;
    }
    _box = await Hive.openBox<dynamic>(boxName);
  }

  @override
  Future<List<SavedResponse>> getAll() async {
    final raw = _box?.get('items');
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => SavedResponse.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<void> add(SavedResponse response) async {
    final box = _box;
    if (box == null) return;
    final next = ResponseHistory.add(await getAll(), response);
    await box.put('items', next.map((item) => item.toJson()).toList());
    _changes.add(null);
  }

  @override
  Future<void> clear() async {
    await _box?.delete('items');
    _changes.add(null);
  }
}

class MemoryResponseStorage implements ResponseStorage {
  final List<SavedResponse> _items = [];
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> init() async {}

  @override
  Future<List<SavedResponse>> getAll() async {
    return List<SavedResponse>.unmodifiable(_items);
  }

  @override
  Future<void> add(SavedResponse response) async {
    final next = ResponseHistory.add(_items, response);
    _items
      ..clear()
      ..addAll(next);
    _changes.add(null);
  }

  @override
  Future<void> clear() async {
    _items.clear();
    _changes.add(null);
  }
}
