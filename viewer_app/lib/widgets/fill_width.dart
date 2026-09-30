import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Fills the available width when the incoming width is bounded. When the
/// width is unbounded (for example a Row child without Expanded, a
/// horizontal list, or a Column nested in a Row), it sizes to [child], or to
/// [fallbackWidth] when one is given, and does not throw
/// "BoxConstraints forces an infinite width".
///
/// Reusable widgets use this in place of `SizedBox(width: double.infinity)`.
/// It supports intrinsic sizing, so it is safe inside `IntrinsicWidth` and
/// `AlertDialog`.
class FillWidth extends SingleChildRenderObjectWidget {
  const FillWidth({super.key, this.fallbackWidth, super.child});

  /// Width used when the incoming width is unbounded. Null means the widget
  /// hugs its child.
  final double? fallbackWidth;

  @override
  RenderFillWidth createRenderObject(BuildContext context) =>
      RenderFillWidth(fallbackWidth: fallbackWidth);

  @override
  void updateRenderObject(BuildContext context, RenderFillWidth renderObject) {
    renderObject.fallbackWidth = fallbackWidth;
  }
}

/// Render object behind [FillWidth].
class RenderFillWidth extends RenderProxyBox {
  RenderFillWidth({double? fallbackWidth, RenderBox? child})
      : _fallbackWidth = fallbackWidth,
        super(child);

  double? get fallbackWidth => _fallbackWidth;
  double? _fallbackWidth;
  set fallbackWidth(double? value) {
    if (value == _fallbackWidth) return;
    _fallbackWidth = value;
    markNeedsLayout();
  }

  BoxConstraints _childConstraints(BoxConstraints c) {
    if (c.hasBoundedWidth) return c.tighten(width: c.maxWidth);
    final fallback = _fallbackWidth;
    if (fallback != null) return c.tighten(width: fallback);
    return c;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final inner = _childConstraints(constraints);
    final c = child;
    if (c == null) return constraints.constrain(inner.smallest);
    return constraints.constrain(c.getDryLayout(inner));
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) =>
      child?.getDryBaseline(_childConstraints(constraints), baseline);

  @override
  void performLayout() {
    final inner = _childConstraints(constraints);
    final c = child;
    if (c == null) {
      size = constraints.constrain(inner.smallest);
      return;
    }
    c.layout(inner, parentUsesSize: true);
    size = constraints.constrain(c.size);
  }
}
