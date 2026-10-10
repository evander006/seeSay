import 'package:flutter/material.dart';
import 'package:seesay/core/accessibility/haptic_service.dart';
import 'package:seesay/core/accessibility/touch_exploration_scope.dart';
import 'package:seesay/core/accessibility/touch_exploration_service.dart';

class AccessibleAction extends StatefulWidget {
  const AccessibleAction({
    required this.id,
    required this.label,
    required this.hint,
    required this.onTap,
    required this.child,
    this.enabled = true,
    this.haptic = HapticKind.tap,
    super.key,
  });

  final String id;
  final String label;
  final String hint;
  final VoidCallback? onTap;
  final Widget child;
  final bool enabled;
  final HapticKind haptic;

  @override
  State<AccessibleAction> createState() => _AccessibleActionState();
}

class _AccessibleActionState extends State<AccessibleAction> {
  TouchExplorationScopeState? _scope;
  DateTime? _lastActivation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = TouchExplorationScope.maybeOf(context);
    _schedulePublish();
  }

  @override
  void didUpdateWidget(covariant AccessibleAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedulePublish();
  }

  void _schedulePublish() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _publish());
  }

  void _publish() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    _scope?.updateZone(
      ExplorationZone(
        id: widget.id,
        label: widget.label,
        hint: widget.hint,
        bounds: rect,
      ),
    );
  }

  @override
  void dispose() {
    _scope?.removeZone(widget.id);
    super.dispose();
  }

  void _activate() {
    if (!widget.enabled || widget.onTap == null) return;
    if (_scope?.consumeTap(widget.id) ?? false) return;
    final now = DateTime.now();
    final last = _lastActivation;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 400)) {
      return;
    }
    _lastActivation = now;
    final feedback = _scope?.feedback ?? FallbackSystemFeedback();
    feedback.haptic(widget.haptic);
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      hint: widget.hint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? _activate : null,
        child: widget.child,
      ),
    );
  }
}
