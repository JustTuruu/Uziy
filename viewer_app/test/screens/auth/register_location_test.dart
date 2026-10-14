import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:viewer_app/models/regions.dart';
import 'package:viewer_app/routes/app_router.dart' show Routes;
import 'package:viewer_app/screens/auth/auth_widgets.dart';
import 'package:viewer_app/screens/auth/location_fields.dart';
import 'package:viewer_app/screens/auth/register_screen.dart';
import 'package:viewer_app/widgets/ui.dart';

import '../../support/fake_api.dart';

void main() {
  testWidgets(
      'registering in Улаанбаатар without a district is stopped on the form, '
      'before any SMS', (tester) async {
    final api = FakeApi.install((_) => const FakeReply(500));
    tester.view.physicalSize = const Size(390, 2600) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: Routes.register,
      routes: [
        GoRoute(
            path: Routes.register, builder: (_, __) => const RegisterScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: app!,
      ),
    ));
    await tester.pumpAndSettle();

    // Nothing is preselected; picking the capital brings up its districts.
    expect(find.byType(LocationFields), findsOneWidget);
    expect(find.text(kDistrictLabel), findsNothing);
    final city = find.byKey(const ValueKey('city'));
    await tester.ensureVisible(city);
    await tester.pumpAndSettle();
    await tester.tap(city);
    await tester.pumpAndSettle();
    await tester.tap(find.text(kCapital).last);
    await tester.pumpAndSettle();
    expect(find.text(kDistrictLabel), findsOneWidget);

    final tile = find.byType(TermsAgreementTile);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getTopLeft(tile) + const Offset(30, 30));
    await tester.pumpAndSettle();
    final submit = find.widgetWithText(AppButton, kContinueLabel);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text(kDistrictRequired), findsOneWidget);
    expect(api.callsTo('/auth/phone-verifications'), isEmpty);
  });
}
