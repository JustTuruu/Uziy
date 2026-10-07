import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/screens/profile/privacy_content.dart';
import 'package:viewer_app/screens/profile/privacy_screen.dart';
import 'package:viewer_app/widgets/ui.dart';

void main() {
  testWidgets('shows the title, the intro and the sections', (tester) async {
    tester.view.physicalSize = const Size(390, 3000) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const PrivacyScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text(kPrivacyTitle), findsOneWidget);
    expect(find.text(kPrivacyIntro), findsOneWidget);
    expect(
        find.byType(PolicySectionView), findsNWidgets(kPrivacySections.length));
    for (final section in kPrivacySections) {
      expect(find.text(section.heading), findsOneWidget);
      expect(find.text(section.body), findsOneWidget);
    }
  });

  test('every policy section has a heading and a body', () {
    for (final section in kPrivacySections) {
      expect(section.heading.trim(), isNotEmpty);
      expect(section.body.trim(), isNotEmpty);
    }
  });
}
