/// Pure maths and constants of the mood slider (no widgets, so it is unit
/// tested on its own). A slider position `t` runs 0..1 across the moods,
/// worst to best. A RATING question has five stops (owner, 2026-10-21:
/// Маш муу · Муу · Дунд · Сайн · Маш сайн); questions created before that
/// keep their three (Муу · Дунд · Сайн), so every helper takes the number of
/// [steps] the question has.
library;

import 'dart:ui';

import '../../models/survey_question.dart';
import '../../theme/app_theme.dart';

/// Stops of a RATING question created today.
const int kMoodSteps = 5;

/// Stops of a RATING question created before 2026-10-21.
const int kMoodLegacySteps = 3;

/// Answers of a RATING question when the backend sent none (it normally
/// sends exactly these; they mirror the backend's `RatingScale.LABELS`).
const List<String> kMoodLabels = ['Маш муу', 'Муу', 'Дунд', 'Сайн', 'Маш сайн'];

/// Where the thumb rests before the viewer has touched it (the middle stop).
const double kMoodStartPosition = 0.5;

/// The mood hues: deep red → coral → the brand's own gold → leaf → forest.
/// They colour only the face, the word and the slider; the panel stays the
/// app's own surface, so the question belongs to the rest of the app. Kept
/// apart from the brand palette because a red-to-green scale carries meaning.
abstract final class MoodColors {
  static const Color veryBad = Color(0xFF9E2B22);
  static const Color bad = Color(0xFFB83E31);
  static const Color mid = AppColors.warning;
  static const Color good = Color(0xFF2F7A4F);
  static const Color veryGood = Color(0xFF176445);

  /// Drawn on a mood-coloured surface (the thumb's mouth).
  static const Color ink = AppColors.background;
}

/// The same scale for the dark appearance: lighter, so it stays readable on
/// the graphite panel.
abstract final class MoodColorsDark {
  static const Color veryBad = Color(0xFFFF968A);
  static const Color bad = Color(0xFFFFB2A5);
  static const Color mid = Color(0xFFF0CE88);
  static const Color good = Color(0xFFB4DCC0);
  static Color get veryGood => const AppPalette(true).primary;
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
    this.browTilt = 0,
    this.mouthOpen = 0,
  });

  final double eyeWidth;
  final double eyeHeight;
  final double mouthWidth;

  /// How far the middle of the mouth sits below its ends; negative = frown.
  final double mouthSag;

  /// Worried brows over the eyes (inner ends raised), 0 = none, 1 = full.
  final double browTilt;

  /// How much of the smile is filled in as an open laugh, 0..1.
  final double mouthOpen;

  @override
  bool operator ==(Object other) =>
      other is MoodShape &&
      other.eyeWidth == eyeWidth &&
      other.eyeHeight == eyeHeight &&
      other.mouthWidth == mouthWidth &&
      other.mouthSag == mouthSag &&
      other.browTilt == browTilt &&
      other.mouthOpen == mouthOpen;

  @override
  int get hashCode => Object.hash(
      eyeWidth, eyeHeight, mouthWidth, mouthSag, browTilt, mouthOpen);

  static MoodShape lerp(MoodShape a, MoodShape b, double t) => MoodShape(
        eyeWidth: lerpDouble(a.eyeWidth, b.eyeWidth, t)!,
        eyeHeight: lerpDouble(a.eyeHeight, b.eyeHeight, t)!,
        mouthWidth: lerpDouble(a.mouthWidth, b.mouthWidth, t)!,
        mouthSag: lerpDouble(a.mouthSag, b.mouthSag, t)!,
        browTilt: lerpDouble(a.browTilt, b.browTilt, t)!,
        mouthOpen: lerpDouble(a.mouthOpen, b.mouthOpen, t)!,
      );
}

/// Маш муу: small eyes under worried brows, a deep frown.
const MoodShape kVeryBadFace = MoodShape(
  eyeWidth: 0.16,
  eyeHeight: 0.16,
  mouthWidth: 0.30,
  mouthSag: -0.19,
  browTilt: 1,
);

/// Муу: round eyes, a frown.
const MoodShape kBadFace = MoodShape(
  eyeWidth: 0.19,
  eyeHeight: 0.19,
  mouthWidth: 0.26,
  mouthSag: -0.13,
);

/// Дунд: flat pill eyes, an almost straight mouth.
const MoodShape kMidFace = MoodShape(
  eyeWidth: 0.30,
  eyeHeight: 0.11,
  mouthWidth: 0.20,
  mouthSag: -0.05,
);

/// Сайн: round eyes, a smile.
const MoodShape kGoodFace = MoodShape(
  eyeWidth: 0.26,
  eyeHeight: 0.24,
  mouthWidth: 0.26,
  mouthSag: 0.10,
);

/// Маш сайн: big eyes, a wide open laugh.
const MoodShape kVeryGoodFace = MoodShape(
  eyeWidth: 0.30,
  eyeHeight: 0.30,
  mouthWidth: 0.34,
  mouthSag: 0.17,
  mouthOpen: 1,
);

/// The best face of a three-stop scale, exactly as before 2026-10-21.
const MoodShape kLegacyGoodFace = MoodShape(
  eyeWidth: 0.30,
  eyeHeight: 0.30,
  mouthWidth: 0.28,
  mouthSag: 0.15,
);

/// The faces of a [steps]-stop scale, worst to best. Three stops keep the
/// faces they always had.
List<MoodShape> moodFacesFor(int steps) => steps == kMoodLegacySteps
    ? const [kBadFace, kMidFace, kLegacyGoodFace]
    : const [kVeryBadFace, kBadFace, kMidFace, kGoodFace, kVeryGoodFace];

/// The hues of a [steps]-stop scale, worst to best.
List<Color> moodHuesFor(int steps, {bool dark = false}) {
  if (steps == kMoodLegacySteps) {
    return dark
        ? [MoodColorsDark.bad, MoodColorsDark.mid, MoodColorsDark.veryGood]
        : const [MoodColors.bad, MoodColors.mid, MoodColors.veryGood];
  }
  return dark
      ? [
          MoodColorsDark.veryBad,
          MoodColorsDark.bad,
          MoodColorsDark.mid,
          MoodColorsDark.good,
          MoodColorsDark.veryGood,
        ]
      : const [
          MoodColors.veryBad,
          MoodColors.bad,
          MoodColors.mid,
          MoodColors.good,
          MoodColors.veryGood,
        ];
}

double _clamp01(double t) => t.clamp(0.0, 1.0);

/// Interpolates through evenly spaced [keys]: between neighbouring keys the
/// value is blended by how far [t] has travelled from one to the next.
T _across<T>(double t, List<T> keys, T Function(T, T, double) blend) {
  final scaled = _clamp01(t) * (keys.length - 1);
  final i = scaled.floor().clamp(0, keys.length - 2);
  return blend(keys[i], keys[i + 1], scaled - i);
}

/// Eyes, brows and mouth at [t]; their positions never change, only these
/// sizes.
MoodShape moodShapeAt(double t, {int steps = kMoodSteps}) =>
    _across(t, moodFacesFor(steps), MoodShape.lerp);

/// Mood colour at [t], blended so it drifts while the thumb is dragged.
Color moodTintAt(double t, {bool dark = false, int steps = kMoodSteps}) =>
    _across(
        t, moodHuesFor(steps, dark: dark), (a, b, p) => Color.lerp(a, b, p)!);

/// The stop (0..[steps]-1) nearest to [t].
int moodIndexFor(double t, {int steps = kMoodSteps}) =>
    (_clamp01(t) * (steps - 1)).round();

/// Position of stop [index].
double moodPositionOf(int index, {int steps = kMoodSteps}) =>
    index / (steps - 1);

/// Slider position for a finger at [dx] along a track of [width].
double positionFromDrag(double dx, double width) =>
    width <= 0 ? kMoodStartPosition : _clamp01(dx / width);

/// How far word [index] sits from the centre, in word-widths: 0 when it is
/// the current mood, ±1 when the neighbouring mood is current.
double moodWordShift(int index, double t, {int steps = kMoodSteps}) =>
    index - _clamp01(t) * (steps - 1);

/// Words fade as they slide away from the centre.
double moodWordOpacity(int index, double t, {int steps = kMoodSteps}) =>
    (1 - moodWordShift(index, t, steps: steps).abs() * 1.6).clamp(0.0, 1.0);

/// The labels of [question]: its own when the backend sent a five-stop (or an
/// older three-stop) scale, otherwise the standard five.
List<String> moodLabelsFor(SurveyQuestion question) {
  final n = question.options.length;
  return n == kMoodSteps || n == kMoodLegacySteps
      ? question.options
      : kMoodLabels;
}

/// The stop [answer] stands for, or null when nothing is chosen yet.
int? moodSelectedIndex(List<String> labels, dynamic answer) {
  if (answer is! String) return null;
  final i = labels.indexOf(answer);
  return i < 0 ? null : i;
}

/// The panel fill at [t]: [surface] (the current theme's) with a faint wash
/// of the mood.
Color moodPanelAt(double t, {required Color surface, int steps = kMoodSteps}) =>
    Color.alphaBlend(
      moodTintAt(t, dark: surface.computeLuminance() < 0.1, steps: steps)
          .withValues(alpha: kMoodPanelWash),
      surface,
    );
