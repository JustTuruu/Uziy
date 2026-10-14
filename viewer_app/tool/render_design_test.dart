// Manual visual review: flutter test tool/render_design_test.dart
//   --dart-define=UI_PREVIEW_FONT=/absolute/path/to/a/Cyrillic/font.ttf
// Fixtures are local to this renderer; the app continues to use its API.
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/campaign.dart';
import 'package:viewer_app/models/user.dart';
import 'package:viewer_app/screens/auth/login_screen.dart';
import 'package:viewer_app/screens/home/feed_logic.dart';
import 'package:viewer_app/screens/home/feed_widgets.dart';
import 'package:viewer_app/screens/profile/profile_widgets.dart';
import 'package:viewer_app/screens/survey/survey_widgets.dart';
import 'package:viewer_app/screens/wallet/wallet_logic.dart';
import 'package:viewer_app/screens/wallet/wallet_widgets.dart';
import 'package:viewer_app/widgets/ui.dart';
import 'package:viewer_app/widgets/app_nav_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const fontPath = String.fromEnvironment('UI_PREVIEW_FONT');
  setUpAll(() async {
    if (fontPath.isEmpty) {
      throw StateError(
          'Supply UI_PREVIEW_FONT for readable Cyrillic previews.');
    }
    final bytes = File(fontPath).readAsBytesSync();
    await (FontLoader('Ahem')
          ..addFont(Future.value(ByteData.sublistView(bytes))))
        .load();
    await (FontLoader('Roboto')
          ..addFont(Future.value(ByteData.sublistView(bytes))))
        .load();
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final family in manifest) {
      final loader = FontLoader(family['family'] as String);
      for (final font in family['fonts'] as List) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  final campaigns = Campaign.mockFeed();
  const user = AppUser(
      id: 1,
      phoneNumber: '88112233',
      role: UserRole.viewer,
      balance: 12400,
      isVerified: true,
      age: 24,
      city: 'Улаанбаатар',
      gender: Gender.female);
  Widget page(List<Widget> children, {int tab = 0}) => Scaffold(
        extendBody: true,
        body: SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children),
        )),
        bottomNavigationBar:
            AppNavBar(currentIndex: tab, onTap: (_) {}, items: const [
          AppNavItem(icon: Icons.play_circle_outline_rounded, label: 'Нүүр'),
          AppNavItem(
              icon: Icons.account_balance_wallet_outlined, label: 'Хэтэвч'),
          AppNavItem(icon: Icons.person_outline_rounded, label: 'Профайл'),
        ]),
      );
  Map<String, Widget> screens(BuildContext context) => {
        'home': page([
          FeedHeader(
              now: DateTime(2026, 10, 13, 10),
              balance: 12400,
              onBalanceTap: () {}),
          const SizedBox(height: 20),
          EarningsHeroCard(summary: summarizeFeed(campaigns)),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Танд зориулсан'),
          const SizedBox(height: 16),
          FeedFilterBar(value: FeedFilter.all, onChanged: (_) {}),
          const SizedBox(height: 16),
          CampaignCard(campaign: campaigns.first, onTap: () {}),
        ]),
        'wallet': page([
          Text('Хэтэвч', style: context.textStyles.display),
          const SizedBox(height: 6),
          Text('Урамшууллаа цуглуулж, дансандаа татаарай',
              style: context.textStyles.bodySmall),
          const SizedBox(height: 24),
          WalletBalanceCard(
              balance: user.balance,
              verified: true,
              progress: payoutProgress(user.balance)),
          const SizedBox(height: 16),
          AppButton(
              label: 'Мөнгө татах',
              icon: Icons.account_balance_rounded,
              onPressed: () {}),
          const SizedBox(height: 32),
          const SectionHeader(title: 'Хэрхэн ажилладаг вэ'),
          const SizedBox(height: 12),
          const HowItWorksCard(),
        ], tab: 1),
        'profile': page([
          ProfileBody(
              user: user,
              onLogout: () {},
              onBalanceTap: () {},
              onHistoryTap: () {})
        ], tab: 2),
        'survey': Scaffold(
          appBar: AppBar(title: const Text('Судалгаа'), leading: const BackButton()),
          body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text('Асуулт 1 / 3',
                            style: context.textStyles.label)),
                    const RewardChip(amount: 700)
                  ]),
                  const SizedBox(height: 16),
                  const SegmentedProgress(total: 3, current: 0),
                  const SizedBox(height: 36),
                  Text('Та ямар төрлийн контент сонирхдог вэ?',
                      style: context.textStyles.displaySmall),
                  const SizedBox(height: 12),
                  Text('Өөрт хамгийн тохирох нэг хариултыг сонгоно уу.',
                      style: context.textStyles.bodySmall),
                  const SizedBox(height: 28),
                  for (final (index, label) in [
                    'Технологи, шинэ бүтээгдэхүүн',
                    'Аялал, чөлөөт цаг',
                    'Санхүү, өдөр тутмын хэрэглээ'
                  ].indexed) ...[
                    OptionTile(
                        label: label,
                        index: index,
                        selected: index == 0,
                        onTap: () {}),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 28),
                  AppButton(
                      label: 'Үргэлжлүүлэх',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () {}),
                ],
              )),
        ),
        'login': const LoginScreen(),
      };
  const dark = bool.fromEnvironment('UI_PREVIEW_DARK');
  for (final name in ['home', 'wallet', 'profile', 'survey', 'login']) {
    testWidgets('render $name', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      final theme = dark ? AppTheme.dark() : AppTheme.light();
      const styles = AppTypography(AppPalette(dark));
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
          appBarTheme: theme.appBarTheme.copyWith(
            titleTextStyle: styles.title.copyWith(fontFamily: 'Roboto'),
          ),
          textButtonTheme: TextButtonThemeData(
              style: theme.textButtonTheme.style!.copyWith(
            textStyle: WidgetStatePropertyAll(
                styles.label.copyWith(fontFamily: 'Roboto')),
          )),
        ),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: RepaintBoundary(
            key: key,
            child: Builder(builder: (context) => screens(context)[name]!)),
      ));
      await tester.runAsync(() => precacheImage(
          const AssetImage('assets/logo.png'), key.currentContext!));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output =
            File('build/design-preview/$name${dark ? '-dark' : ''}.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
