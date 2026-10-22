import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'mood_logic.dart';

/// Mood rating as a drag slider: five stops (Маш муу · Муу · Дунд · Сайн ·
/// Маш сайн), or the three of a question created before 2026-10-21 — the
/// number of [labels] decides.
///
/// While the thumb moves, only the *shapes* change: the eyes, brows and mouth
/// stay where they are and morph (worried brows and a deep frown → a frown →
/// flat pills → a smile → an open laugh) and the colour of the face, word and
/// track drifts red → gold → green on the app's panel. The big word is a
/// carousel that slides sideways with the thumb, so the moods flow past one
/// another instead of cross-fading in place. Letting go snaps to the
/// nearest stop with a small bounce; tapping a label or the track jumps there.
///
/// The thumb rests on Дунд until the viewer touches it, and a short nudge
/// shows it can be dragged; [onChanged] only fires from real input, so an
/// untouched slider is an unanswered question.
class MoodSlider extends StatefulWidget {
  const MoodSlider({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  /// One label per stop, worst to best ([kMoodSteps], or
  /// [kMoodLegacySteps] for an older question).
  final List<String> labels;

  /// Stop already chosen (e.g. coming back to this question), if any.
  final int? selectedIndex;
  final ValueChanged<int> onChanged;

  static const String semanticLabel = 'Үнэлгээ';
  static const double thumbSize = 52;
  static const double trackHeight = 4;

  @override
  State<MoodSlider> createState() => _MoodSliderState();
}

class _MoodSliderState extends State<MoodSlider> with TickerProviderStateMixin {
  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: AppDurations.medium,
  );

  /// Wiggles the thumb a little while the viewer has not touched it.
  late final AnimationController _hint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  /// What is drawn: the real position plus the hint nudge.
  late final ValueNotifier<double> _shown;

  static const double _nudgeAmplitude = 0.07;
  static const int _nudgeRepeats = 2;

  late double _base;
  double _snapFrom = kMoodStartPosition;
  double _snapTo = kMoodStartPosition;
  late bool _touched;

  int get _steps => widget.labels.length;
  late int _lastStop;
  bool _hintStarted = false;

  /// A real drag is under way (a plain tap also reports a drag 'cancel').
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    final selected = widget.selectedIndex;
    _touched = selected != null;
    _base = selected == null
        ? kMoodStartPosition
        : moodPositionOf(selected, steps: _steps);
    _lastStop = moodIndexFor(_base, steps: _steps);
    _shown = ValueNotifier(_base);
    _snap.addListener(_onSnap);
    _hint.addListener(_publish);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hintStarted && !_touched && !AppMotion.reduced(context)) {
      _hintStarted = true;
      _hint.repeat(count: _nudgeRepeats);
    }
  }

  @override
  void didUpdateWidget(MoodSlider old) {
    super.didUpdateWidget(old);
    final selected = widget.selectedIndex;
    if (selected != null &&
        selected != old.selectedIndex &&
        !_snap.isAnimating) {
      _touched = true;
      _hint.stop();
      _setBase(moodPositionOf(selected, steps: _steps));
    }
  }

  @override
  void dispose() {
    _snap.dispose();
    _hint.dispose();
    _shown.dispose();
    super.dispose();
  }

  void _publish() {
    final nudge =
        _touched ? 0.0 : math.sin(_hint.value * 2 * math.pi) * _nudgeAmplitude;
    _shown.value = (_base + nudge).clamp(0.0, 1.0);
  }

  void _setBase(double t, {bool haptic = false}) {
    _base = t.clamp(0.0, 1.0);
    _publish();
    final stop = moodIndexFor(_base, steps: _steps);
    if (stop != _lastStop) {
      _lastStop = stop;
      if (haptic) HapticFeedback.selectionClick();
    }
  }

  void _onSnap() {
    final eased = Curves.easeOutBack.transform(_snap.value);
    _setBase(_snapFrom + (_snapTo - _snapFrom) * eased);
  }

  void _touch() {
    if (_touched) return;
    _touched = true;
    _hint.stop();
    _publish();
  }

  void _animateTo(double target) {
    if (AppMotion.reduced(context)) {
      _setBase(target);
      return;
    }
    _snapFrom = _base;
    _snapTo = target;
    _snap.forward(from: 0);
  }

  void _choose(int index) {
    _touch();
    if (index != _lastStop) HapticFeedback.selectionClick();
    _animateTo(moodPositionOf(index, steps: _steps));
    widget.onChanged(index);
  }

  void _endDrag() {
    if (!_dragging) return;
    _dragging = false;
    _choose(moodIndexFor(_base, steps: _steps));
  }

  double _positionAt(double dx, double trackWidth) {
    const r = MoodSlider.thumbSize / 2;
    return positionFromDrag(dx - r, trackWidth - 2 * r);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _shown,
      builder: (context, position, _) {
        final stop = moodIndexFor(position, steps: _steps);
        final labels = widget.labels;
        return Semantics(
          slider: true,
          label: MoodSlider.semanticLabel,
          value: labels[stop],
          increasedValue: labels[math.min(stop + 1, _steps - 1)],
          decreasedValue: labels[math.max(stop - 1, 0)],
          onIncrease: stop < _steps - 1 ? () => _choose(stop + 1) : null,
          onDecrease: stop > 0 ? () => _choose(stop - 1) : null,
          child: ExcludeSemantics(child: _buildPanel(position, stop)),
        );
      },
    );
  }

  Widget _buildPanel(double position, int stop) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: moodPanelAt(position,
            surface: context.colors.surface, steps: _steps),
        borderRadius: AppRadii.brXl,
        border: Border.all(color: _tint(position).withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          FractionallySizedBox(
            widthFactor: 0.7,
            child: AspectRatio(
              aspectRatio: 1.45,
              child: CustomPaint(
                  painter: MoodFacePainter(position,
                      dark: context.colors.isDark, steps: _steps)),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          MoodWordCarousel(labels: widget.labels, position: position),
          const SizedBox(height: AppSpacing.xl),
          _buildTrack(position),
          const SizedBox(height: AppSpacing.sm),
          _buildLabels(stop),
        ],
      ),
    );
  }

  Widget _buildTrack(double position) {
    return LayoutBuilder(
      builder: (context, box) {
        const r = MoodSlider.thumbSize / 2;
        final width = box.maxWidth;
        final travel = width - 2 * r;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            _dragging = true;
            _snap.stop();
            _touch();
          },
          onHorizontalDragUpdate: (d) =>
              _setBase(_positionAt(d.localPosition.dx, width), haptic: true),
          onHorizontalDragEnd: (_) => _endDrag(),
          onHorizontalDragCancel: _endDrag,
          onTapUp: (d) => _choose(moodIndexFor(
              _positionAt(d.localPosition.dx, width),
              steps: _steps)),
          child: SizedBox(
            height: MoodSlider.thumbSize,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Positioned(
                  left: r,
                  right: r,
                  child: Container(
                    height: MoodSlider.trackHeight,
                    decoration: BoxDecoration(
                      color: context.colors.borderStrong,
                      borderRadius: AppRadii.brPill,
                    ),
                  ),
                ),
                // The part of the track the thumb has travelled.
                Positioned(
                  left: r,
                  width: travel * position,
                  child: Container(
                    height: MoodSlider.trackHeight,
                    decoration: BoxDecoration(
                      color: _tint(position),
                      borderRadius: AppRadii.brPill,
                    ),
                  ),
                ),
                for (var i = 0; i < _steps; i++)
                  Positioned(
                    left: r + travel * moodPositionOf(i, steps: _steps) - 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: moodPositionOf(i, steps: _steps) <= position
                            ? _tint(position)
                            : context.colors.borderStrong,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Positioned(
                  left: travel * position,
                  child: SizedBox.square(
                    dimension: MoodSlider.thumbSize,
                    child: CustomPaint(
                        painter: MoodThumbPainter(position,
                            dark: context.colors.isDark, steps: _steps)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static const int _labelFlex = 5;
  static const int _endLabelFlex = 6;

  Color _tint(double position) =>
      moodTintAt(position, dark: context.colors.isDark, steps: _steps);

  /// One tappable label per stop under the track: the ends hug the edges,
  /// the middle ones are centred. Five labels wrap to two short lines on a
  /// narrow screen ('Маш / муу') instead of crowding.
  Widget _buildLabels(int stop) {
    final last = _steps - 1;
    final compact = _steps > kMoodLegacySteps;
    Widget label(int i) {
      final (Alignment alignment, TextAlign textAlign) = i == 0
          ? (Alignment.centerLeft, TextAlign.left)
          : i == last
              ? (Alignment.centerRight, TextAlign.right)
              : (Alignment.center, TextAlign.center);
      final base =
          compact ? context.textStyles.label : context.textStyles.bodyStrong;
      return Expanded(
        // The end words are the longest ('Маш муу', 'Маш сайн'): a little
        // more room keeps them on one line like the rest.
        flex: compact && (i == 0 || i == last) ? _endLabelFlex : _labelFlex,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _choose(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Align(
              alignment: alignment,
              child: AnimatedDefaultTextStyle(
                duration: AppMotion.duration(context, AppDurations.fast),
                // Merge onto the inherited style: AnimatedDefaultTextStyle
                // replaces it outright, which would drop the theme's font.
                style: DefaultTextStyle.of(context).style.merge(base.copyWith(
                      color: i == stop
                          ? context.colors.textPrimary
                          : context.colors.textTertiary,
                      // Five labels: the chosen one changes colour only, so
                      // it never widens and jumps to a second line.
                      fontWeight: compact
                          ? FontWeight.w700
                          : (i == stop ? FontWeight.w800 : FontWeight.w600),
                      height: 1.2,
                    )),
                child: Text(
                  widget.labels[i],
                  textAlign: textAlign,
                  maxLines: 2,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (var i = 0; i <= last; i++) label(i)],
    );
  }
}

/// The big word: all labels sit side by side and the row slides with the
/// slider [position], fading the words that move away from the centre.
class MoodWordCarousel extends StatelessWidget {
  const MoodWordCarousel({
    super.key,
    required this.labels,
    required this.position,
  });

  final List<String> labels;
  final double position;

  static const double height = 72;
  static const double fontSize = 56;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < labels.length; i++)
              FractionalTranslation(
                translation:
                    Offset(moodWordShift(i, position, steps: labels.length), 0),
                child: Opacity(
                  opacity: moodWordOpacity(i, position, steps: labels.length),
                  child: SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labels[i].toUpperCase(),
                        maxLines: 1,
                        style: context.textStyles.display.copyWith(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                          color: moodTintAt(position,
                              dark: context.colors.isDark,
                              steps: labels.length),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Strokes the mouth: a quadratic arc whose middle sits [sag] below its ends.
void _paintMouth(
  Canvas canvas, {
  required Offset center,
  required double width,
  required double sag,
  required double stroke,
  required Color color,
  double open = 0,
}) {
  final path = Path()
    ..moveTo(center.dx - width / 2, center.dy)
    // A quadratic curve reaches half-way to its control point.
    ..quadraticBezierTo(
      center.dx,
      center.dy + 2 * sag,
      center.dx + width / 2,
      center.dy,
    );
  if (open > 0.01 && sag > 0) {
    // An open laugh: the smile closed by a straight top lip and filled.
    canvas.drawPath(
      Path.from(path)..close(),
      Paint()..color = color.withValues(alpha: open.clamp(0.0, 1.0)),
    );
  }
  canvas.drawPath(
    path,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round,
  );
}

/// The face: two eyes (with brows when worried) and a mouth at fixed spots,
/// shaped by [position] on a [steps]-stop scale.
class MoodFacePainter extends CustomPainter {
  const MoodFacePainter(this.position,
      {this.dark = false, this.steps = kMoodSteps});
  final bool dark;
  final int steps;

  final double position;

  static const double _eyeSpread = 0.27;
  static const double _eyeY = 0.28;
  static const double _mouthY = 0.78;
  static const double _mouthStroke = 0.05;
  static const double _browWidth = 0.17;
  static const double _browGap = 0.05;
  static const double _browLift = 0.07;
  static const double _browStroke = 0.04;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shape = moodShapeAt(position, steps: steps);
    final tint = moodTintAt(position, dark: dark, steps: steps);
    final eye = Paint()..color = tint;
    for (final side in [-1.0, 1.0]) {
      final center = Offset(w / 2 + side * _eyeSpread * w, _eyeY * h);
      final rect = Rect.fromCenter(
        center: center,
        width: shape.eyeWidth * w,
        height: shape.eyeHeight * w,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(math.min(rect.width, rect.height) / 2),
        ),
        eye,
      );
      if (shape.browTilt > 0.01) {
        // Worried brows: the inner end (towards the nose) rides higher.
        final y = rect.top - _browGap * w;
        final outer = Offset(center.dx + side * _browWidth * w / 2, y);
        final inner = Offset(center.dx - side * _browWidth * w / 2,
            y - shape.browTilt * _browLift * w);
        canvas.drawLine(
          outer,
          inner,
          Paint()
            ..color = tint.withValues(alpha: shape.browTilt.clamp(0.0, 1.0))
            ..strokeWidth = _browStroke * w
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    _paintMouth(
      canvas,
      center: Offset(w / 2, _mouthY * h),
      width: shape.mouthWidth * w,
      sag: shape.mouthSag * w,
      stroke: _mouthStroke * w,
      color: tint,
      open: shape.mouthOpen,
    );
  }

  @override
  bool shouldRepaint(MoodFacePainter old) =>
      old.position != position || old.dark != dark || old.steps != steps;
}

/// The draggable knob: a disc in the mood colour with a tiny dark mouth that
/// follows the mood.
class MoodThumbPainter extends CustomPainter {
  const MoodThumbPainter(this.position,
      {this.dark = false, this.steps = kMoodSteps});
  final bool dark;
  final int steps;

  final double position;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      size.width / 2,
      Paint()..color = moodTintAt(position, dark: dark, steps: steps),
    );
    final shape = moodShapeAt(position, steps: steps);
    _paintMouth(
      canvas,
      center: Offset(c.dx, c.dy + size.height * 0.04),
      width: size.width * 0.34,
      sag: shape.mouthSag * size.width * 0.9,
      stroke: size.width * 0.07,
      color: dark ? const AppPalette(true).onPrimary : MoodColors.ink,
    );
  }

  @override
  bool shouldRepaint(MoodThumbPainter old) =>
      old.position != position || old.dark != dark || old.steps != steps;
}
