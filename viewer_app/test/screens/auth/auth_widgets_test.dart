import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/screens/auth/auth_widgets.dart';
import 'package:viewer_app/widgets/ui.dart';

/// Pumps [child] in the real app theme at a phone-sized viewport.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double textScale = 1.0,
  bool reduceMotion = false,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = Size(width * 3, 844 * 3);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
        ),
        child: app!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('AuthValidators', () {
    test('phone must be exactly 8 characters', () {
      const msg = 'bad';
      expect(AuthValidators.phone(null, message: msg), msg);
      expect(AuthValidators.phone('', message: msg), msg);
      expect(AuthValidators.phone('8877889', message: msg), msg);
      expect(AuthValidators.phone('887788990', message: msg), msg);
      expect(AuthValidators.phone('88778899', message: msg), isNull);
      // The typing group of BigPhoneField does not count as a character.
      expect(AuthValidators.phone('8877 8899', message: msg), isNull);
      expect(AuthValidators.phone('8877 889', message: msg), msg);
    });

    test('password needs at least 6 characters', () {
      expect(AuthValidators.password(null), 'Дор хаяж 6 тэмдэгт');
      expect(AuthValidators.password('12345'), 'Дор хаяж 6 тэмдэгт');
      expect(AuthValidators.password('123456'), isNull);
      expect(AuthValidators.password('a much longer one'), isNull);
    });
  });

  test('phoneDigits strips everything but digits', () {
    expect(phoneDigits(null), '');
    expect(phoneDigits('88778899'), '88778899');
    expect(phoneDigits('8877 8899'), '88778899');
    expect(phoneDigits('+976 8877-8899'), '97688778899');
  });

  group('birth date helpers', () {
    test('formatBirthDate uses yyyy.MM.dd with zero padding', () {
      expect(formatBirthDate(DateTime(2001, 3, 9)), '2001.03.09');
      expect(formatBirthDate(DateTime(1990, 12, 31)), '1990.12.31');
    });

    test('ageInYears counts only reached birthdays', () {
      final now = DateTime(2026, 9, 28);
      expect(ageInYears(DateTime(2000, 9, 28), now), 26); // birthday today
      expect(ageInYears(DateTime(2000, 9, 29), now), 25); // tomorrow
      expect(ageInYears(DateTime(2000, 10, 1), now), 25); // next month
      expect(ageInYears(DateTime(2000, 1, 15), now), 26); // earlier this year
      // Feb 29 birthday on Feb 28 of a non-leap year: not reached yet.
      expect(ageInYears(DateTime(2004, 2, 29), DateTime(2027, 2, 28)), 22);
      expect(ageInYears(DateTime(2004, 2, 29), DateTime(2027, 3, 1)), 23);
    });

    test('picker bounds keep the min age 13 / max 80 / open at 20 rule', () {
      final b = birthDatePickerBounds(DateTime(2026, 9, 28));
      expect(b.initial, DateTime(2006, 9, 28));
      expect(b.first, DateTime(1946));
      expect(b.last, DateTime(2013));
    });

    test('picker reopens at the chosen date only when still in range', () {
      final now = DateTime(2026, 9, 28);
      final def = birthDatePickerBounds(now).initial;
      expect(birthDatePickerInitial(null, now), def);
      expect(
        birthDatePickerInitial(DateTime(1999, 5, 4), now),
        DateTime(1999, 5, 4),
      );
      // Too young (after lastDate) or too old (before firstDate).
      expect(birthDatePickerInitial(DateTime(2013, 6, 1), now), def);
      expect(birthDatePickerInitial(DateTime(1940, 1, 1), now), def);
      // Bounds themselves are allowed.
      expect(birthDatePickerInitial(DateTime(2013), now), DateTime(2013));
      expect(birthDatePickerInitial(DateTime(1946), now), DateTime(1946));
    });
  });

  group('BigPhoneField', () {
    List<PhoneDigitSlot> slots(WidgetTester tester) =>
        tester.widgetList<PhoneDigitSlot>(find.byType(PhoneDigitSlot)).toList();
    List<String?> digits(WidgetTester tester) =>
        slots(tester).map((s) => s.digit).toList();
    List<int> activeSlots(WidgetTester tester) => [
          for (final (i, s) in slots(tester).indexed)
            if (s.active) i,
        ];

    testWidgets('shows +976 and one empty slot per digit', (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      await _pump(tester, BigPhoneField(controller: ctrl));

      expect(find.text(BigPhoneField.countryCode), findsOneWidget);
      expect(slots(tester), hasLength(AuthValidators.phoneLength));
      expect(digits(tester), everyElement(isNull));
      expect(activeSlots(tester), isEmpty);
      expect(slots(tester).any((s) => s.error), isFalse);
    });

    testWidgets('the hidden input is numeric, caret-less and not selectable',
        (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      await _pump(tester, BigPhoneField(controller: ctrl));

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.number);
      expect(field.showCursor, isFalse);
      expect(field.enableInteractiveSelection, isFalse);
      expect(field.autofillHints, BigPhoneField.defaultAutofillHints);
    });

    testWidgets('typed digits fill the slots in order', (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      await _pump(tester, BigPhoneField(controller: ctrl));

      await tester.enterText(find.byType(TextField), '9911');
      await tester.pump();
      expect(ctrl.text, '9911');
      expect(digits(tester), ['9', '9', '1', '1', null, null, null, null]);
    });

    testWidgets('keeps only digits, and only 8 of them', (tester) async {
      final ctrl = TextEditingController();
      final changes = <String>[];
      addTearDown(ctrl.dispose);
      await _pump(
        tester,
        BigPhoneField(controller: ctrl, onChanged: changes.add),
      );

      await tester.enterText(find.byType(TextField), '99a11-223344');
      await tester.pump();
      expect(ctrl.text, '99112233');
      expect(changes, ['99112233']);
      expect(digits(tester), ['9', '9', '1', '1', '2', '2', '3', '3']);
    });

    testWidgets('the gap after the fourth slot is the wider group gap',
        (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      // Wide enough that the row is not shrunk to fit.
      await _pump(tester, BigPhoneField(controller: ctrl), width: 600);

      final slot = find.byType(PhoneDigitSlot);
      double gap(int i) =>
          tester.getTopLeft(slot.at(i + 1)).dx -
          tester.getTopRight(slot.at(i)).dx;
      expect(gap(0), moreOrLessEquals(BigPhoneField.slotGap));
      expect(gap(3), moreOrLessEquals(BigPhoneField.groupGap));
      expect(gap(4), moreOrLessEquals(BigPhoneField.slotGap));
    });

    testWidgets('only the slot being typed into is active, and only on focus',
        (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      await _pump(tester, BigPhoneField(controller: ctrl));
      expect(activeSlots(tester), isEmpty);

      await tester.tap(find.byType(BigPhoneField));
      await tester.pump();
      expect(activeSlots(tester), [0]);

      await tester.enterText(find.byType(TextField), '991');
      await tester.pump();
      expect(activeSlots(tester), [3]);

      // After the last digit the highlight stays on the last slot.
      await tester.enterText(find.byType(TextField), '99112233');
      await tester.pump();
      expect(activeSlots(tester), [7]);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(activeSlots(tester), isEmpty);
    });

    testWidgets('a failed validation shows the message and reddens the slots',
        (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      final formKey = GlobalKey<FormState>();
      await _pump(
        tester,
        Form(
          key: formKey,
          child: BigPhoneField(
            controller: ctrl,
            validator: (v) =>
                AuthValidators.phone(v, message: '8 оронтой утасны дугаар'),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '8811');
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('8 оронтой утасны дугаар'), findsOneWidget);
      expect(slots(tester).every((s) => s.error), isTrue);

      await tester.enterText(find.byType(TextField), '99112233');
      expect(formKey.currentState!.validate(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('8 оронтой утасны дугаар'), findsNothing);
      expect(slots(tester).any((s) => s.error), isFalse);
    });

    testWidgets('a number set on the controller reaches slots and validator',
        (tester) async {
      final ctrl = TextEditingController(text: '8811');
      addTearDown(ctrl.dispose);
      final formKey = GlobalKey<FormState>();
      await _pump(
        tester,
        Form(
          key: formKey,
          child: BigPhoneField(
            controller: ctrl,
            validator: (v) => AuthValidators.phone(v, message: 'bad'),
          ),
        ),
      );
      expect(digits(tester).take(4), ['8', '8', '1', '1']);
      expect(formKey.currentState!.validate(), isFalse);

      ctrl.text = '88112233';
      await tester.pumpAndSettle();
      expect(digits(tester), ['8', '8', '1', '1', '2', '2', '3', '3']);
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('shrinks to fit a narrow column instead of overflowing',
        (tester) async {
      final ctrl = TextEditingController(text: '88778899');
      addTearDown(ctrl.dispose);
      await _pump(
        tester,
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: 200, child: BigPhoneField(controller: ctrl)),
        ),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopRight(find.byType(PhoneDigitSlot).last).dx,
        lessThanOrEqualTo(
          tester.getTopRight(find.byType(BigPhoneField)).dx + 0.5,
        ),
      );
    });
  });

  group('PhoneDigitSlot', () {
    test('line colour: error beats active beats resting', () {
      expect(
        PhoneDigitSlot.lineColor(active: false, error: false),
        PhoneDigitSlot.restingLineColor,
      );
      expect(
        PhoneDigitSlot.lineColor(active: true, error: false),
        AppColors.primary,
      );
      expect(
        PhoneDigitSlot.lineColor(active: true, error: true),
        AppColors.danger,
      );
      expect(
        PhoneDigitSlot.lineColor(active: false, error: true),
        AppColors.danger,
      );
    });

    testWidgets('an empty slot is as tall as a filled one', (tester) async {
      await _pump(
        tester,
        const Row(
          children: [
            PhoneDigitSlot(
              key: ValueKey('empty'),
              digit: null,
              active: false,
              error: false,
            ),
            PhoneDigitSlot(
              key: ValueKey('filled'),
              digit: '8',
              active: true,
              error: false,
            ),
          ],
        ),
      );
      expect(find.text('8'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('empty'))),
        tester.getSize(find.byKey(const ValueKey('filled'))),
      );
    });
  });

  group('InlineFieldError', () {
    Widget host(bool show) => InlineFieldError(show: show, message: 'алдаа');

    testWidgets('grows in when shown and takes no height when hidden',
        (tester) async {
      await _pump(tester, host(false));
      expect(find.text('алдаа'), findsNothing);
      expect(tester.getSize(find.byType(InlineFieldError)).height, 0);

      await _pump(tester, host(true));
      await tester.pumpAndSettle();
      expect(find.text('алдаа'), findsOneWidget);
      expect(
        tester.getSize(find.byType(InlineFieldError)).height,
        greaterThan(0),
      );
    });

    testWidgets('reduce motion: appears at once and does not throw',
        (tester) async {
      await _pump(tester, host(false), reduceMotion: true);
      await _pump(tester, host(true), reduceMotion: true);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedSize), findsNothing);
      expect(find.text('алдаа'), findsOneWidget);
    });
  });

  group('FieldError', () {
    testWidgets('flush drops the side inset of the boxed-field variant',
        (tester) async {
      await _pump(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FieldError('boxed', key: ValueKey('boxed')),
            FieldError('flush', key: ValueKey('flush'), flush: true),
          ],
        ),
      );
      final column = tester.getTopLeft(find.byType(Column)).dx;
      expect(tester.getTopLeft(find.text('flush')).dx, column);
      expect(tester.getTopLeft(find.text('boxed')).dx, greaterThan(column));
    });
  });

  group('PhoneNumberSection', () {
    testWidgets('shows the heading, the helper line and the big field',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      await _pump(tester, PhoneNumberSection(controller: ctrl));

      expect(find.text(PhoneNumberSection.title), findsOneWidget);
      expect(find.text(PhoneNumberSection.helper), findsOneWidget);
      expect(find.byType(BigPhoneField), findsOneWidget);
      expect(
        tester.getSemantics(find.text(PhoneNumberSection.title)),
        isSemantics(isHeader: true),
      );
      semantics.dispose();
    });

    testWidgets('passes the controller and validator through', (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      final formKey = GlobalKey<FormState>();
      var submitted = '';
      await _pump(
        tester,
        Form(
          key: formKey,
          child: PhoneNumberSection(
            controller: ctrl,
            onFieldSubmitted: (v) => submitted = v,
            validator: (v) => AuthValidators.phone(v, message: 'bad'),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '88112233');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(ctrl.text, '88112233');
      expect(submitted, '88112233');
      expect(formKey.currentState!.validate(), isTrue);
    });
  });

  testWidgets('the password field opens the ordinary text keyboard',
      (tester) async {
    await _pump(
      tester,
      PasswordField(controller: TextEditingController()),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.text);
    expect(field.obscureText, isTrue);
  });

  group('PasswordField', () {
    testWidgets('is obscured until the toggle is tapped', (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      final semantics = tester.ensureSemantics();
      await _pump(tester, PasswordField(controller: ctrl));

      bool obscured() =>
          tester.widget<EditableText>(find.byType(EditableText)).obscureText;

      expect(obscured(), isTrue);
      expect(find.bySemanticsLabel(PasswordField.showLabel), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();
      expect(obscured(), isFalse);
      expect(find.bySemanticsLabel(PasswordField.hideLabel), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(obscured(), isTrue);
      semantics.dispose();
    });

    testWidgets('toggle has a 44pt tap target', (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      await _pump(tester, PasswordField(controller: ctrl));
      final size = tester.getSize(find.byType(AppIconButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  group('GenderOptionCard', () {
    double badgeScale(WidgetTester tester) => tester
        .widget<AnimatedScale>(find.byKey(GenderOptionCard.checkBadgeKey))
        .scale;

    testWidgets('tap fires onTap', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        GenderOptionCard(
          label: 'Эрэгтэй',
          icon: Icons.male_rounded,
          selected: false,
          onTap: () => taps++,
        ),
      );
      await tester.tap(find.text('Эрэгтэй'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('selected state shows the check badge and semantics',
        (tester) async {
      final semantics = tester.ensureSemantics();
      Widget card(bool selected) => GenderOptionCard(
            label: 'Эмэгтэй',
            icon: Icons.female_rounded,
            selected: selected,
            onTap: () {},
          );

      await _pump(tester, card(false));
      expect(badgeScale(tester), 0);
      expect(
        tester.getSemantics(find.byType(GenderOptionCard)),
        isSemantics(
          label: 'Эмэгтэй',
          isButton: true,
          isSelected: false,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );

      await _pump(tester, card(true));
      await tester.pumpAndSettle();
      expect(badgeScale(tester), 1);
      expect(
        tester.getSemantics(find.byType(GenderOptionCard)),
        isSemantics(label: 'Эмэгтэй', isSelected: true),
      );
      semantics.dispose();
    });

    testWidgets('selection in a pair: only the tapped card is selected',
        (tester) async {
      String? selected;
      await _pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => Row(
            children: [
              Expanded(
                child: GenderOptionCard(
                  key: const ValueKey('m'),
                  label: 'Эрэгтэй',
                  icon: Icons.male_rounded,
                  selected: selected == 'm',
                  onTap: () => setState(() => selected = 'm'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GenderOptionCard(
                  key: const ValueKey('f'),
                  label: 'Эмэгтэй',
                  icon: Icons.female_rounded,
                  selected: selected == 'f',
                  onTap: () => setState(() => selected = 'f'),
                ),
              ),
            ],
          ),
        ),
      );
      double scaleOf(String k) => tester
          .widget<AnimatedScale>(
            find.descendant(
              of: find.byKey(ValueKey(k)),
              matching: find.byKey(GenderOptionCard.checkBadgeKey),
            ),
          )
          .scale;

      await tester.tap(find.text('Эмэгтэй'));
      await tester.pumpAndSettle();
      expect(selected, 'f');
      expect(scaleOf('f'), 1);
      expect(scaleOf('m'), 0);

      await tester.tap(find.text('Эрэгтэй'));
      await tester.pumpAndSettle();
      expect(selected, 'm');
      expect(scaleOf('m'), 1);
      expect(scaleOf('f'), 0);
    });

    testWidgets('reduce motion: selected state applies immediately',
        (tester) async {
      await _pump(
        tester,
        GenderOptionCard(
          label: 'Эрэгтэй',
          icon: Icons.male_rounded,
          selected: true,
          onTap: () {},
        ),
        reduceMotion: true,
      );
      await tester.pump();
      expect(badgeScale(tester), 1);
    });
  });

  group('BirthDateTile', () {
    testWidgets('shows the placeholder and fires onTap', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        BirthDateTile(value: null, onTap: () => taps++),
      );
      expect(find.text('Огноо сонгох'), findsOneWidget);
      await tester.tap(find.byType(BirthDateTile));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('formats the chosen date as yyyy.MM.dd', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        BirthDateTile(value: DateTime(2001, 3, 9), onTap: () {}),
      );
      expect(find.text('2001.03.09'), findsOneWidget);
      expect(find.text('Огноо сонгох'), findsNothing);
      expect(
        find.bySemanticsLabel('Төрсөн он сар өдөр: 2001.03.09'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('shows the age chip for a chosen date', (tester) async {
      final now = DateTime.now();
      // Jan 1 birthdays are always reached by "today".
      await _pump(
        tester,
        BirthDateTile(value: DateTime(now.year - 25, 1, 1), onTap: () {}),
      );
      expect(find.text('25 нас'), findsOneWidget);
    });
  });

  group('TermsAgreementTile', () {
    testWidgets('tapping the box toggles; links open the sheets',
        (tester) async {
      final changes = <bool>[];
      var terms = 0;
      var privacy = 0;
      await _pump(
        tester,
        TermsAgreementTile(
          value: false,
          onChanged: changes.add,
          onTapTerms: () => terms++,
          onTapPrivacy: () => privacy++,
        ),
      );

      // The checkbox sits at the tile's top-left (14 padding + 12 half-box).
      await tester.tapAt(
        tester.getTopLeft(find.byType(TermsAgreementTile)) +
            const Offset(26, 26),
      );
      await tester.pumpAndSettle();
      expect(changes, [true]);

      await tester.tapOnText(
        find.textRange.ofSubstring(TermsAgreementTile.termsLabel),
      );
      await tester.pumpAndSettle();
      expect(terms, 1);

      await tester.tapOnText(
        find.textRange.ofSubstring(TermsAgreementTile.privacyLabel),
      );
      await tester.pumpAndSettle();
      expect(privacy, 1);

      // Link taps must not toggle the checkbox.
      expect(changes, [true]);
    });

    testWidgets('exposes the checked state to screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        TermsAgreementTile(
          value: true,
          onChanged: (_) {},
          onTapTerms: () {},
          onTapPrivacy: () {},
        ),
      );
      expect(
        tester.getSemantics(find.byType(TermsAgreementTile)),
        isSemantics(hasCheckedState: true, isChecked: true),
      );
      semantics.dispose();
    });
  });

  group('AuthFooterLink', () {
    testWidgets('is a 44pt tappable link', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        AuthFooterLink(
          prompt: 'Шинээр бүртгүүлэх үү?',
          action: 'Бүртгүүлэх',
          onTap: () => taps++,
        ),
      );
      expect(find.text('Шинээр бүртгүүлэх үү? Бүртгүүлэх'), findsOneWidget);
      expect(
        tester.getSize(find.byType(Pressable)).height,
        greaterThanOrEqualTo(AppLayout.minTapTarget),
      );
      await tester.tap(find.byType(AuthFooterLink));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('small screens + large text', () {
    testWidgets('auth pieces do not overflow at 320pt and 1.3x text',
        (tester) async {
      final phone = TextEditingController(text: '88778899');
      final pass = TextEditingController(text: 'secret1');
      addTearDown(phone.dispose);
      addTearDown(pass.dispose);
      await _pump(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PhoneNumberSection(controller: phone),
            const SizedBox(height: 12),
            PasswordField(
              controller: pass,
              hintText: 'Нууц үг (доод тал нь 6 тэмдэгт)',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GenderOptionCard(
                    label: 'Эрэгтэй',
                    icon: Icons.male_rounded,
                    selected: true,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GenderOptionCard(
                    label: 'Эмэгтэй',
                    icon: Icons.female_rounded,
                    selected: false,
                    error: true,
                    onTap: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            BirthDateTile(value: DateTime(1999, 12, 31), onTap: () {}),
            const FieldError('Төрсөн өдрөө сонгоно уу'),
            const SizedBox(height: 12),
            TermsAgreementTile(
              value: false,
              onChanged: (_) {},
              onTapTerms: () {},
              onTapPrivacy: () {},
            ),
            AuthFooterLink(
              prompt: 'Шинээр бүртгүүлэх үү?',
              action: 'Бүртгүүлэх',
              onTap: () {},
            ),
          ],
        ),
        width: 320,
        textScale: 1.3,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
