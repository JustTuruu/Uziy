import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/widgets/ui.dart';

const _body = Key('body');

/// [AppSheetFrame] around a 100pt box, at the bottom of an 800pt screen.
Future<void> _pumpFrame(WidgetTester tester, MediaQueryData media) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(MediaQuery(
    data: media.copyWith(size: const Size(400, 800)),
    child: const Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AppSheetFrame(
          child: SizedBox(key: _body, width: 400, height: 100),
        ),
      ),
    ),
  ));
}

void main() {
  group('AppSheetFrame', () {
    testWidgets('keeps the content above the home indicator', (tester) async {
      await _pumpFrame(
        tester,
        const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
      );
      expect(tester.getRect(find.byKey(_body)).bottom, 800 - 34);
    });

    testWidgets(
        'keeps the content above the keyboard, without adding the '
        'home indicator twice', (tester) async {
      // With the keyboard up the bottom padding is part of the inset.
      await _pumpFrame(
        tester,
        const MediaQueryData(
          viewInsets: EdgeInsets.only(bottom: 300),
          viewPadding: EdgeInsets.only(bottom: 34),
        ),
      );
      expect(tester.getRect(find.byKey(_body)).bottom, 800 - 300);
    });
  });

  group('showAppSheet', () {
    testWidgets(
        'opens on the root navigator from a nested one, with a drag '
        'handle, and returns the popped value', (tester) async {
      final nestedKey = GlobalKey<NavigatorState>();
      String? result;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Navigator(
          key: nestedKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await showAppSheet<String>(
                  context,
                  builder: (sheet) => TextButton(
                    onPressed: () => Navigator.of(sheet).pop('done'),
                    child: const Text('close'),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final sheet = tester.element(find.text('close'));
      expect(Navigator.of(sheet), isNot(same(nestedKey.currentState)));
      expect(
          Navigator.of(sheet), same(Navigator.of(sheet, rootNavigator: true)));
      expect(find.byType(AppSheetFrame), findsOneWidget);
      final bottomSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(bottomSheet.showDragHandle, isTrue);

      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();
      expect(result, 'done');
    });
  });
}
