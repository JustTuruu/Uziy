import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/screens/auth/login_backdrop.dart';
import 'package:viewer_app/screens/auth/login_fields.dart';
import 'package:viewer_app/widgets/ui.dart';

void main() {
  group('SoftShadowInputBorder', () {
    test('copyWith keeps the shadow colour', () {
      const border = SoftShadowInputBorder(shadowColor: Color(0x11000000));
      final copy = border.copyWith(borderRadius: AppRadii.brSm);
      expect(copy.shadowColor, const Color(0x11000000));
      expect(copy.borderRadius, AppRadii.brSm);
    });

    test('equality includes the shadow colour', () {
      const a = SoftShadowInputBorder(shadowColor: Color(0x11000000));
      const b = SoftShadowInputBorder(shadowColor: Color(0x22000000));
      expect(a == b, isFalse);
      expect(a == const SoftShadowInputBorder(shadowColor: Color(0x11000000)),
          isTrue);
    });

    testWidgets('only the sign-in page raises its fields', (tester) async {
      Future<InputBorder?> enabled({required bool raised}) async {
        late InputBorder? border;
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(),
          home: LoginFieldsTheme(
            raised: raised,
            child: Builder(builder: (context) {
              border = Theme.of(context).inputDecorationTheme.enabledBorder;
              return const SizedBox();
            }),
          ),
        ));
        return border;
      }

      final up = await enabled(raised: true) as SoftShadowInputBorder;
      expect(up.shadowColor, isNotNull);
      final flat = await enabled(raised: false) as SoftShadowInputBorder;
      expect(flat.shadowColor, isNull);
    });
  });

  group('LoginBackdrop', () {
    test('paints in both themes and only repaints on a new tint', () {
      for (final dark in [false, true]) {
        final p = LoginBackdropPainter(tint: Colors.green, dark: dark);
        final recorder = PictureRecorder();
        p.paint(Canvas(recorder), const Size(390, 844));
        recorder.endRecording();
        expect(p.shouldRepaint(p), isFalse);
      }
    });

    testWidgets('is decorative: no taps, no semantics', (tester) async {
      var taps = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Stack(children: [
          Positioned.fill(
            child: GestureDetector(onTap: () => taps++),
          ),
          const Positioned.fill(child: LoginBackdrop()),
        ]),
      ));
      await tester.tapAt(const Offset(200, 400));
      expect(taps, 1, reason: 'taps pass through the curves');
      expect(
        find.descendant(
          of: find.byType(LoginBackdrop),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });
}
