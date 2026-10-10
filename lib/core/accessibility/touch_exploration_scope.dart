import 'package:flutter/widgets.dart';
import 'package:seesay/core/accessibility/accessibility_audio_service.dart';
import 'package:seesay/core/accessibility/haptic_service.dart';
import 'package:seesay/core/accessibility/touch_exploration_service.dart';

class TouchExplorationScope extends StatefulWidget {
  const TouchExplorationScope({
    required this.audio,
    required this.feedback,
    required this.customSpeechEnabled,
    required this.child,
    super.key,
  });

  final AccessibilityAudioService audio;
  final SystemFeedback feedback;
  final bool Function() customSpeechEnabled;
  final Widget child;

  static TouchExplorationScopeState? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_TouchExplorationInherited>()
        ?.state;
  }

  @override
  State<TouchExplorationScope> createState() => TouchExplorationScopeState();
}

class TouchExplorationScopeState extends State<TouchExplorationScope> {
  final TouchExplorationService service = TouchExplorationService();

  bool get _enabled => false;

  void updateZone(ExplorationZone zone) => service.updateZone(zone);

  void removeZone(String id) => service.removeZone(id);

  bool consumeTap(String id) => service.consumeTap(id);

  SystemFeedback get feedback => widget.feedback;

  void _explore(ExplorationZone _) {}

  void _down(PointerDownEvent event) {
    service.onPointerDown(
      pointerId: event.pointer,
      zone: service.hitTest(event.position),
      enabled: _enabled,
      onExplore: _explore,
    );
  }

  void _move(PointerMoveEvent event) {
    service.onPointerMove(
      pointerId: event.pointer,
      zone: service.hitTest(event.position),
      enabled: _enabled,
      onExplore: _explore,
    );
  }

  void _up(PointerEvent event) => service.onPointerUp(event.pointer);

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TouchExplorationInherited(
      state: this,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: widget.child,
      ),
    );
  }
}

class _TouchExplorationInherited extends InheritedWidget {
  const _TouchExplorationInherited({required this.state, required super.child});

  final TouchExplorationScopeState state;

  @override
  bool updateShouldNotify(covariant _TouchExplorationInherited oldWidget) {
    return false;
  }
}
