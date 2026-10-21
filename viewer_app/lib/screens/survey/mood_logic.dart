/// Pure maths and constants of the mood slider (no widgets, so it is unit
/// tested on its own). A slider position `t` runs 0..1 across the three
/// moods: 0 = Муу, 0.5 = Дунд, 1 = Сайн.
library;

import 'dart:ui';

import '../../models/survey_question.dart';
import '../../theme/app_theme.dart';

const int kMoodSteps = 3;

/// Answers of a RATING question when the backend sent none (it normally
/// sends exactly these).
const List<String> kMoodLabels = ['Муу', 'Дунд', 'Сайн'];

/// Where the thumb rests before the viewer has touched it.
const double kMoodStartPosition = 0.5;

/// The mood hues: coral → the brand's own gold → mint. They colour only the
/// face, the word and the slider; the panel stays the app's own surface, so
/// the question belongs to the rest of the app. Kept apart from the brand
/// palette because a red-to-green scale carries meaning.
abstract final class MoodColors {
  static const Color bad = Color(0xFFB83E31);
  static const Color mid = AppColors.warning;
  static const Color good = Color(0xFF176445);

  /// Drawn on a mood-coloured surface (the thumb's mouth).
  static const Color ink = AppColors.background;
}

/// Share of the mood colour mixed into the panel: enough that the panel
/// follows the mood, little enough that it still reads as the app's surface
/// (light or dark).
const double kMoodPanelWash = 0.10;

/// How the face looks at one position. Sizes are fractions of the face width.
class MoodShape {
  const MoodShape({
    required this.eyeWidth,
    required this.eyeHeight,
    required this.mouthWidth,
    required this.mouthSag,
  });

  final double eyeWidth;
  final double eyeHeight;
  final double mouthWidth;

  /// How far the middle of the mouth sits below its ends; negative = frown.
  final double mouthSag;

  static MoodShape lerp(MoodShape a, MoodShape b, double t) => MoodShape(
        eyeWidth: lerpDouble(a.eyeWidth, b.eyeWidth, t)!,
        eyeHeight: lerpDouble(a.eyeHeight, b.eyeHeight, t)!,
        mouthWidth: lerpDouble(a.mouthWidth, b.mouthWidth, t)!,
        mouthSag: lerpDouble(a.mouthSag, b.mouthSag, t)!,
      );
}

const MoodShape _bad = MoodShape(
  eyeWidth: 0.19,
  eyeHeight: 0.19,
  mouthWidth: 0.26,
  mouthSag: -0.13,
);
const MoodShape _mid = MoodShape(
  eyeWidth: 0.30,
  eyeHeight: 0.11,
  mouthWidth: 0.20,
  mouthSag: -0.05,
);
const MoodShape _good = MoodShape(
  eyeWidth: 0.30,
  eyeHeight: 0.30,
  mouthWidth: 0.28,
  mouthSag: 0.15,
);

double _clamp01(double t) => t.clamp(0.0, 1.0);

/// Interpolates through three anchors: first half blends [a]→[b], second [b]→[c].
T _acrossMoods<T>(
  double t,
  T a,
  T b,
  T c,
  T Function(T, T, double) blend,
) {
  final p = _clamp01(t);
  return p <= 0.5 ? blend(a, b, p * 2) : blend(b, c, (p - 0.5) * 2);
}

/// Eyes and mouth at [t]; their positions never change, only these sizes.
MoodShape moodShapeAt(double t) =>
    _acrossMoods(t, _bad, _mid, _good, MoodShape.lerp);

/// Panel colour at [t], blended so it drifts while the thumb is dragged.
Color moodTintAt(double t, {bool dark = false}) => _acrossMoods(
      t,
      dark ? const Color(0xFFFFB2A5) : MoodColors.bad,
      dark ? const Color(0xFFF0CE88) : MoodColors.mid,
      dark ? const AppPalette(true).primary : MoodColors.good,
      (a, b, p) => Color.lerp(a, b, p)!,
    );

/// The stop (0..[kMoodSteps]-1) nearest to [t].
int moodIndexFor(double t) => (_clamp01(t) * (kMoodSteps - 1)).round();

/// Position of stop [index].
double moodPositionOf(int index) => index / (kMoodSteps - 1);

/// Slider position for a finger at [dx] along a track of [width].
double positionFromDrag(double dx, double width) =>
    width <= 0 ? kMoodStartPosition : _clamp01(dx / width);

/// How far word [index] sits from the centre, in word-widths: 0 when it is
/// the current mood, ±1 when the neighbouring mood is current.
double moodWordShift(int index, double t) =>
    index - _clamp01(t) * (kMoodSteps - 1);

/// Words fade as they slide away from the centre.
double moodWordOpacity(int index, double t) =>
    (1 - moodWordShift(index, t).abs() * 1.6).clamp(0.0, 1.0);

/// The three labels of [question]: its own when the backend sent three,
/// otherwise the standard ones.
List<String> moodLabelsFor(SurveyQuestion question) =>
    question.options.length == kMoodSteps ? question.options : kMoodLabels;

/// The stop [answer] stands for, or null when nothing is chosen yet.
int? moodSelectedIndex(List<String> labels, dynamic answer) {
  if (answer is! String) return null;
  final i = labels.indexOf(answer);
  return i < 0 ? null : i;
}

/// The panel fill at [t]: [surface] (the current theme's) with a faint wash
/// of the mood.
Color moodPanelAt(double t, {required Color surface}) => Color.alphaBlend(
      moodTintAt(t, dark: surface.computeLuminance() < 0.1)
          .withValues(alpha: kMoodPanelWash),
      surface,
    );
