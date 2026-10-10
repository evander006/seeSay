import 'package:hive/hive.dart';
import 'package:seesay/core/storage/saved_response.dart';

abstract class ResponseStorage {
  Future<void> init();

  Future<List<SavedResponse>> getAll();

  Future<void> add(SavedResponse response);

  Future<void> clear();
}

class HiveResponseStorage implements ResponseStorage {
  HiveResponseStorage({this.boxName = 'responses'});

  final String boxName;
  Box<dynamic>? _box;

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
  }

  @override
  Future<void> clear() async {
    await _box?.delete('items');
  }
}

class MemoryResponseStorage implements ResponseStorage {
  final List<SavedResponse> _items = [];

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
  }

  @override
  Future<void> clear() async {
    _items.clear();
  }
}
