import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/regions.dart';
import 'package:viewer_app/screens/auth/location_fields.dart';
import 'package:viewer_app/widgets/ui.dart';

/// Hosts [LocationFields] in a form the way the register screen does.
class _Host extends StatefulWidget {
  const _Host(
      {required this.formKey, required this.city, required this.district});
  final GlobalKey<FormState> formKey;
  final TextEditingController city;
  final TextEditingController district;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) => Form(
        key: widget.formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LocationFields(
              city: widget.city,
              district: widget.district,
              onCityChanged: (_) => setState(() {}),
            ),
          ],
        ),
      );
}

void main() {
  late GlobalKey<FormState> form;
  late TextEditingController city;
  late TextEditingController district;

  Future<void> pump(WidgetTester tester, {String start = kCapital}) async {
    form = GlobalKey<FormState>();
    city = TextEditingController(text: start);
    district = TextEditingController();
    addTearDown(city.dispose);
    addTearDown(district.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: _Host(formKey: form, city: city, district: district),
      ),
    ));
  }

  /// [option] inside the open dropdown menu (not the field showing it).
  Finder inMenu(String option) => find.descendant(
      of: find.byType(Scrollable).last, matching: find.text(option));

  /// Opens [field]'s menu and taps [option]; [delta] < 0 scrolls the menu up
  /// (the menu opens at the current choice).
  Future<void> pick(WidgetTester tester, Key field, String option,
      {double delta = 50}) async {
    await tester.tap(find.byKey(field));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(inMenu(option), delta,
        scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(inMenu(option));
    await tester.pumpAndSettle();
    await tester.tap(inMenu(option));
    await tester.pumpAndSettle();
  }

  testWidgets('every aimag can be picked', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('city')));
    await tester.pumpAndSettle();

    for (final aimag in kAimags) {
      await tester.scrollUntilVisible(inMenu(aimag), 50,
          scrollable: find.byType(Scrollable).last);
      expect(inMenu(aimag), findsOneWidget);
    }
  });

  testWidgets('in the capital a district is required', (tester) async {
    await pump(tester);

    expect(find.text(kDistrictLabel), findsOneWidget);
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text(kDistrictRequired), findsOneWidget);

    await pick(tester, const ValueKey('district'), 'Хан-Уул');

    expect(district.text, 'Хан-Уул');
    expect(form.currentState!.validate(), isTrue);
  });

  testWidgets('an aimag asks for an optional sum instead', (tester) async {
    await pump(tester);

    await pick(tester, const ValueKey('city'), 'Дархан-Уул');

    expect(city.text, 'Дархан-Уул');
    expect(find.text(kDistrictLabel), findsNothing);
    expect(find.byKey(const ValueKey('sum')), findsOneWidget);
    expect(form.currentState!.validate(), isTrue, reason: 'sum is optional');
  });

  testWidgets('changing the city clears the district', (tester) async {
    await pump(tester);
    await pick(tester, const ValueKey('district'), 'Баянгол');

    await pick(tester, const ValueKey('city'), 'Ховд');
    expect(district.text, isEmpty);

    await pick(tester, const ValueKey('city'), kCapital, delta: -50);
    expect(form.currentState!.validate(), isFalse,
        reason: 'back in the capital the district must be picked again');
  });
}
