import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/screens/auth/auth_widgets.dart';
import 'package:viewer_app/screens/wallet/add_name_sheet.dart';
import 'package:viewer_app/services/viewer_service.dart';
import 'package:viewer_app/widgets/ui.dart';

Future<void> _pump(WidgetTester tester, SaveName onSave,
    {void Function(bool?)? onClosed}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final r = await showAddNameSheet(context, onSave: onSave);
            onClosed?.call(r);
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.descendant(
      of: find.widgetWithText(LabeledField, label),
      matching: find.byType(TextField),
    );

void main() {
  testWidgets('asks for овог and нэр and says why', (tester) async {
    await _pump(tester, (_, __) async {});
    expect(find.text(kAddNameTitle), findsOneWidget);
    expect(find.text(kAddNameNote), findsOneWidget);
    expect(find.byType(PersonNameFields), findsOneWidget);
    expect(find.text(PersonNameFields.lastNameLabel), findsOneWidget);
    expect(find.text(PersonNameFields.firstNameLabel), findsOneWidget);
  });

  testWidgets('empty or non-letter names are refused before saving',
      (tester) async {
    var saves = 0;
    await _pump(tester, (_, __) async => saves++);

    await tester.tap(find.text(kAddNameSave));
    await tester.pump();
    expect(find.text(AuthValidators.lastNameRequired), findsOneWidget);
    expect(find.text(AuthValidators.firstNameRequired), findsOneWidget);

    await tester.enterText(_field(PersonNameFields.lastNameLabel), 'Бат123');
    await tester.enterText(_field(PersonNameFields.firstNameLabel), 'Сараа');
    await tester.tap(find.text(kAddNameSave));
    await tester.pump();
    expect(saves, 0);
  });

  testWidgets('a valid name is saved trimmed and the sheet closes with true',
      (tester) async {
    final saved = <String>[];
    bool? result;
    await _pump(tester, (last, first) async => saved.addAll([last, first]),
        onClosed: (r) => result = r);

    await tester.enterText(_field(PersonNameFields.lastNameLabel), ' Бат ');
    await tester.enterText(_field(PersonNameFields.firstNameLabel), 'Сараа ');
    await tester.tap(find.text(kAddNameSave));
    await tester.pumpAndSettle();

    expect(saved, ['Бат', 'Сараа']);
    expect(result, isTrue);
    expect(find.text(kAddNameTitle), findsNothing);
  });

  testWidgets('a refusal from the server is shown and the sheet stays',
      (tester) async {
    await _pump(tester, (_, __) async {
      throw ApiException(409, 'Овог, нэр аль хэдийн бүртгэгдсэн байна');
    });

    await tester.enterText(_field(PersonNameFields.lastNameLabel), 'Бат');
    await tester.enterText(_field(PersonNameFields.firstNameLabel), 'Сараа');
    await tester.tap(find.text(kAddNameSave));
    await tester.pumpAndSettle();

    expect(find.text('Овог, нэр аль хэдийн бүртгэгдсэн байна'), findsOneWidget);
    expect(find.text(kAddNameTitle), findsOneWidget);
  });
}
