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

  final int length;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  /// Red boxes, for a rejected code.
  final bool hasError;
  final bool enabled;
  final bool autofocus;

  static const String semanticLabel = 'Баталгаажуулах код';

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;
  bool _completed = false;

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
  }

  @override
  void dispose() {
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Flexible(
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
                ],
              ],
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
        ? AppColors.danger
        : active
            ? AppColors.primary
            : null;
    return AnimatedContainer(
      duration: AppMotion.duration(context, AppDurations.fast),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadii.brMd,
        border: Border.all(
          color: ring ?? AppColors.border,
          width: ring == null ? 1 : 1.6,
        ),
        boxShadow: ring == null
            ? null
            : AppShadows.glow(ring,
                strength: 0.25, blur: 14, offset: Offset.zero),
      ),
      child: Text(
        digit ?? '',
        style: AppTextStyles.display.copyWith(
          fontSize: 26,
          fontFeatures: AppTextStyles.tabular,
        ),
      ),
    );
  }
}
