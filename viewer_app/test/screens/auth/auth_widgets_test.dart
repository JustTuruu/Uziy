import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/user.dart';
import 'package:viewer_app/screens/auth/auth_widgets.dart';
import 'package:viewer_app/widgets/ui.dart';

/// Pumps [child] in the real app theme at a phone-sized viewport.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double textScale = 1.0,
  bool reduceMotion = false,
  ThemeData? theme,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = Size(width * 3, 844 * 3);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
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
      // Spaces a user types or pastes do not count as characters.
      expect(AuthValidators.phone('8877 8899', message: msg), isNull);
      expect(AuthValidators.phone('8877 889', message: msg), msg);
    });

    test('password needs at least 6 characters', () {
      expect(AuthValidators.password(null), 'Дор хаяж 6 тэмдэгт');
      expect(AuthValidators.password('12345'), 'Дор хаяж 6 тэмдэгт');
      expect(AuthValidators.password('123456'), isNull);
      expect(AuthValidators.password('a much longer one'), isNull);
    });

    test('passwordRepeat: must equal the first typing exactly', () {
      expect(AuthValidators.passwordRepeat(null, 'secret1'),
          AuthValidators.passwordRepeatRequired);
      expect(AuthValidators.passwordRepeat('', 'secret1'),
          AuthValidators.passwordRepeatRequired);
      expect(AuthValidators.passwordRepeat('secret2', 'secret1'),
          AuthValidators.passwordMismatch);
      expect(AuthValidators.passwordRepeat('Secret1', 'secret1'),
          AuthValidators.passwordMismatch);
      expect(AuthValidators.passwordRepeat('secret1', 'secret1'), isNull);
    });

    test('names: real names pass, like the backend rule', () {
      for (final name in [
        'Оюун-Эрдэнэ',
        'Төрболд',
        'Бат-Өлзий',
        'Turbold',
        ' Болд ',
        "O'Neil",
        'Болд Эрдэнэ'
      ]) {
        expect(AuthValidators.lastName(name), isNull, reason: name);
        expect(AuthValidators.firstName(name), isNull, reason: name);
      }
    });

    test('names: empty, digits, symbols and overlong are refused', () {
      expect(AuthValidators.lastName(''), AuthValidators.lastNameRequired);
      expect(AuthValidators.firstName('  '), AuthValidators.firstNameRequired);
      expect(AuthValidators.lastName('Бат1'), AuthValidators.nameLetters);
      expect(AuthValidators.firstName('-Болд'), AuthValidators.nameLetters);
      expect(AuthValidators.firstName('Болд@'), AuthValidators.nameLetters);
      expect(
        AuthValidators.lastName('Б' * (AuthValidators.nameMaxLength + 1)),
        AuthValidators.nameTooLong,
      );
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

  group('PhoneDigitsFormatter', () {
    TextEditingValue format(String typed) =>
        const PhoneDigitsFormatter().formatEditUpdate(
            TextEditingValue.empty, TextEditingValue(text: typed));

    test('keeps only digits, at most 8', () {
      expect(format('8811 2233').text, '88112233');
      expect(format('8811-2233-99').text, '88112233');
      expect(format('abc').text, '');
    });

    test('a pasted number with the country code keeps the 8 national digits',
        () {
      expect(format('+976 8811 2233').text, '88112233');
      expect(format('97688112233').text, '88112233');
    });

    test('an ordinary edit is left alone, caret included', () {
      const typed = TextEditingValue(
        text: '8811',
        selection: TextSelection.collapsed(offset: 2),
      );
      expect(
        const PhoneDigitsFormatter()
            .formatEditUpdate(TextEditingValue.empty, typed),
        typed,
      );
    });
  });

  group('PhoneField', () {
    testWidgets('a plain editable field with a +976 prefix', (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      await _pump(tester, PhoneField(controller: ctrl));

      expect(find.text(PhoneField.countryCode), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.number);
      expect(field.autofillHints, PhoneField.defaultAutofillHints);
      expect(field.enableInteractiveSelection, isTrue,
          reason: 'the number can be selected, copied and pasted');
      expect(field.showCursor, isNot(false));
    });

    testWidgets('typing goes straight into the controller as bare digits',
        (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      await _pump(tester, PhoneField(controller: ctrl));

      await tester.enterText(find.byType(TextField), '+976 8811 2233');
      expect(ctrl.text, '88112233');
      expect(find.text('88112233'), findsOneWidget);
    });

    testWidgets('a failed validation shows the message under the field',
        (tester) async {
      final ctrl = TextEditingController(text: '8811');
      addTearDown(ctrl.dispose);
      final formKey = GlobalKey<FormState>();
      await _pump(
        tester,
        Form(
          key: formKey,
          child: PhoneField(
            controller: ctrl,
            validator: (v) => AuthValidators.phone(v, message: 'Буруу'),
          ),
        ),
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Буруу'), findsOneWidget);
    });

    /// The user's request (2026-10-14): the phone field must look like the
    /// password field — same height, font and border.
    testWidgets('matches the password field: height, font and border',
        (tester) async {
      final phone = TextEditingController(text: '88112233');
      final pass = TextEditingController(text: 'secret');
      addTearDown(phone.dispose);
      addTearDown(pass.dispose);
      await _pump(
        tester,
        Column(
          children: [
            PhoneField(controller: phone),
            PasswordField(controller: pass),
          ],
        ),
      );

      final phoneBox = find.byType(TextFormField).first;
      final passBox = find.byType(TextFormField).last;
      expect(tester.getSize(phoneBox).height, tester.getSize(passBox).height);

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      final phoneStyle = fields.first.style!;
      final passStyle = fields.last.style!;
      expect(phoneStyle.fontSize, passStyle.fontSize);
      expect(phoneStyle.fontWeight, passStyle.fontWeight);
      expect(phoneStyle.height, passStyle.height);

      final borders = tester
          .widgetList<InputDecorator>(find.byType(InputDecorator))
          .map((d) => d.decoration.border ?? d.decoration.enabledBorder)
          .toList();
      expect(borders.first, borders.last);
    });

    /// Regression (2026-10-13): '+976' kept the light text colour, so it was
    /// almost invisible on the dark background.
    testWidgets('+976 and the number follow the dark theme', (tester) async {
      final ctrl = TextEditingController(text: '88112233');
      addTearDown(ctrl.dispose);
      await _pump(tester, PhoneField(controller: ctrl), theme: AppTheme.dark());

      const dark = AppPalette(true);
      final prefix = tester.widget<Text>(find.text(PhoneField.countryCode));
      expect(prefix.style!.color, dark.textSecondary);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style!.color, dark.textPrimary);
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
    testWidgets('lines up with the text inside a field', (tester) async {
      await _pump(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [FieldError('алдаа')],
        ),
      );
      final column = tester.getTopLeft(find.byType(Column)).dx;
      expect(tester.getTopLeft(find.text('алдаа')).dx, greaterThan(column));
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

      await tester.tap(find.byIcon(AppIcons.passwordHidden));
      await tester.pumpAndSettle();
      expect(obscured(), isFalse);
      expect(find.bySemanticsLabel(PasswordField.hideLabel), findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.passwordShown));
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

  group('GenderSelector', () {
    testWidgets('nothing chosen at first; a tap reports the gender once',
        (tester) async {
      final picked = <Gender>[];
      await _pump(
        tester,
        GenderSelector(value: null, onChanged: picked.add),
      );
      expect(find.text('Эрэгтэй'), findsOneWidget);
      expect(find.text('Эмэгтэй'), findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<Gender>>(
                find.byType(SegmentedButton<Gender>))
            .selected,
        isEmpty,
      );
      await tester.tap(find.text('Эмэгтэй'));
      await tester.pump();
      expect(picked, [Gender.female]);
    });

    testWidgets('tapping the chosen one again reports nothing', (tester) async {
      final picked = <Gender>[];
      await _pump(
        tester,
        GenderSelector(value: Gender.male, onChanged: picked.add),
      );
      await tester.tap(find.text('Эрэгтэй'));
      await tester.pump();
      expect(picked, isEmpty);
    });

    // Owner, 2026-10-22: it grew to ~62pt (taller than the fields) and
    // looked too big; it is now a compact 44pt at any text size.
    for (final scale in [1.0, 1.3]) {
      testWidgets('compact: exactly 44pt tall, no check mark (text x$scale)',
          (tester) async {
        await _pump(
          tester,
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: GenderSelector(value: Gender.male, onChanged: (_) {}),
          ),
        );
        expect(GenderSelector.height, 44);
        expect(
          tester.getSize(find.byType(SegmentedButton<Gender>)).height,
          GenderSelector.height,
        );
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.check), findsNothing);

        // Each half fills the control and its word sits in the middle (a
        // forced outer height once left the word high over a dark band).
        final box = tester.getRect(find.byType(SegmentedButton<Gender>));
        for (final label in GenderSelector.labels.values) {
          final half = tester.getRect(find
              .ancestor(of: find.text(label), matching: find.byType(TextButton))
              .first);
          expect(half.height, closeTo(box.height, 1), reason: label);
          expect(
              tester.getCenter(find.text(label)).dy, closeTo(box.center.dy, 1),
              reason: label);
        }
      });
    }
  });

  group('AuthPageTitle', () {
    testWidgets('is a heading at the flow title size', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, const AuthPageTitle('Нэвтрэх'));
      expect(
        tester.getSemantics(find.text('Нэвтрэх')),
        isSemantics(isHeader: true),
      );
      expect(
        tester.widget<Text>(find.text('Нэвтрэх')).style?.fontSize,
        AuthPageTitle.titleSize,
      );
      semantics.dispose();
    });
  });

  group('LabeledField', () {
    testWidgets('the label turns brand green while its field has the cursor',
        (tester) async {
      await _pump(
        tester,
        LabeledField(label: 'Овог', child: TextFormField()),
      );
      Color? labelColor() => tester
          .widget<AnimatedDefaultTextStyle>(find
              .ancestor(
                of: find.text('Овог'),
                matching: find.byType(AnimatedDefaultTextStyle),
              )
              .first)
          .style
          .color;
      final primary = AppTheme.light().colorScheme.primary;
      expect(labelColor(), isNot(primary));
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(labelColor(), primary);
    });

    testWidgets('a trailing action shares the label line', (tester) async {
      await _pump(
        tester,
        LabeledField(
          label: 'Нууц үг',
          trailing: const Text('link'),
          child: TextFormField(),
        ),
      );
      expect(
        (tester.getCenter(find.text('link')).dy -
                tester.getCenter(find.text('Нууц үг')).dy)
            .abs(),
        lessThan(8),
      );
    });
  });

  group('AuthBackButton', () {
    testWidgets('a 44pt round control named Буцах', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await _pump(tester, AuthBackButton(onPressed: () => taps++));
      expect(tester.getSize(find.byType(AuthBackButton)),
          const Size.square(AppLayout.minTapTarget));
      expect(tester.getSemantics(find.byType(AuthBackButton)),
          isSemantics(label: AuthBackButton.label, isButton: true));
      await tester.tap(find.byType(AuthBackButton));
      await tester.pumpAndSettle();
      expect(taps, 1);
      semantics.dispose();
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
    testWidgets('error paints the frame red; the box fill is flat',
        (tester) async {
      Future<BoxDecoration> frame(
          {required bool value, bool error = false}) async {
        await _pump(
          tester,
          TermsAgreementTile(
            value: value,
            error: error,
            onChanged: (_) {},
            onTapTerms: () {},
            onTapPrivacy: () {},
          ),
        );
        await tester.pumpAndSettle();
        final boxes = tester
            .widgetList<AnimatedContainer>(find.descendant(
              of: find.byType(TermsAgreementTile),
              matching: find.byType(AnimatedContainer),
            ))
            .map((c) => c.decoration as BoxDecoration)
            .toList();
        for (final b in boxes) {
          expect(b.gradient, isNull);
        }
        return boxes.first;
      }

      final red = await frame(value: false, error: true);
      expect((red.border! as Border).top.color,
          AppTheme.light().colorScheme.error);
      final ok = await frame(value: false);
      expect((ok.border! as Border).top.color,
          isNot(AppTheme.light().colorScheme.error));
    });

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
            PhoneField(controller: phone),
            const SizedBox(height: 12),
            PasswordField(
              controller: pass,
              hintText: 'Нууц үг (доод тал нь 6 тэмдэгт)',
            ),
            const SizedBox(height: 12),
            GenderSelector(
              value: Gender.male,
              error: true,
              onChanged: (_) {},
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
