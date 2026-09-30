import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/survey_question.dart';
import 'package:viewer_app/screens/survey/survey_widgets.dart';
import 'package:viewer_app/widgets/ui.dart';

/// Pumps [child] in the real app theme. [reduceMotion] emulates the OS
/// "reduce motion" setting.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool reduceMotion = false,
  double textScale = 1.0,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: app!,
      ),
      home: Scaffold(body: child),
    ),
  );
}

/// Emulates a small phone (iPhone SE 1st gen, 320 x 568 pt).
void _useSmallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(640, 1136);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

SurveyQuestion _q({
  bool required = true,
  QuestionType type = QuestionType.singleChoice,
}) =>
    SurveyQuestion(
      id: 7,
      campaignId: 1,
      prompt: 'Энэ реклам танд сонирхолтой санагдсан уу?',
      type: type,
      options: const ['Тийм', 'Дунд зэрэг', 'Үгүй'],
      required: required,
    );

void main() {
  group('optionLetter', () {
    test('starts with the Mongolian Cyrillic enumerators', () {
      expect(
        [for (var i = 0; i < 6; i++) optionLetter(i)],
        ['А', 'Б', 'В', 'Г', 'Д', 'Е'],
      );
    });

    test('last single letter is Я', () {
      expect(optionLetter(optionAlphabet.length - 1), 'Я');
    });

    test('continues spreadsheet-style past the last letter', () {
      final n = optionAlphabet.length;
      expect(optionLetter(n), 'АА');
      expect(optionLetter(n + 1), 'АБ');
      expect(optionLetter(2 * n - 1), 'АЯ');
      expect(optionLetter(2 * n), 'БА');
      expect(optionLetter(n * n + n - 1), 'ЯЯ');
      expect(optionLetter(n * n + n), 'ААА');
    });

    test('negative indexes clamp to the first letter', () {
      expect(optionLetter(-1), 'А');
      expect(optionLetter(-100), 'А');
    });

    test('labels are unique and never Latin', () {
      final labels = [for (var i = 0; i < 2000; i++) optionLetter(i)];
      expect(labels.toSet().length, labels.length);
      final latin = RegExp('[A-Za-z]');
      expect(labels.where(latin.hasMatch), isEmpty);
    });

    test('alphabet has no duplicates and skips non-initial letters', () {
      expect(optionAlphabet.toSet().length, optionAlphabet.length);
      for (final skipped in ['Ё', 'Й', 'Щ', 'Ъ', 'Ы', 'Ь']) {
        expect(optionAlphabet, isNot(contains(skipped)));
      }
    });
  });

  group('canAdvance', () {
    final required = _q();
    final optional = _q(required: false);

    final cases = <String, (Object?, bool, bool)>{
      // label: (answer, expected when required, expected when optional)
      'null': (null, false, true),
      'empty string': ('', false, true),
      'whitespace string': ('  \n\t ', false, true),
      'empty list': (<String>[], false, true),
      'string value': ('Тийм', true, true),
      'padded string value': ('  Тийм ', true, true),
      'list value': (<String>['Тийм'], true, true),
      'other object': (3, true, true),
    };

    cases.forEach((label, c) {
      final (answer, whenRequired, whenOptional) = c;
      test('required x $label -> $whenRequired', () {
        expect(canAdvance(required, answer), whenRequired);
      });
      test('optional x $label -> $whenOptional', () {
        expect(canAdvance(optional, answer), whenOptional);
      });
    });

    test('same rule for every question type', () {
      for (final type in QuestionType.values) {
        expect(canAdvance(_q(type: type), null), isFalse);
        expect(canAdvance(_q(type: type), ''), isFalse);
        expect(canAdvance(_q(type: type), 'x'), isTrue);
        expect(canAdvance(_q(type: type, required: false), null), isTrue);
      }
    });
  });

  group('labels', () {
    test('questionProgressLabel is 1-based', () {
      expect(questionProgressLabel(0, 3), 'Асуулт 1/3');
      expect(questionProgressLabel(1, 3), 'Асуулт 2/3');
      expect(questionProgressLabel(2, 3), 'Асуулт 3/3');
    });

    test('answerHintFor covers every type', () {
      expect(
        answerHintFor(QuestionType.multipleChoice),
        'Хэд хэдийг сонгож болно',
      );
      expect(answerHintFor(QuestionType.singleChoice), isNotEmpty);
      expect(answerHintFor(QuestionType.text), isNotEmpty);
    });

    test('characterCountLabel counts user-perceived characters', () {
      expect(characterCountLabel(''), '0 тэмдэгт');
      expect(characterCountLabel('Сайн'), '4 тэмдэгт');
      // A letter + combining mark is 2 UTF-16 code units but 1 character.
      expect(characterCountLabel('\u0435\u0308'), '1 тэмдэгт');
    });
  });

  group('OptionTile', () {
    testWidgets('tap fires onTap', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        OptionTile(
          label: 'Тийм',
          index: 0,
          selected: false,
          onTap: () => taps++,
        ),
      );
      await tester.tap(find.text('Тийм'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('shows the letter badge for single choice', (tester) async {
      await _pump(
        tester,
        OptionTile(label: 'Үгүй', index: 2, selected: false, onTap: () {}),
      );
      expect(find.text('В'), findsOneWidget);
      expect(find.byKey(OptionTile.checkKey), findsOneWidget);
    });

    testWidgets(
        'selected single choice shows the check and is announced '
        'as a checked radio', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        OptionTile(label: 'Тийм', index: 0, selected: true, onTap: () {}),
      );
      await tester.pumpAndSettle();

      final check = tester.widget<AnimatedOpacity>(
        find.byKey(OptionTile.checkKey),
      );
      expect(check.opacity, 1);
      expect(
        tester.getSemantics(find.byType(OptionTile)),
        isSemantics(
          label: 'Тийм',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('unselected single choice hides the check', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        OptionTile(label: 'Тийм', index: 0, selected: false, onTap: () {}),
      );
      await tester.pumpAndSettle();

      final check = tester.widget<AnimatedOpacity>(
        find.byKey(OptionTile.checkKey),
      );
      expect(check.opacity, 0);
      expect(
        tester.getSemantics(find.byType(OptionTile)),
        isSemantics(
          label: 'Тийм',
          hasCheckedState: true,
          isChecked: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('selected state animates and the border turns gold',
        (tester) async {
      var selected = false;
      await _pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => OptionTile(
            label: 'Тийм',
            index: 0,
            selected: selected,
            onTap: () => setState(() => selected = !selected),
          ),
        ),
      );

      Color borderColor() {
        final container = tester.widget<AnimatedContainer>(
          find
              .descendant(
                of: find.byType(OptionTile),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        );
        final deco = container.foregroundDecoration! as BoxDecoration;
        return (deco.border! as Border).top.color;
      }

      expect(borderColor(), AppColors.border);
      await tester.tap(find.text('Тийм'));
      await tester.pumpAndSettle();
      expect(selected, isTrue);
      expect(borderColor(), AppColors.primary);
      expect(
        tester.widget<AnimatedOpacity>(find.byKey(OptionTile.checkKey)).opacity,
        1,
      );
    });

    testWidgets(
        'multiple choice uses a checkbox badge, no letter, and is '
        'not a radio', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        OptionTile(
          label: 'Хааяа',
          index: 0,
          selected: true,
          multiple: true,
          onTap: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('А'), findsNothing);
      expect(find.byKey(OptionTile.checkKey), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(OptionTile)),
        isSemantics(
          label: 'Хааяа',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('long labels wrap without overflow on a small phone at 1.3x',
        (tester) async {
      _useSmallPhone(tester);
      await _pump(
        tester,
        Padding(
          padding: const EdgeInsets.all(20),
          child: OptionTile(
            label: 'Маш урт хариултын сонголт энэ бол бүр илүү урт текст '
                'олон мөрөнд хуваагдана',
            index: 30,
            selected: true,
            onTap: () {},
          ),
        ),
        textScale: 1.3,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('АБ'), findsOneWidget);
    });
  });

  group('QuestionHeading', () {
    testWidgets('required question: overline, prompt, hint, no tag',
        (tester) async {
      await _pump(tester, QuestionHeading(number: 2, question: _q()));
      expect(find.text('АСУУЛТ 2'), findsOneWidget);
      expect(
        find.text('Энэ реклам танд сонирхолтой санагдсан уу?'),
        findsOneWidget,
      );
      expect(
          find.text(answerHintFor(QuestionType.singleChoice)), findsOneWidget);
      expect(find.text(QuestionHeading.optionalLabel), findsNothing);
    });

    testWidgets('optional question shows the Заавал биш tag', (tester) async {
      await _pump(
        tester,
        QuestionHeading(
          number: 3,
          question: _q(required: false, type: QuestionType.multipleChoice),
        ),
      );
      expect(find.text('Заавал биш'), findsOneWidget);
      expect(find.text('Хэд хэдийг сонгож болно'), findsOneWidget);
    });
  });

  group('SurveyTextField', () {
    testWidgets('keeps the hint and counts characters live', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final changes = <String>[];
      await _pump(
        tester,
        Padding(
          padding: const EdgeInsets.all(20),
          child: SurveyTextField(
            controller: controller,
            onChanged: changes.add,
          ),
        ),
      );
      expect(find.text('Санал бодлоо бичээрэй...'), findsOneWidget);
      expect(find.text('0 тэмдэгт'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Сайн байна');
      await tester.pump();
      expect(find.text('10 тэмдэгт'), findsOneWidget);
      expect(changes.last, 'Сайн байна');
    });

    testWidgets('shows text restored from the controller', (tester) async {
      final controller = TextEditingController(text: 'Өмнөх хариулт');
      addTearDown(controller.dispose);
      await _pump(
        tester,
        SurveyTextField(controller: controller, onChanged: (_) {}),
      );
      expect(find.text('Өмнөх хариулт'), findsOneWidget);
      expect(find.text('13 тэмдэгт'), findsOneWidget);
    });
  });

  group('StepBackButton', () {
    testWidgets('is announced as Буцах and fires onPressed', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await _pump(
        tester,
        Center(child: StepBackButton(onPressed: () => taps++)),
      );
      expect(find.bySemanticsLabel('Буцах'), findsOneWidget);
      expect(
        tester.getSize(find.byType(StepBackButton)),
        const Size.square(StepBackButton.size),
      );
      await tester.tap(find.byType(StepBackButton));
      await tester.pumpAndSettle();
      expect(taps, 1);
      handle.dispose();
    });
  });

  group('SurveySkeleton', () {
    testWidgets('renders prompt + three option placeholders', (tester) async {
      await _pump(
        tester,
        const Padding(padding: EdgeInsets.all(20), child: SurveySkeleton()),
      );
      // Shimmer repeats forever: pump a fixed duration, never settle.
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      final optionBlocks = tester
          .widgetList<Skeleton>(find.byType(Skeleton))
          .where((s) => s.height == OptionTile.minHeight);
      expect(optionBlocks.length, 3);
    });
  });

  group('AdaptiveCtaButton.resolve', () {
    // 10 px per character keeps the arithmetic obvious.
    double measure(String s) => s.length * 10.0;
    const full = 'Илгээх ба урамшуулал авах'; // 25 chars -> 250 px
    const compact = 'Илгээх';

    (String, IconData?) resolve(double width, {IconData? icon}) =>
        AdaptiveCtaButton.resolve(
          label: full,
          compactLabel: compact,
          icon: icon,
          maxWidth: width,
          measure: measure,
        );

    test('keeps label and icon when both fit', () {
      // 250 + 28 icon + 44 padding + 2 margin = 324.
      expect(resolve(324, icon: Icons.send), (full, Icons.send));
    });

    test('drops the icon first', () {
      expect(resolve(323, icon: Icons.send), (full, null));
      expect(resolve(296, icon: Icons.send), (full, null));
    });

    test('falls back to the compact label when the label is cut off', () {
      expect(resolve(295), (compact, null));
      expect(resolve(120, icon: Icons.send), (compact, null));
    });

    test('without a compact label it keeps the full label', () {
      expect(
        AdaptiveCtaButton.resolve(
          label: full,
          compactLabel: null,
          icon: Icons.send,
          maxWidth: 100,
          measure: measure,
        ),
        (full, null),
      );
    });

    test('unbounded width keeps everything', () {
      expect(resolve(double.infinity, icon: Icons.send), (full, Icons.send));
    });
  });

  group('AdaptiveCtaButton', () {
    testWidgets('shows the full label when there is room', (tester) async {
      await _pump(
        tester,
        Center(
          child: SizedBox(
            width: 700,
            child: AdaptiveCtaButton(
              label: 'Илгээх ба урамшуулал авах',
              compactLabel: 'Илгээх',
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(find.text('Илгээх ба урамшуулал авах'), findsOneWidget);
    });

    testWidgets(
        'switches to the compact label but keeps the full '
        'semantics label when narrow', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await _pump(
        tester,
        Center(
          child: SizedBox(
            width: 150,
            child: AdaptiveCtaButton(
              label: 'Илгээх ба урамшуулал авах',
              compactLabel: 'Илгээх',
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      expect(find.text('Илгээх'), findsOneWidget);
      expect(find.text('Илгээх ба урамшуулал авах'), findsNothing);
      expect(
        find.bySemanticsLabel('Илгээх ба урамшуулал авах'),
        findsOneWidget,
      );
      await tester.tap(find.text('Илгээх'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('loading shows a spinner and ignores taps', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        Center(
          child: SizedBox(
            width: 300,
            child: AdaptiveCtaButton(
              label: 'Дараах',
              loading: true,
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(AdaptiveCtaButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 0);
    });

    test('measureLabelWidth grows with text scale', () {
      const style = TextStyle(fontSize: 16);
      final base = measureLabelWidth('Дараах', style);
      final scaled = measureLabelWidth(
        'Дараах',
        style,
        textScaler: const TextScaler.linear(1.3),
      );
      expect(base, greaterThan(0));
      expect(scaled, greaterThan(base));
    });
  });

  group('ScrollEdgeFade', () {
    test('stopsFor keeps the middle opaque', () {
      expect(ScrollEdgeFade.stopsFor(400, 12, 24), [0, 0.03, 0.94, 1]);
    });

    test('stopsFor stays ordered for tiny or empty boxes', () {
      for (final h in [0.0, 10.0, 30.0]) {
        final stops = ScrollEdgeFade.stopsFor(h, 12, 24);
        for (var i = 1; i < stops.length; i++) {
          expect(stops[i], greaterThanOrEqualTo(stops[i - 1]));
        }
        expect(stops.first, 0);
        expect(stops.last, 1);
      }
    });

    testWidgets('wraps its child in a mask', (tester) async {
      await _pump(
        tester,
        const ScrollEdgeFade(child: SizedBox(height: 200, width: 200)),
      );
      expect(find.byType(ShaderMask), findsOneWidget);
    });
  });

  group('RewardCelebration', () {
    testWidgets('counts up to the formatted reward and settles',
        (tester) async {
      await _pump(
        tester,
        SingleChildScrollView(
          child: RewardCelebration(reward: 700, onContinue: () {}),
        ),
      );
      // Mid count-up the final amount is not on screen yet.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('+700 ₮'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('+700 ₮'), findsOneWidget);
      expect(find.text(RewardCelebration.title), findsOneWidget);
      expect(find.text(RewardCelebration.subtitle), findsOneWidget);
      expect(find.byType(CoinIcon), findsOneWidget);
      // Confetti is gone once the burst has finished.
      expect(
        find.descendant(
          of: find.byType(ConfettiBurst),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('formats large rewards with grouping', (tester) async {
      await _pump(
        tester,
        SingleChildScrollView(
          child: RewardCelebration(reward: 12500, onContinue: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('+12,500 ₮'), findsOneWidget);
    });

    testWidgets('reduce-motion shows the final amount in the first frame',
        (tester) async {
      await _pump(
        tester,
        SingleChildScrollView(
          child: RewardCelebration(reward: 700, onContinue: () {}),
        ),
        reduceMotion: true,
      );
      expect(find.text('+700 ₮'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('continue button fires onContinue', (tester) async {
      var continued = 0;
      await _pump(
        tester,
        SingleChildScrollView(
          child: RewardCelebration(
            reward: 500,
            onContinue: () => continued++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(RewardCelebration.continueLabel));
      await tester.pumpAndSettle();
      expect(continued, 1);
    });

    testWidgets('fits a small phone at 1.3x text without overflow',
        (tester) async {
      _useSmallPhone(tester);
      await _pump(
        tester,
        SingleChildScrollView(
          child: RewardCelebration(reward: 1234567, onContinue: () {}),
        ),
        textScale: 1.3,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('+1,234,567 ₮'), findsOneWidget);
    });

    testWidgets('works inside a modal bottom sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isDismissible: false,
                    enableDrag: false,
                    isScrollControlled: true,
                    useSafeArea: true,
                    clipBehavior: Clip.none,
                    builder: (sheetContext) => SingleChildScrollView(
                      clipBehavior: Clip.none,
                      child: RewardCelebration(
                        reward: 700,
                        onContinue: () => Navigator.of(sheetContext).pop(),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('+700 ₮'), findsOneWidget);

      await tester.tap(find.text(RewardCelebration.continueLabel));
      await tester.pumpAndSettle();
      expect(find.byType(RewardCelebration), findsNothing);
    });
  });
}
