import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/campaign.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_feed_screen.dart';
import '../screens/home/video_player_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/survey/survey_screen.dart';
import '../screens/wallet/payout_request_screen.dart';
import '../screens/wallet/wallet_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/app_nav_bar.dart';
import '../widgets/reels_icon.dart';

class Routes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const wallet = '/wallet';
  static const profile = '/profile';
  static const payout = '/wallet/payout';
  static const video = '/video'; // /video/:campaignId
  static const survey = '/survey'; // /survey/:campaignId
}

// --- Transition helpers -----------------------------------------------------

/// Bottom-nav tab: short fade + slight upward drift, run inside the shell's
/// nested Navigator.
Page<T> _tab<T>(Widget child, LocalKey key) => CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      transitionsBuilder: (context, animation, secondary, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.012),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

/// Subtle fade. Used for the splash → login handoff.
Page<T> _fade<T>(Widget child, LocalKey key) => CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondary, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          ),
          child: child,
        );
      },
    );

/// Slide up from the bottom — iOS "modal presentation" style. Used for the
/// video player and the survey flow.
Page<T> _modal<T>(Widget child, LocalKey key) => CustomTransitionPage<T>(
      key: key,
      child: child,
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );

/// Standard iOS push (slide from right + parallax back). Used for
/// login/register/payout — content that's part of a normal navigation stack.
Page<T> _cupertino<T>(Widget child, LocalKey key) =>
    CupertinoPage<T>(key: key, child: child);

// --- Router -----------------------------------------------------------------

final GoRouter appRouter = GoRouter(
  initialLocation: Routes.splash,
  routes: [
    GoRoute(
      path: Routes.splash,
      pageBuilder: (_, state) =>
          _fade(const SplashScreen(), state.pageKey),
    ),
    GoRoute(
      path: Routes.login,
      pageBuilder: (_, state) =>
          _fade(const LoginScreen(), state.pageKey),
    ),
    GoRoute(
      path: Routes.register,
      pageBuilder: (_, state) =>
          _cupertino(const RegisterScreen(), state.pageKey),
    ),
    ShellRoute(
      builder: (context, state, child) => _MainShell(child: child),
      routes: [
        GoRoute(
          path: Routes.home,
          pageBuilder: (_, state) =>
              _tab(const HomeFeedScreen(), state.pageKey),
        ),
        GoRoute(
          path: Routes.wallet,
          pageBuilder: (_, state) =>
              _tab(const WalletScreen(), state.pageKey),
        ),
        GoRoute(
          path: Routes.profile,
          pageBuilder: (_, state) =>
              _tab(const ProfileScreen(), state.pageKey),
        ),
      ],
    ),
    GoRoute(
      path: Routes.payout,
      pageBuilder: (_, state) =>
          _cupertino(const PayoutRequestScreen(), state.pageKey),
    ),
    GoRoute(
      path: '${Routes.video}/:campaignId',
      pageBuilder: (context, state) => _modal(
        VideoPlayerScreen(
          campaignId: state.pathParameters['campaignId']!,
          // Feed passes the Campaign via `extra` so we don't need a second
          // network call. Falls back to null for deep links.
          campaign: state.extra is Campaign ? state.extra as Campaign : null,
        ),
        state.pageKey,
      ),
    ),
    GoRoute(
      path: '${Routes.survey}/:campaignId',
      pageBuilder: (context, state) => _modal(
        SurveyScreen(
          campaignId: state.pathParameters['campaignId']!,
          campaign: state.extra is Campaign ? state.extra as Campaign : null,
        ),
        state.pageKey,
      ),
    ),
  ],
);

class _MainShell extends StatelessWidget {
  const _MainShell({required this.child});
  final Widget child;

  static const _tabs = [
    AppNavItem(
      glyphBuilder: ReelsIcon.glyph,
      label: 'Нүүр',
    ),
    AppNavItem(
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      label: 'Хэтэвч',
    ),
    AppNavItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Профайл',
    ),
  ];

  int _indexForLocation(String location) {
    if (location.startsWith(Routes.wallet)) return 1;
    if (location.startsWith(Routes.profile)) return 2;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(Routes.home);
        break;
      case 1:
        context.go(Routes.wallet);
        break;
      case 2:
        context.go(Routes.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexForLocation(location);

    return Scaffold(
      // Tab screens scroll underneath the floating glass nav bar; its height
      // is folded into MediaQuery.padding.bottom for them
      // (see AppLayout.scrollBottomPadding).
      extendBody: true,
      backgroundColor: AppColors.background,
      // `child` is the shell's Navigator (GlobalKey). It must not be wrapped
      // in an AnimatedSwitcher: that mounts it twice during the transition
      // and trips `_dependents.isEmpty`. Tab animation lives in [_tab].
      body: child,
      bottomNavigationBar: AppNavBar(
        currentIndex: index,
        onTap: (i) => _onTap(context, i),
        items: _tabs,
      ),
    );
  }
}
