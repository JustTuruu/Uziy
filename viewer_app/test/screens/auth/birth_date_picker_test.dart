import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/screens/auth/birth_date_picker.dart';
import 'package:viewer_app/theme/app_theme.dart';

final _first = DateTime(1946);
final _last = DateTime(2013);
final _now = DateTime(2026, 10, 22);

Finder _wheel(String label) => find.byKey(ValueKey('birth-wheel-$label'));

/// Turns [label]'s wheel by [rows] (positive = towards later values).
Future<void> _spin(WidgetTester tester, String label, int rows) async {
  await tester.drag(
      _wheel(label), Offset(0, -rows * kBirthWheelItemExtent.toDouble()));
  await tester.pumpAndSettle();
}

/// Opens the sheet on [initial] (age counted on [_now]).
Future<void> _open(WidgetTester tester, DateTime initial) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showModalBottomSheet<DateTime>(
            context: context,
            isScrollControlled: true,
            builder: (_) => BirthDateSheet(
              initial: initial,
              first: _first,
              last: _last,
              now: _now,
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<DateTime?> _done(
    WidgetTester tester, Future<DateTime?> Function() read) async {
  await tester.tap(find.text(kBirthPickerDone));
  await tester.pumpAndSettle();
  return read();
}

void main() {
  group('logic', () {
    test('daysInMonth knows leap Februaries', () {
      expect(daysInMonth(2004, 2), 29);
      expect(daysInMonth(2005, 2), 28);
      expect(daysInMonth(2000, 2), 29);
      expect(daysInMonth(1900, 2), 28);
      expect(daysInMonth(2006, 10), 31);
      expect(daysInMonth(2006, 11), 30);
    });

    test('birthDateFrom cuts the day to the month', () {
      expect(birthDateFrom(2005, 2, 31, first: _first, last: _last),
          DateTime(2005, 2, 28));
      expect(birthDateFrom(2004, 2, 31, first: _first, last: _last),
          DateTime(2004, 2, 29));
      expect(birthDateFrom(2006, 10, 22, first: _first, last: _last),
          DateTime(2006, 10, 22));
    });

    test('birthDateFrom keeps the date inside the bounds', () {
      expect(birthDateFrom(2013, 6, 1, first: _first, last: _last), _last);
      expect(birthDateFrom(1940, 1, 1, first: _first, last: _last), _first);
    });

    test('the date is written as it is said, the age with настай', () {
      expect(birthDateLong(DateTime(2007, 2, 22)), '2007 оны 2-р сарын 22');
      expect(birthDateLong(DateTime(1999, 12, 1)), '1999 оны 12-р сарын 1');
      expect(birthAgeLabel(19), '19 настай');
    });

    test('months read 1-р сар … 12-р сар', () {
      expect(birthMonthLabel(1), '1-р сар');
      expect(birthMonthLabel(12), '12-р сар');
    });
  });

  group('BirthDateSheet', () {
    testWidgets('opens on the given date with three labelled wheels',
        (tester) async {
      await _open(tester, DateTime(2006, 10, 22));

      expect(find.text(kBirthPickerTitle), findsOneWidget);
      for (final l in [kYearWheelLabel, kMonthWheelLabel, kDayWheelLabel]) {
        expect(_wheel(l), findsOneWidget);
        expect(find.text(l), findsOneWidget);
      }
      // The date as it is said, and the age.
      expect(find.text('2006 оны 10-р сарын 22'), findsOneWidget);
      expect(find.text('20 настай'), findsOneWidget);
      expect(find.textContaining('2006.10.22'), findsNothing);
      // No month calendar any more.
      expect(find.byType(CalendarDatePicker), findsNothing);
    });

    testWidgets('turning the year wheel moves straight to another year',
        (tester) async {
      DateTime? result;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showBirthDatePicker(
                context,
                initial: DateTime(2006, 10, 22),
                first: _first,
                last: _last,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await _spin(tester, kYearWheelLabel, -6); // 2006 → 2000
      await _spin(tester, kMonthWheelLabel, -9); // October → January
      await _spin(tester, kDayWheelLabel, -17); // 22 → 5

      expect(await _done(tester, () async => result), DateTime(2000, 1, 5));
    });

    testWidgets('a day the new month does not have becomes its last day',
        (tester) async {
      await _open(tester, DateTime(2005, 1, 31));

      await _spin(tester, kMonthWheelLabel, 1); // January 31 → February

      expect(find.text('2005 оны 2-р сарын 28'), findsOneWidget);
    });

    // Regression: the band is drawn over the chosen row; an opaque band hid
    // the chosen year, month and day.
    testWidgets('the highlight band lets the chosen values show through',
        (tester) async {
      await _open(tester, DateTime(2006, 10, 22));
      final bands = tester.widgetList<CupertinoPickerDefaultSelectionOverlay>(
          find.byType(CupertinoPickerDefaultSelectionOverlay));
      expect(bands, hasLength(3));
      for (final band in bands) {
        expect(band.background.a, lessThan(0.5));
      }
    });

    testWidgets('dismissing returns nothing', (tester) async {
      await _open(tester, DateTime(2006, 10, 22));
      await tester.tapAt(const Offset(10, 10)); // the barrier above the sheet
      await tester.pumpAndSettle();
      expect(find.text(kBirthPickerTitle), findsNothing);
    });

    for (final dark in [false, true]) {
      testWidgets('fits a 320pt phone at 1.3x text (dark: $dark)',
          (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
            body: BirthDateSheet(
              initial: DateTime(2006, 10, 22),
              first: _first,
              last: _last,
              now: _now,
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
