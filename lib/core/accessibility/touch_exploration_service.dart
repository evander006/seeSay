import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:seesay/core/accessibility/semantics_builder.dart';

class ExplorationZone {
  const ExplorationZone({
    required this.id,
    required this.label,
    required this.hint,
    required this.bounds,
  });

  final String id;
  final String label;
  final String hint;
  final Rect? bounds;

  String get spoken => semanticsAnnouncement(label: label, hint: hint);
}

class TouchExplorationService {
  TouchExplorationService({
    this.exploreDelay = const Duration(milliseconds: 700),
    this.debounce = const Duration(milliseconds: 1200),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration exploreDelay;
  final Duration debounce;
  final DateTime Function() _now;

  final Map<String, ExplorationZone> zones = {};
  String? lastSpokenElementId;
  DateTime? lastSpokenTimestamp;

  Timer? _timer;
  int? _pointer;
  String? _activeZoneId;
  bool exploredThisGesture = false;
  String? suppressTapForId;

  void updateZone(ExplorationZone zone) {
    zones[zone.id] = zone;
  }

  void removeZone(String id) {
    zones.remove(id);
  }

  ExplorationZone? hitTest(Offset position) {
    for (final zone in zones.values) {
      final bounds = zone.bounds;
      if (bounds != null && bounds.contains(position)) return zone;
    }
    return null;
  }

  bool shouldSpeak(String id, DateTime now) {
    final last = lastSpokenTimestamp;
    if (lastSpokenElementId == id &&
        last != null &&
        now.difference(last) < debounce) {
      return false;
    }
    lastSpokenElementId = id;
    lastSpokenTimestamp = now;
    return true;
  }

  void onPointerDown({
    required int pointerId,
    required ExplorationZone? zone,
    required bool enabled,
    required void Function(ExplorationZone zone) onExplore,
  }) {
    _timer?.cancel();
    _pointer = pointerId;
    exploredThisGesture = false;
    _activeZoneId = zone?.id;
    if (!enabled || zone == null) return;
    final captured = zone;
    _timer = Timer(exploreDelay, () {
      exploredThisGesture = true;
      suppressTapForId = captured.id;
      if (shouldSpeak(captured.id, _now())) onExplore(captured);
    });
  }

  void onPointerMove({
    required int pointerId,
    required ExplorationZone? zone,
    required bool enabled,
    required void Function(ExplorationZone zone) onExplore,
  }) {
    if (_pointer != pointerId || !enabled || zone == null) return;
    if (zone.id == _activeZoneId) return;
    _timer?.cancel();
    _activeZoneId = zone.id;
    exploredThisGesture = true;
    suppressTapForId = zone.id;
    if (shouldSpeak(zone.id, _now())) onExplore(zone);
  }

  void onPointerUp(int pointerId) {
    if (_pointer != pointerId) return;
    _timer?.cancel();
    _pointer = null;
    if (!exploredThisGesture) suppressTapForId = null;
  }

  bool consumeTap(String id) {
    if (suppressTapForId != id) return false;
    suppressTapForId = null;
    return true;
  }

  void dispose() {
    _timer?.cancel();
  }
}
