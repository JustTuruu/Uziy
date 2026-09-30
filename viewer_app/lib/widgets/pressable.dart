import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Press-scale micro-interaction for any tappable surface.
///
/// Shrinks the child to [scale] while pressed and springs back on release.
/// Quick taps still play the full squish. Disabled (no scale, no gestures,
/// semantics `enabled: false`) when both [onTap] and [onLongPress] are null.
/// Honors reduce-motion (no scaling).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.haptic = false,
    this.semanticLabel,
    this.isButton = true,
    this.excludeSemantics = false,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Scale while pressed (1.0 = no scale).
  final double scale;

  /// Fire `HapticFeedback.selectionClick()` on tap.
  final bool haptic;

  /// Screen-reader label. Required in practice for icon-only content.
  final String? semanticLabel;

  /// Announce as a button (default true).
  final bool isButton;

  /// Drop the child's own semantics (use with [semanticLabel] when the
  /// child's text would be redundant or misleading, e.g. a spinner).
  final bool excludeSemantics;

  final HitTestBehavior behavior;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.press,
    reverseDuration: AppDurations.normal,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.standard,
    // Played backwards on release: fast release with a tiny spring past 1.0.
    reverseCurve: Curves.easeInBack,
  );
  bool _down = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  void didUpdateWidget(covariant Pressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled && _controller.value != 0) {
      _down = false;
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _press() {
    if (AppMotion.reduced(context)) return;
    _down = true;
    _controller.forward();
  }

  void _release() {
    _down = false;
    if (_controller.status == AnimationStatus.forward) {
      // Let a quick tap finish its squish before springing back.
      _controller.forward().whenCompleteOrCancel(() {
        if (mounted && !_down) _controller.reverse();
      });
    } else {
      _controller.reverse();
    }
  }

  void _handleTap() {
    if (widget.haptic) HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  void _handleLongPress() {
    _release();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    return Semantics(
      container: true,
      button: widget.isButton,
      enabled: enabled,
      label: widget.semanticLabel,
      excludeSemantics: widget.excludeSemantics,
      onTap: widget.onTap == null ? null : _handleTap,
      onLongPress: widget.onLongPress == null ? null : _handleLongPress,
      child: GestureDetector(
        behavior: widget.behavior,
        excludeFromSemantics: true,
        onTapDown: enabled ? (_) => _press() : null,
        onTapUp: enabled ? (_) => _release() : null,
        onTapCancel: enabled ? _release : null,
        onTap: widget.onTap == null ? null : _handleTap,
        onLongPress: widget.onLongPress == null ? null : _handleLongPress,
        child: AnimatedBuilder(
          animation: _curve,
          child: widget.child,
          // Always keep the Transform in the tree so the child's element
          // (and its state) is never re-parented mid-press.
          builder: (context, child) => Transform.scale(
            scale: 1 - (1 - widget.scale) * _curve.value,
            child: child,
          ),
        ),
      ),
    );
  }
}
