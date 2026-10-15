import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Keeps the frames that got an answer, for the gallery. Only the newest [limit] stay.
class FrameStore {
  FrameStore({this._directory, this.limit = 50});

  final Directory? _directory;
  final int limit;

  /// Copies [frame] into app storage; returns the kept path or null when that fails.
  Future<String?> keep(File frame, String id) async {
    try {
      final dir = await _frames();
      final target = await frame.copy(
        '${dir.path}${Platform.pathSeparator}$id.jpg',
      );
      await _prune(dir);
      return target.path;
    } on Object {
      return null;
    }
  }

  Future<Directory> _frames() async {
    final base = _directory ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}frames');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _prune(Directory dir) async {
    final files = await dir
        .list()
        .where((entry) => entry is File && entry.path.endsWith('.jpg'))
        .cast<File>()
        .toList();
    if (files.length <= limit) return;
    // Names are microsecond timestamps of equal length, so text order is time order.
    files.sort((a, b) => a.path.compareTo(b.path));
    for (final old in files.take(files.length - limit)) {
      await old.delete();
    }
  }
}
