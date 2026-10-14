import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// One-time-code entry: [length] digit boxes, the current one highlighted.
///
/// Pattern: Adapter — one invisible numeric [TextField] does the real work
/// (soft keyboard, paste, SMS autofill, backspace) and the boxes only draw
/// its text. That is why pasting '123 456' or tapping an SMS suggestion
/// fills every box, which per-box fields cannot do reliably.
///
/// [onCompleted] fires once each time the code reaches full length; edit it
/// and it can fire again. Pass a [controller] to clear the code from outside
/// (e.g. after a wrong code, together with [hasError]).
///
/// Once every digit is typed the boxes slide together into the centre, then a
/// glowing [OtpDoneBadge] pops up and its check is drawn by hand, left to
/// right; clearing or editing the code (or [hasError]) spreads them back out.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    this.length = defaultLength,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onCompleted,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = false,
  });

  static const int defaultLength = 6;

  /// The whole 'gather, pop, draw the check' sequence.
  static const Duration doneDuration = Duration(milliseconds: 1100);

  /// Slice of [doneDuration] the boxes spend sliding together; the badge
  /// takes over from here.
  static const double gatherEnd = 0.45;
  static const Interval gatherSlice =
      Interval(0, gatherEnd, curve: AppMotion.exit);

  /// A box's centre sits one box-width plus the gap from its neighbour; the
  /// gap is small next to the box, so this stretches the slide a touch.
  static const double slidePerBox = 1.1;

  final int length;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  /// Red boxes, for a rejected code.
  final bool hasError;
  final bool enabled;
  final bool autofocus;

  @visibleForTesting
  static const Key boxesKey = Key('otp-boxes');

  static const String semanticLabel = 'Баталгаажуулах код';

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput>
    with SingleTickerProviderStateMixin {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;
  bool _completed = false;

  /// 0 = boxes in a row, 1 = finished check.
  late final AnimationController _done = AnimationController(
    vsync: this,
    duration: OtpInput.doneDuration,
    reverseDuration: AppDurations.medium,
  );

  /// The controller also notifies on cursor / selection changes; only a real
  /// text change may reach [OtpInput.onChanged].
  String _lastText = '';

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _lastText = _controller.text;
    _controller.addListener(_onText);
    _focus.addListener(_onFocus);
    if (_isDone) _done.value = 1;
  }

  bool get _isDone =>
      _controller.text.length == widget.length && !widget.hasError;

  void _syncDone() {
    if (_isDone) {
      AppMotion.reduced(context) ? _done.value = 1 : _done.forward();
    } else {
      AppMotion.reduced(context) ? _done.value = 0 : _done.reverse();
    }
  }

  @override
  void didUpdateWidget(OtpInput old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _ownController)?.removeListener(_onText);
      _controller.addListener(_onText);
    }
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
    if (old.hasError != widget.hasError) _syncDone();
  }

  @override
  void dispose() {
    _done.dispose();
    _controller.removeListener(_onText);
    _focus.removeListener(_onFocus);
    _ownController?.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  void _onText() {
    final code = _controller.text;
    if (code == _lastText) return;
    _lastText = code;
    setState(() {});
    _syncDone();
    widget.onChanged?.call(code);
    final full = code.length == widget.length;
    if (full && !_completed) {
      _completed = true;
      widget.onCompleted?.call(code);
    } else if (!full) {
      _completed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _controller.text;
    // The box being typed into; after the last digit it stays on the last.
    final active = _focus.hasFocus && widget.enabled
        ? code.length.clamp(0, widget.length - 1)
        : -1;

    return Semantics(
      label: OtpInput.semanticLabel,
      textField: true,
      // No LayoutBuilder: auth pages sit inside SliverFillRemaining, which
      // asks for intrinsic sizes, and LayoutBuilder cannot answer that.
      child: Stack(
        alignment: Alignment.center,
        children: [
          ExcludeSemantics(
            child: AnimatedBuilder(
              animation: _done,
              builder: (context, child) {
                final gather = OtpInput.gatherSlice.transform(_done.value);
                return Opacity(
                  key: OtpInput.boxesKey,
                  opacity: _done.value < OtpInput.gatherEnd ? 1 : 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < widget.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: FractionalTranslation(
                            translation: Offset(
                              -(i - (widget.length - 1) / 2) *
                                  OtpInput.slidePerBox *
                                  gather,
                              0,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: OtpBox.maxWidth,
                              ),
                              child: AspectRatio(
                                aspectRatio: 1 / OtpBox.heightFactor,
                                child: OtpBox(
                                  digit: i < code.length ? code[i] : null,
                                  active: i == active,
                                  error: widget.hasError,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          ExcludeSemantics(
            child: AnimatedBuilder(
              animation: _done,
              builder: (context, _) => OtpDoneBadge(progress: _done.value),
            ),
          ),
          // Invisible but hit-testable: a tap anywhere on the boxes lands
          // here and opens the keyboard.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                enableInteractiveSelection: false,
                showCursor: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One digit cell of an [OtpInput]: empty, filled, active (gold ring) or
/// error (red ring).
class OtpBox extends StatelessWidget {
  const OtpBox({
    super.key,
    required this.digit,
    required this.active,
    required this.error,
  });

  final String? digit;
  final bool active;
  final bool error;

  static const double maxWidth = 52;
  static const double heightFactor = 1.2;

  @override
  Widget build(BuildContext context) {
    final ring = error
        ? context.colors.danger
        : active
            ? context.colors.primary
            : null;
    return AnimatedContainer(
      duration: AppMotion.duration(context, AppDurations.fast),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: AppRadii.brMd,
        border: Border.all(
          color: ring ?? context.colors.border,
          width: ring == null ? 1 : 1.6,
        ),
        boxShadow: ring == null
            ? null
            : AppShadows.glow(ring,
                strength: 0.25, blur: 14, offset: Offset.zero),
      ),
      child: Text(
        digit ?? '',
        style: context.textStyles.display.copyWith(
          fontSize: 26,
          fontFeatures: AppTextStyles.tabular,
        ),
      ),
    );
  }
}

/// The glowing check that replaces the boxes of a finished [OtpInput].
///
/// [progress] is the whole sequence (0..1): the badge pops up after the boxes
/// have gathered, then its check is stroked from the short stroke's start to
/// the long stroke's tip, like a hand drawing it.
class OtpDoneBadge extends StatelessWidget {
  const OtpDoneBadge({super.key, required this.progress});

  final double progress;

  static const double size = 64;
  static const double strokeWidth = 4;

  /// Slice of the sequence spent popping up, then drawing.
  static const Interval popSlice = Interval(OtpInput.gatherEnd, 0.65);
  static const Interval drawSlice = Interval(0.6, 1);

  @override
  Widget build(BuildContext context) {
    final pop = popSlice.transform(progress);
    final draw = AppMotion.standard.transform(drawSlice.transform(progress));
    return IgnorePointer(
      child: Opacity(
        opacity: pop,
        child: Transform.scale(
          scale: 0.6 + 0.4 * AppMotion.emphasized.transform(pop),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: context.colors.surfaceElevated,
              borderRadius: AppRadii.brLg,
              border: Border.all(color: context.colors.primary, width: 1.6),
              boxShadow: AppShadows.glow(context.colors.primary,
                  strength: 0.6, blur: 22, offset: Offset.zero),
            ),
            child: CustomPaint(
              painter:
                  CheckPainter(progress: draw, color: context.colors.primary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Strokes a check mark; [progress] 0..1 is how much of it is drawn so far.
class CheckPainter extends CustomPainter {
  const CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.74, size.height * 0.36);
    final PathMetric metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = OtpDoneBadge.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(CheckPainter old) =>
      old.progress != progress || old.color != color;
}
