import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/user.dart';
import '../../routes/app_router.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/viewer_service.dart';
import '../../widgets/ui.dart';
import 'profile_logic.dart';
import 'profile_widgets.dart';

/// Profile tab: loads the signed-in viewer from GET /viewer/me and renders
/// it with the presentational widgets in profile_widgets.dart. The load and
/// logout sequencing lives in profile_logic.dart (unit tested); this class
/// only turns the results into setState and navigation.
///
/// Tab-screen layout contract: no own Scaffold, no bottom SafeArea; the
/// scroll content ends with AppLayout.scrollBottomPadding so the last row
/// clears the floating nav bar.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Last profile of the current session. The shell rebuilds this screen
  /// on every tab switch; seeding from here skips the skeleton flash while
  /// the fresh request runs. Keyed by the auth header, so another account
  /// signing in never sees it.
  static final SessionCache<AppUser> _cache = SessionCache<AppUser>();

  static String? get _sessionKey =>
      ApiService.instance.dio.options.headers['Authorization'] as String?;

  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  final _loadFlight = SingleFlight<void>();

  AppUser? _me;
  String? _error;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _me = _cache.read(_sessionKey);
    _load();
  }

  /// Pull-to-refresh, retry and the initial load share one request.
  Future<void> _load() => _loadFlight.run(_fetch);

  Future<void> _fetch() async {
    final session = _sessionKey;
    final result = await loadProfile(
      fetch: ViewerService.instance.me,
      clearToken: () async {
        // Same as before: only an on-screen profile clears the session.
        if (mounted) await AuthService.instance.logout();
      },
    );
    switch (result) {
      case ProfileLoaded(:final user):
        _cache.write(session, user);
        if (!mounted) return;
        setState(() {
          _me = user;
          _error = null;
        });
      case ProfileSessionExpired():
        _cache.clear();
        if (!mounted) return;
        context.go(Routes.login);
      case ProfileLoadFailed(:final message):
        if (!mounted) return;
        setState(() => _error = message);
    }
  }

  /// Retry from the error banner. Runs through the RefreshIndicator so the
  /// gold spinner shows while the request is in flight; the banner stays
  /// until the result is in, so a second failure is visibly a new attempt.
  void _retry() {
    final indicator = _refreshKey.currentState;
    if (indicator != null) {
      indicator.show();
    } else {
      _load();
    }
  }

  Future<void> _confirmLogout() async {
    if (_loggingOut) return;
    HapticFeedback.selectionClick();
    final result = await runLogout(
      confirm: () async => await showLogoutConfirmSheet(context) && mounted,
      clearToken: () async {
        setState(() => _loggingOut = true);
        // Clear the stored token BEFORE leaving, so the next launch does
        // not silently sign the user back in.
        await AuthService.instance.logout();
      },
    );
    switch (result) {
      case LogoutResult.cancelled:
        return;
      case LogoutResult.failed:
        if (!mounted) return;
        setState(() => _loggingOut = false);
        showLogoutFailedSnackBar(context);
      case LogoutResult.done:
        _cache.clear();
        if (!mounted) return;
        context.go(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AmbientBackground(
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Center the column on tablets / landscape.
            final side = math.max(
              AppLayout.screenPadding,
              (constraints.maxWidth - AppLayout.maxContentWidth) / 2,
            );
            return RefreshIndicator(
              key: _refreshKey,
              onRefresh: _load,
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceElevated,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  side,
                  AppSpacing.md,
                  side,
                  AppLayout.scrollBottomPadding(context),
                ),
                children: [
                  ProfileBody(
                    user: _me,
                    error: _error,
                    onRetry: _retry,
                    onLogout: _confirmLogout,
                    onBalanceTap: () => context.go(Routes.wallet),
                    onHistoryTap: () => context.push(Routes.history),
                    onHelpTap: () => context.push(Routes.help),
                    onPrivacyTap: () => context.push(Routes.privacy),
                    loggingOut: _loggingOut,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
