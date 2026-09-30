import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/user.dart';
import 'package:viewer_app/screens/profile/profile_logic.dart';
import 'package:viewer_app/screens/profile/profile_widgets.dart';
import 'package:viewer_app/widgets/ui.dart';

AppUser _user({
  bool verified = false,
  String phone = '88778899',
  Gender? gender = Gender.male,
  int? age = 24,
  String? city = 'Улаанбаатар',
  String? district,
  double balance = 3400,
}) =>
    AppUser(
      id: 7,
      phoneNumber: phone,
      role: UserRole.viewer,
      gender: gender,
      age: age,
      city: city,
      district: district,
      balance: balance,
      isVerified: verified,
    );

/// Pumps [child] in the app theme inside a scrollable page, optionally with
/// reduce-motion and an OS text scale.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool reduceMotion = false,
  double textScale = 1.0,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
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

void _setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  group('ProfileTitle', () {
    testWidgets('matches the other tab titles: display style plus subtitle',
        (tester) async {
      await _pump(tester, const ProfileTitle());

      final title = tester.widget<Text>(find.text(ProfileTitle.title));
      expect(title.style, AppTextStyles.display);
      final subtitle = tester.widget<Text>(find.text(ProfileTitle.subtitle));
      expect(subtitle.style, AppTextStyles.bodySmall);
    });
  });

  group('ProfileHeader', () {
    testWidgets('verified: green badge, check dot, no hint', (tester) async {
      await _pump(tester, ProfileHeader(user: _user(verified: true)));
      await tester.pumpAndSettle();

      expect(find.text('+976 8877 8899'), findsOneWidget);
      expect(find.text(kVerifiedLabel), findsOneWidget);
      expect(find.text(kUnverifiedLabel), findsNothing);
      expect(find.textContaining(kUnverifiedHint), findsNothing);
      expect(find.byKey(const ValueKey('profile-avatar-verified')),
          findsOneWidget);

      final chip = tester.widget<TagChip>(find.byType(TagChip));
      expect(chip.tone, TagTone.success);
    });

    testWidgets('unverified: neutral badge plus the verification hint',
        (tester) async {
      await _pump(tester, ProfileHeader(user: _user()));
      await tester.pumpAndSettle();

      expect(find.text(kUnverifiedLabel), findsOneWidget);
      expect(find.textContaining(kUnverifiedHint), findsOneWidget);
      expect(find.text(kVerifiedLabel), findsNothing);
      expect(
          find.byKey(const ValueKey('profile-avatar-verified')), findsNothing);

      final chip = tester.widget<TagChip>(find.byType(TagChip));
      expect(chip.tone, TagTone.neutral);
    });

    testWidgets('hint icon is inline, so it wraps with the first line',
        (tester) async {
      _setSurface(tester, const Size(320, 640));
      await _pump(tester, ProfileHeader(user: _user()), textScale: 1.3);
      await tester.pumpAndSettle();

      final hint = find.byKey(const ValueKey('profile-unverified-hint'));
      expect(
        find.descendant(
          of: hint,
          matching: find.byIcon(Icons.info_outline_rounded),
        ),
        findsOneWidget,
      );
      // The hint wraps at this size; the icon sits on its first line.
      final hintRect = tester.getRect(hint);
      final iconRect = tester.getRect(find.byIcon(Icons.info_outline_rounded));
      expect(hintRect.height, greaterThan(iconRect.height * 1.5));
      expect(iconRect.top - hintRect.top, lessThan(iconRect.height));
      expect(tester.takeException(), isNull);
    });

    testWidgets('avatar is a decorative person glyph', (tester) async {
      await _pump(tester, ProfileHeader(user: _user(phone: '99112205')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('profile-avatar-icon')), findsOneWidget);
      // No phone digits in the avatar (they read like a score).
      expect(find.text('05'), findsNothing);
      // Decorative: the phone number and badge below say it in words.
      expect(find.bySemanticsLabel(RegExp('Профайл зураг')), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ProfileAvatar),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
      expect(find.bySemanticsLabel(RegExp('9911 2205')), findsOneWidget);
    });
  });

  group('ProfileStatsRow', () {
    testWidgets('shows balance, age and city', (tester) async {
      await _pump(tester, ProfileStatsRow(user: _user()));
      await tester.pumpAndSettle();

      expect(find.text('3,400 ₮'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('Улаанбаатар'), findsOneWidget);
      expect(find.text('Үлдэгдэл'), findsOneWidget);
      expect(find.text('Нас'), findsOneWidget);
      expect(find.text('Хот'), findsOneWidget);
      expect(find.byType(CoinIcon), findsOneWidget);
    });

    testWidgets('balance does not count up from 0 when the tab opens',
        (tester) async {
      await _pump(tester, ProfileStatsRow(user: _user()));
      await tester.pump();
      expect(find.text('3,400 ₮'), findsOneWidget);
      expect(find.text('0 ₮'), findsNothing);
    });

    testWidgets('unknown age and city show a dash', (tester) async {
      await _pump(
        tester,
        ProfileStatsRow(user: _user(age: null, city: null, balance: 0)),
      );
      await tester.pumpAndSettle();

      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('0 ₮'), findsOneWidget);
    });

    testWidgets('balance tile opens the wallet when a callback is given',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        ProfileStatsRow(user: _user(), onBalanceTap: () => taps++),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(
        find.bySemanticsLabel(balanceSemantics(3400, opensWallet: true)),
        findsOneWidget,
      );
      await tester.tap(find.byType(ProfileBalanceTile));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('read-only balance tile has no chevron', (tester) async {
      await _pump(tester, ProfileStatsRow(user: _user()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.bySemanticsLabel(balanceSemantics(3400)), findsOneWidget);
    });

    testWidgets('stat tiles announce label then value', (tester) async {
      await _pump(tester, ProfileStatsRow(user: _user()));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Нас: 24'), findsOneWidget);
      expect(find.bySemanticsLabel('Хот: Улаанбаатар'), findsOneWidget);
    });

    testWidgets(
        'Нас and Хот render at the same size and height at 320pt, 1.3x text',
        (tester) async {
      _setSurface(tester, const Size(320, 640));
      await _pump(
        tester,
        ProfileStatsRow(user: _user(balance: 1234567, age: 7)),
        textScale: 1.3,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // getRect follows paint transforms, so a FittedBox shrinking one
      // value would show up here.
      final age = tester.getRect(find.text('7'));
      final city = tester.getRect(find.text('Улаанбаатар'));
      expect(age.height, closeTo(city.height, 0.01));

      final heights = tester
          .widgetList(find.byType(ProfileStatCard))
          .map((w) => tester.getSize(find.byWidget(w)).height)
          .toSet();
      expect(heights, hasLength(1));
    });

    testWidgets('the balance tile spans the full width', (tester) async {
      _setSurface(tester, const Size(375, 700));
      await _pump(tester, ProfileStatsRow(user: _user()));
      await tester.pumpAndSettle();

      final row = tester.getSize(find.byType(ProfileStatsRow)).width;
      expect(tester.getSize(find.byType(ProfileBalanceTile)).width, row);
      for (final card
          in tester.widgetList<ProfileStatCard>(find.byType(ProfileStatCard))) {
        expect(
          tester.getSize(find.byWidget(card)).width,
          lessThan(row / 2),
        );
      }
    });
  });

  group('PersonalInfoCard', () {
    testWidgets('lists gender, age, city and district', (tester) async {
      await _pump(
        tester,
        PersonalInfoCard(
          user: _user(gender: Gender.female, district: 'Сүхбаатар'),
        ),
      );
      expect(find.text('Эмэгтэй'), findsOneWidget);
      expect(find.text('Дүүрэг'), findsOneWidget);
      expect(find.text('Сүхбаатар'), findsOneWidget);
      expect(find.byType(ProfileDetailRow), findsNWidgets(4));
    });

    testWidgets('no district row and dashes for missing values',
        (tester) async {
      await _pump(
        tester,
        PersonalInfoCard(user: _user(gender: null, age: null, city: null)),
      );
      expect(find.text('Дүүрэг'), findsNothing);
      expect(find.text('—'), findsNWidgets(3));
      expect(find.byType(ProfileDetailRow), findsNWidgets(3));
    });
  });

  group('ProfileErrorBanner', () {
    Future<void> pumpBanner(
      WidgetTester tester, {
      required double width,
      double textScale = 1.0,
      VoidCallback? onRetry,
    }) {
      _setSurface(tester, Size(width + 40, 600));
      return _pump(
        tester,
        ProfileErrorBanner(message: kGenericLoadError, onRetry: onRetry),
        textScale: textScale,
      );
    }

    testWidgets('roomy: the kit banner with its inline action', (tester) async {
      var retries = 0;
      await pumpBanner(tester, width: 520, onRetry: () => retries++);

      expect(find.byKey(const ValueKey('profile-retry-stacked')), findsNothing);
      final banner = tester.widget<StatusBanner>(find.byType(StatusBanner));
      expect(banner.actionLabel, ProfileErrorBanner.retryLabel);

      await tester.tap(find.text(ProfileErrorBanner.retryLabel));
      await tester.pumpAndSettle();
      expect(retries, 1);
    });

    for (final (width, scale) in [(280.0, 1.3), (280.0, 1.0), (520.0, 1.3)]) {
      testWidgets('stacks the retry at ${width}pt, ${scale}x text',
          (tester) async {
        var retries = 0;
        await pumpBanner(
          tester,
          width: width,
          textScale: scale,
          onRetry: () => retries++,
        );
        expect(tester.takeException(), isNull);

        final banner = tester.widget<StatusBanner>(find.byType(StatusBanner));
        expect(banner.actionLabel, isNull);
        expect(
          find.byKey(const ValueKey('profile-retry-stacked')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('profile-retry-stacked')));
        await tester.pumpAndSettle();
        expect(retries, 1);
      });
    }

    testWidgets('without onRetry there is no action at all', (tester) async {
      await pumpBanner(tester, width: 280);
      expect(find.text(ProfileErrorBanner.retryLabel), findsNothing);
      expect(find.text(kGenericLoadError), findsOneWidget);
    });
  });

  group('ProfileBody', () {
    testWidgets('loading shows the skeleton and keeps logout available',
        (tester) async {
      await _pump(
        tester,
        ProfileBody(user: null, onLogout: () {}),
        reduceMotion: true,
      );
      await tester.pump();

      expect(find.byType(ProfileSkeleton), findsOneWidget);
      expect(find.byType(ProfileHeader), findsNothing);
      expect(find.byType(StatusBanner), findsNothing);
      expect(find.text('Гарах'), findsOneWidget);
      expect(find.text(ProfileTitle.title), findsOneWidget);
    });

    testWidgets('error without data: banner with retry, logout still there',
        (tester) async {
      var retries = 0;
      await _pump(
        tester,
        ProfileBody(
          user: null,
          error: 'Профайл ачаалж чадсангүй',
          onRetry: () => retries++,
          onLogout: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProfileSkeleton), findsNothing);
      expect(find.text('Профайл ачаалж чадсангүй'), findsOneWidget);
      expect(find.text('Гарах'), findsOneWidget);

      await tester.tap(find.text(ProfileErrorBanner.retryLabel));
      await tester.pumpAndSettle();
      expect(retries, 1);
    });

    testWidgets('loaded: header, stats, personal info and menu',
        (tester) async {
      await _pump(tester, ProfileBody(user: _user(), onLogout: () {}));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileHeader), findsOneWidget);
      expect(find.byType(ProfileStatsRow), findsOneWidget);
      expect(find.text('Хувийн мэдээлэл'), findsOneWidget);
      expect(find.text('Бусад'), findsOneWidget);
      expect(find.text('Үзсэн видеонуудын түүх'), findsOneWidget);
      expect(find.text('Нууцлалын бодлого'), findsOneWidget);
      expect(find.byType(StatusBanner), findsNothing);
    });

    testWidgets('balance tile forwards to onBalanceTap', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        ProfileBody(
          user: _user(),
          onLogout: () {},
          onBalanceTap: () => taps++,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ProfileBalanceTile));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('stale data keeps the content under the error banner',
        (tester) async {
      await _pump(
        tester,
        ProfileBody(
          user: _user(),
          error: kGenericLoadError,
          onRetry: () {},
          onLogout: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StatusBanner), findsOneWidget);
      expect(find.byType(ProfileHeader), findsOneWidget);
    });

    testWidgets('menu items show the coming-soon snackbar', (tester) async {
      await _pump(tester, ProfileBody(user: _user(), onLogout: () {}));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Нууцлалын бодлого'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Нууцлалын бодлого'));
      await tester.pump();
      expect(find.text(kComingSoon), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    });

    testWidgets('logout row calls onLogout, and is inert while logging out',
        (tester) async {
      var logouts = 0;
      await _pump(
          tester, ProfileBody(user: _user(), onLogout: () => logouts++));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Гарах'));
      await tester.tap(find.text('Гарах'));
      await tester.pumpAndSettle();
      expect(logouts, 1);

      await _pump(
        tester,
        ProfileBody(
          user: _user(),
          onLogout: () => logouts++,
          loggingOut: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.ensureVisible(find.text('Гарах'));
      await tester.tap(find.text('Гарах'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));
      expect(logouts, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    for (final verified in [false, true]) {
      testWidgets(
          'no overflow at 320pt wide with 1.3x text '
          '(${verified ? 'verified' : 'unverified'})', (tester) async {
        _setSurface(tester, const Size(320, 640));
        await _pump(
          tester,
          ProfileBody(
            user: _user(
              verified: verified,
              balance: 1234567,
              district: 'Сонгинохайрхан',
            ),
            onLogout: () {},
            onBalanceTap: () {},
          ),
          textScale: 1.3,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    for (final stale in [false, true]) {
      testWidgets(
          'error state has no overflow at 320pt wide with 1.3x text '
          '(${stale ? 'stale data' : 'no data'})', (tester) async {
        _setSurface(tester, const Size(320, 640));
        await _pump(
          tester,
          ProfileBody(
            user: stale ? _user(balance: 1234567) : null,
            error: kGenericLoadError,
            onRetry: () {},
            onLogout: () {},
          ),
          textScale: 1.3,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('profile-retry-stacked')),
          findsOneWidget,
        );
      });
    }

    testWidgets('error banner over stale data has no overflow at 320pt wide',
        (tester) async {
      _setSurface(tester, const Size(320, 640));
      await _pump(
        tester,
        ProfileBody(
          user: _user(balance: 1234567),
          error: kGenericLoadError,
          onRetry: () {},
          onLogout: () {},
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('skeleton has no overflow at 320pt wide with 1.3x text',
        (tester) async {
      _setSurface(tester, const Size(320, 640));
      await _pump(
        tester,
        ProfileBody(user: null, onLogout: () {}),
        reduceMotion: true,
        textScale: 1.3,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('showProfileSnackBar', () {
    Future<void> pumpTrigger(
      WidgetTester tester,
      void Function(BuildContext) show,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => show(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
    }

    testWidgets('coming soon: gold clock icon', (tester) async {
      await pumpTrigger(tester, showComingSoonSnackBar);

      expect(find.text(kComingSoon), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.schedule_rounded));
      expect(icon.color, AppColors.primary);
    });

    testWidgets('logout failed: same layout with a red error icon',
        (tester) async {
      await pumpTrigger(tester, showLogoutFailedSnackBar);

      expect(find.text(kLogoutFailed), findsOneWidget);
      final icon =
          tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded));
      expect(icon.color, AppColors.dangerLight);
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    });

    testWidgets('a second snackbar replaces the first', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => showComingSoonSnackBar(context),
                    child: const Text('a'),
                  ),
                  TextButton(
                    onPressed: () => showLogoutFailedSnackBar(context),
                    child: const Text('b'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('a'));
      await tester.pump();
      await tester.tap(find.text('b'));
      await tester.pumpAndSettle();
      expect(find.text(kComingSoon), findsNothing);
      expect(find.text(kLogoutFailed), findsOneWidget);
    });
  });

  group('showLogoutConfirmSheet', () {
    Future<List<bool>> openSheet(
      WidgetTester tester, {
      Size? size,
      double textScale = 1.0,
    }) async {
      if (size != null) _setSurface(tester, size);
      final results = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: app!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () async =>
                      results.add(await showLogoutConfirmSheet(context)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('confirm resolves to true', (tester) async {
      final results = await openSheet(tester);
      expect(find.text('Гарах уу?'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Гарах'));
      await tester.pumpAndSettle();
      expect(results, [true]);
      expect(find.text('Гарах уу?'), findsNothing);
    });

    testWidgets('cancel resolves to false', (tester) async {
      final results = await openSheet(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Болих'));
      await tester.pumpAndSettle();
      expect(results, [false]);
    });

    testWidgets('dismissing the sheet resolves to false', (tester) async {
      final results = await openSheet(tester);
      await tester.tapAt(const Offset(10, 10)); // the scrim
      await tester.pumpAndSettle();
      expect(results, [false]);
    });

    testWidgets('fits a small phone with 1.3x text', (tester) async {
      await openSheet(tester, size: const Size(320, 568), textScale: 1.3);
      expect(tester.takeException(), isNull);
      expect(find.text('Гарах уу?'), findsOneWidget);
    });
  });
}
