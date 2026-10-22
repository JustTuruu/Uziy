import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/survey_question.dart';
import 'package:viewer_app/screens/survey/mood_logic.dart';
import 'package:viewer_app/theme/app_theme.dart';

SurveyQuestion _rating(List<String> options) => SurveyQuestion(
      id: 1,
      campaignId: 1,
      prompt: 'p',
      type: QuestionType.rating,
      options: options,
    );

const _legacy = kMoodLegacySteps;

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('the five-stop scale (owner, 2026-10-21)', () {
    test('labels run Маш муу → Маш сайн', () {
      expect(kMoodSteps, 5);
      expect(kMoodLabels, ['Маш муу', 'Муу', 'Дунд', 'Сайн', 'Маш сайн']);
    });

    test('each stop has its own face', () {
      final faces = [for (var i = 0; i < 5; i++) moodShapeAt(i / 4)];
      expect(faces[0], equals(kVeryBadFace));
      expect(faces[1], equals(kBadFace));
      expect(faces[2], equals(kMidFace));
      expect(faces[3], equals(kGoodFace));
      expect(faces[4], equals(kVeryGoodFace));
    });

    test('the mouth only climbs from the deepest frown to the widest laugh',
        () {
      final sags = [for (var i = 0; i < 5; i++) moodShapeAt(i / 4).mouthSag];
      for (var i = 1; i < sags.length; i++) {
        expect(sags[i], greaterThan(sags[i - 1]));
      }
      expect(sags.first, isNegative);
      expect(sags.last, isPositive);
    });

    test('Маш муу alone has worried brows, Маш сайн alone an open laugh', () {
      final faces = [for (var i = 0; i < 5; i++) moodShapeAt(i / 4)];
      expect(
          faces.map((f) => f.browTilt > 0), [true, false, false, false, false]);
      expect(faces.map((f) => f.mouthOpen > 0),
          [false, false, false, false, true]);
    });

    test('Дунд keeps the flat pill eyes; the ends have round ones', () {
      final mid = moodShapeAt(0.5);
      expect(mid.eyeWidth, greaterThan(mid.eyeHeight * 2));
      expect(moodShapeAt(0).eyeWidth, moodShapeAt(0).eyeHeight);
      expect(moodShapeAt(1).eyeWidth, moodShapeAt(1).eyeHeight);
    });

    test('hues hit each stop, red to green', () {
      expect(moodTintAt(0), MoodColors.veryBad);
      expect(moodTintAt(0.25), MoodColors.bad);
      expect(moodTintAt(0.5), MoodColors.mid);
      expect(moodTintAt(0.75), MoodColors.good);
      expect(moodTintAt(1), MoodColors.veryGood);
      expect(moodTintAt(0.125),
          Color.lerp(MoodColors.veryBad, MoodColors.bad, 0.5));
    });

    test('every mood colour reads on its panel in both themes (AA)', () {
      for (final dark in [false, true]) {
        final surface = AppPalette(dark).surface;
        for (var i = 0; i < 5; i++) {
          final t = i / 4;
          expect(
            _contrast(
                moodTintAt(t, dark: dark), moodPanelAt(t, surface: surface)),
            greaterThanOrEqualTo(4.5),
            reason: 'stop $i, dark: $dark',
          );
        }
      }
    });

    test('stops: nearest index, and positions round-trip', () {
      expect(moodIndexFor(0.1), 0);
      expect(moodIndexFor(0.2), 1);
      expect(moodIndexFor(0.5), 2);
      expect(moodIndexFor(0.8), 3);
      expect(moodIndexFor(0.95), 4);
      for (var i = 0; i < 5; i++) {
        expect(moodIndexFor(moodPositionOf(i)), i);
      }
      expect(moodPositionOf(1), 0.25);
    });

    test('word carousel: the current word is centred, neighbours one away', () {
      expect(moodWordShift(2, 0.5), 0);
      expect(moodWordShift(1, 0.5), -1);
      expect(moodWordShift(3, 0.5), 1);
      expect(moodWordOpacity(2, 0.5), 1);
      expect(moodWordOpacity(0, 0.5), 0);
      expect(moodWordShift(4, 1), 0);
    });
  });

  group('a question from before 2026-10-21 keeps its three stops', () {
    test('faces and hues are exactly the old three', () {
      expect(moodShapeAt(0, steps: _legacy), equals(kBadFace));
      expect(moodShapeAt(0.5, steps: _legacy), equals(kMidFace));
      expect(moodShapeAt(1, steps: _legacy), equals(kLegacyGoodFace));
      expect(moodTintAt(0, steps: _legacy), MoodColors.bad);
      expect(moodTintAt(0.5, steps: _legacy), MoodColors.mid);
      expect(moodTintAt(1, steps: _legacy), MoodColors.veryGood);
      expect(moodShapeAt(0.25, steps: _legacy).eyeHeight,
          closeTo((kBadFace.eyeHeight + kMidFace.eyeHeight) / 2, 1e-9));
    });

    test('stops are the old 0 / 0.5 / 1', () {
      expect(moodIndexFor(0.24, steps: _legacy), 0);
      expect(moodIndexFor(0.26, steps: _legacy), 1);
      expect(moodIndexFor(0.76, steps: _legacy), 2);
      expect(moodPositionOf(1, steps: _legacy), 0.5);
      expect(moodWordShift(2, 1, steps: _legacy), 0);
    });
  });

  group('shared', () {
    test('positions outside 0..1 behave like the ends', () {
      expect(moodShapeAt(-3).eyeWidth, moodShapeAt(0).eyeWidth);
      expect(moodShapeAt(7).mouthSag, moodShapeAt(1).mouthSag);
      expect(moodIndexFor(5), 4);
      expect(moodIndexFor(-5), 0);
    });

    test('the middle mood is the brand gold', () {
      expect(MoodColors.mid, AppColors.warning);
    });

    test('the panel is the app surface with only a faint wash', () {
      for (final t in [0.0, 0.5, 1.0]) {
        expect(moodPanelAt(t, surface: AppColors.surface).computeLuminance(),
            greaterThan(0.7));
        expect(
            moodPanelAt(t, surface: const AppPalette(true).surface)
                .computeLuminance(),
            lessThan(0.1));
      }
      expect(
        moodPanelAt(0.5, surface: AppColors.surface),
        Color.alphaBlend(MoodColors.mid.withValues(alpha: kMoodPanelWash),
            AppColors.surface),
      );
    });

    test('positionFromDrag maps the finger and clamps', () {
      expect(positionFromDrag(50, 200), 0.25);
      expect(positionFromDrag(-20, 200), 0);
      expect(positionFromDrag(900, 200), 1);
      expect(positionFromDrag(10, 0), kMoodStartPosition);
    });
  });

  group('labels', () {
    test("uses the question's own five, or an older question's three", () {
      const five = ['1', '2', '3', '4', '5'];
      expect(moodLabelsFor(_rating(five)), five);
      expect(moodLabelsFor(_rating(['A', 'B', 'C'])), ['A', 'B', 'C']);
    });

    test('falls back to the standard five for none or odd counts', () {
      expect(moodLabelsFor(_rating([])), kMoodLabels);
      expect(moodLabelsFor(_rating(['A', 'B'])), kMoodLabels);
      expect(moodLabelsFor(_rating(['A', 'B', 'C', 'D'])), kMoodLabels);
    });

    test('moodSelectedIndex finds the stop of a stored answer', () {
      expect(moodSelectedIndex(kMoodLabels, 'Маш сайн'), 4);
      expect(moodSelectedIndex(kMoodLabels, 'Муу'), 1);
      expect(moodSelectedIndex(kMoodLabels, null), isNull);
      expect(moodSelectedIndex(kMoodLabels, 'Гайхалтай'), isNull);
      expect(moodSelectedIndex(kMoodLabels, 2), isNull);
    });
  });
}
