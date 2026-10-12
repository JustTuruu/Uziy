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

void main() {
  group('moodShapeAt', () {
    test(
        'eyes are round when bad, flat pills when so-so, big circles when good',
        () {
      final bad = moodShapeAt(0);
      final mid = moodShapeAt(0.5);
      final good = moodShapeAt(1);

      expect(bad.eyeWidth, bad.eyeHeight);
      expect(mid.eyeWidth, greaterThan(mid.eyeHeight * 2));
      expect(good.eyeWidth, good.eyeHeight);
      expect(good.eyeHeight, greaterThan(bad.eyeHeight));
    });

    test('the mouth goes from a frown through flat-ish to a smile', () {
      expect(moodShapeAt(0).mouthSag, isNegative);
      expect(moodShapeAt(0.5).mouthSag, greaterThan(moodShapeAt(0).mouthSag));
      expect(moodShapeAt(1).mouthSag, isPositive);
    });

    test('changes smoothly: halfway between two stops is halfway in shape', () {
      final a = moodShapeAt(0);
      final m = moodShapeAt(0.5);
      final quarter = moodShapeAt(0.25);

      expect(quarter.eyeHeight, closeTo((a.eyeHeight + m.eyeHeight) / 2, 1e-9));
    });

    test('positions outside 0..1 behave like the ends', () {
      expect(moodShapeAt(-3).eyeWidth, moodShapeAt(0).eyeWidth);
      expect(moodShapeAt(7).mouthSag, moodShapeAt(1).mouthSag);
    });
  });

  group('moodTintAt', () {
    test('hits the three mood colours at the stops', () {
      expect(moodTintAt(0), MoodColors.bad);
      expect(moodTintAt(0.5), MoodColors.mid);
      expect(moodTintAt(1), MoodColors.good);
    });

    test('blends in between', () {
      expect(moodTintAt(0.25), Color.lerp(MoodColors.bad, MoodColors.mid, 0.5));
    });
  });

  group('moodPanelAt', () {
    test(
        'stays a dark surface: only a faint wash of the mood on the app surface',
        () {
      for (final t in [0.0, 0.5, 1.0]) {
        final panel = moodPanelAt(t);
        expect(panel.computeLuminance(), lessThan(0.12));
      }
      expect(
        moodPanelAt(0.5),
        Color.alphaBlend(
          MoodColors.mid.withValues(alpha: kMoodPanelWash),
          AppColors.surface,
        ),
      );
    });

    test('still follows the mood', () {
      expect(moodPanelAt(0), isNot(moodPanelAt(1)));
      expect(moodPanelAt(0.5), isNot(AppColors.surface));
    });
  });

  test('the middle mood is the brand gold', () {
    expect(MoodColors.mid, AppColors.primary);
  });

  group('stops', () {
    test('moodIndexFor picks the nearest stop', () {
      expect(moodIndexFor(0), 0);
      expect(moodIndexFor(0.24), 0);
      expect(moodIndexFor(0.26), 1);
      expect(moodIndexFor(0.74), 1);
      expect(moodIndexFor(0.76), 2);
      expect(moodIndexFor(1), 2);
      expect(moodIndexFor(5), 2);
      expect(moodIndexFor(-5), 0);
    });

    test('moodPositionOf is the inverse of moodIndexFor', () {
      for (var i = 0; i < kMoodSteps; i++) {
        expect(moodIndexFor(moodPositionOf(i)), i);
      }
    });
  });

  group('positionFromDrag', () {
    test('maps the finger along the track and clamps to the ends', () {
      expect(positionFromDrag(50, 200), 0.25);
      expect(positionFromDrag(-20, 200), 0);
      expect(positionFromDrag(900, 200), 1);
    });

    test('a track with no width rests in the middle', () {
      expect(positionFromDrag(10, 0), kMoodStartPosition);
    });
  });

  group('word carousel', () {
    test(
        'the current word is centred and opaque, neighbours sit one width away',
        () {
      expect(moodWordShift(1, 0.5), 0);
      expect(moodWordOpacity(1, 0.5), 1);
      expect(moodWordShift(0, 0.5), -1);
      expect(moodWordShift(2, 0.5), 1);
      expect(moodWordOpacity(0, 0.5), 0);
    });

    test('words slide left as the thumb moves right', () {
      expect(moodWordShift(1, 0.75), lessThan(moodWordShift(1, 0.5)));
      expect(moodWordShift(2, 1), 0);
    });

    test('a word fades out while it leaves the centre', () {
      expect(moodWordOpacity(1, 0.6), lessThan(1));
      expect(moodWordOpacity(1, 0.6), greaterThan(0));
    });
  });

  group('labels', () {
    test('uses the question\'s own three labels', () {
      expect(moodLabelsFor(_rating(['A', 'B', 'C'])), ['A', 'B', 'C']);
    });

    test(
        'falls back to Муу / Дунд / Сайн when the backend sent none or odd counts',
        () {
      expect(moodLabelsFor(_rating([])), kMoodLabels);
      expect(moodLabelsFor(_rating(['A', 'B'])), kMoodLabels);
    });

    test('moodSelectedIndex finds the stop of a stored answer', () {
      expect(moodSelectedIndex(kMoodLabels, 'Сайн'), 2);
      expect(moodSelectedIndex(kMoodLabels, 'Муу'), 0);
    });

    test('moodSelectedIndex is null for no, unknown or non-text answers', () {
      expect(moodSelectedIndex(kMoodLabels, null), isNull);
      expect(moodSelectedIndex(kMoodLabels, 'Маш сайн'), isNull);
      expect(moodSelectedIndex(kMoodLabels, 2), isNull);
    });
  });
}
