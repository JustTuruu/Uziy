import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/widgets/ui.dart';

void main() {
  testWidgets('measure', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            TextFormField(
              key: const ValueKey('a'),
              initialValue: 'hello',
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.lock_outline_rounded),
                errorText: 'ERRTEXT',
              ),
            ),
            TextFormField(
              key: const ValueKey('b'),
              initialValue: 'noicon',
              decoration: const InputDecoration(
                helperText: 'HELPTEXT',
              ),
            ),
          ]),
        ),
      ),
    ));
    final fieldA = tester.getRect(find.byKey(const ValueKey('a')));
    print('fieldA $fieldA');
    print('icon ${tester.getRect(find.byIcon(Icons.lock_outline_rounded))}');
    print('editable ${tester.getRect(find.descendant(of: find.byKey(const ValueKey('a')), matching: find.byType(EditableText)))}');
    print('err ${tester.getRect(find.text('ERRTEXT'))}');
    final deco = tester.widget<InputDecorator>(find.descendant(of: find.byKey(const ValueKey('a')), matching: find.byType(InputDecorator)));
    print('decorator rect ${tester.getRect(find.descendant(of: find.byKey(const ValueKey('a')), matching: find.byType(InputDecorator)))}');
    print(deco.decoration.contentPadding);
    print('helper ${tester.getRect(find.text('HELPTEXT'))}');
    print('editB ${tester.getRect(find.descendant(of: find.byKey(const ValueKey('b')), matching: find.byType(EditableText)))}');
    final t = tester.widget<Text>(find.text('ERRTEXT'));
    print('err style ${t.style}');
    final rt = tester.renderObject<RenderParagraph>(find.descendant(of: find.text('ERRTEXT'), matching: find.byType(RichText)));
    print('err rendered style ${rt.text.style}');
  });
}
