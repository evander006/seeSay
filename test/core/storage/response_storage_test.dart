import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:seesay/core/storage/response_storage.dart';
import 'package:seesay/core/storage/saved_response.dart';

void main() {
  late Directory directory;
  late HiveResponseStorage storage;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('seesay_hive');
    Hive.init(directory.path);
    storage = HiveResponseStorage(boxName: 'responses_test');
    await storage.init();
    await storage.clear();
  });

  tearDown(() async {
    await storage.clear();
    await Hive.close();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  test('keeps the newest fifty responses', () async {
    for (var index = 0; index < 51; index++) {
      await storage.add(
        SavedResponse(
          id: '$index',
          text: 'ответ $index',
          createdAt: DateTime.utc(2026, 1, 1, 0, index),
          type: index.isEven ? ResponseType.scene : ResponseType.ocr,
        ),
      );
    }

    final items = await storage.getAll();
    expect(items, hasLength(ResponseHistory.maxItems));
    expect(items.first.id, '50');
    expect(items.last.id, '1');
    expect(items.map((item) => item.id), isNot(contains('0')));
  });
}
