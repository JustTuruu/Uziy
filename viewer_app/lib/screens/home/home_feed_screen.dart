import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/campaign.dart';
import '../../models/user.dart';
import '../../routes/app_router.dart';
import '../../routes/auth_gate.dart';
import '../../services/auth_service.dart';
import '../../services/push/push_runtime.dart';
import '../../services/viewer_service.dart';
import '../../widgets/ui.dart';
import 'feed_logic.dart';
import 'feed_widgets.dart';
import 'guest_gate_sheet.dart';

/// Home tab: greeting + balance, earning-potential hero, kind filter and the
/// targeted campaign feed.
///
/// Tab-screen layout contract: this is a body inside the shell's Scaffold
/// (which uses `extendBody: true` and a floating nav bar), so it uses
/// `SafeArea(bottom: false)` and ends its scroll content with
/// [AppLayout.scrollBottomPadding].
class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  List<Campaign>? _feed;
  AppUser? _me;
  String? _error;

  /// Not signed in: a few sample cards, and tapping one asks to sign in.
  /// Fixed for this screen's life (signing in leaves it for a fresh one).
  final bool _guest = !AuthService.instance.isSignedIn;
  FeedFilter _filter = FeedFilter.all;

  /// True while a button-triggered reload (retry / 'Шинэчлэх') is running.
  bool _reloading = false;

  @override
  void initState() {
    super.initState();
    _load();
    // Logged in and on Home: the right moment for the notification prompt.
    if (!_guest) PushRuntime.instance.onHomeReached();
  }

  Future<void> _load() async {
    if (_guest) return _loadGuest();
    try {
      final results = await Future.wait([
        ViewerService.instance.feed(),
        ViewerService.instance.me(),
      ]);
      if (!mounted) return;
      setState(() {
        _feed = results[0] as List<Campaign>;
        _me = results[1] as AppUser;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401 || e.statusCode == 403) {
        await AuthService.instance.logout();
        if (!mounted) return;
        context.go(Routes.login);
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Сервертэй холбогдож чадсангүй');
    }
  }

  Future<void> _loadGuest() async {
    try {
      final feed = await ViewerService.instance.guestFeed();
      if (!mounted) return;
      setState(() {
        _feed = feed;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Сервертэй холбогдож чадсангүй');
    }
  }

  /// Button-driven reload. [clearError] hides the banner while retrying, so
  /// a feed that never loaded shows skeletons again instead of a stale
  /// error. The fetch itself is always [_load].
  Future<void> _reload({bool clearError = false}) async {
    if (_reloading) return;
    setState(() {
      _reloading = true;
      if (clearError) _error = null;
    });
    try {
      await _load();
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  void _openCampaign(Campaign c) {
    if (_guest) {
      _askToSignIn(next: campaignRoute(c));
      return;
    }
    // Survey-only campaigns skip the video player.
    context.push(campaignRoute(c), extra: c);
  }

  /// Guest tapped a campaign: offer register / login and bring them back to
  /// [next] once they are in.
  Future<void> _askToSignIn({required String next}) async {
    final choice = await showGuestGateSheet(context);
    if (choice == null || !mounted) return;
    final route = switch (choice) {
      GuestChoice.register => Routes.register,
      GuestChoice.login => Routes.login,
    };
    context.push(authLocation(route, next: next));
  }

  void _onFilterChanged(FeedFilter f) => setState(() => _filter = f);

  @override
  Widget build(BuildContext context) {
    final feed = _feed;
    final error = _error;
    final summary = feed == null ? null : summarizeFeed(feed);
    final showFilter = summary != null && shouldShowFilter(summary);
    final filter =
        summary == null ? FeedFilter.all : effectiveFilter(_filter, summary);
    final visible =
        feed == null ? const <Campaign>[] : filterFeed(feed, filter);
    final bottomPad = AppLayout.scrollBottomPadding(context);

    return AmbientBackground(
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Phone: 20pt gutters. Tablet / landscape: center a 560pt column.
            final gutter = math.max(
              AppLayout.screenPadding,
              (constraints.maxWidth - AppLayout.maxContentWidth) / 2,
            );
            EdgeInsets pad({double top = 0}) =>
                EdgeInsets.fromLTRB(gutter, top, gutter, 0);

            return RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceElevated,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    key: const ValueKey('feed-header'),
                    padding: pad(top: AppSpacing.md),
                    sliver: SliverToBoxAdapter(
                      child: FeedHeader(
                        now: DateTime.now(),
                        balance: _me?.balance,
                        guest: _guest,
                        // The guest pill is plain 'Нэвтрэх': straight to login.
                        onBalanceTap: _guest
                            ? () => context.push(Routes.login)
                            : () => context.go(Routes.wallet),
                      ),
                    ),
                  ),
                  if (error != null)
                    SliverPadding(
                      key: const ValueKey('feed-error'),
                      padding: pad(top: AppSpacing.xl),
                      sliver: SliverToBoxAdapter(
                        child: StatusBanner(
                          message: error,
                          actionLabel: 'Дахин оролдох',
                          onAction: () => _reload(clearError: true),
                        ),
                      ),
                    ),

                  // Loading: skeletons shaped like the real content.
                  if (feed == null && error == null)
                    SliverPadding(
                      key: const ValueKey('feed-loading'),
                      padding: pad(top: AppSpacing.xl),
                      sliver: const SliverToBoxAdapter(child: FeedSkeleton()),
                    ),

                  // Never loaded and failed: a calm illustration under the
                  // banner (the banner carries the retry).
                  if (feed == null && error != null)
                    SliverFillRemaining(
                      key: const ValueKey('feed-failed'),
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: bottomPad),
                        child: const Center(
                          child: EmptyState(
                            icon: Icons.cloud_off_rounded,
                            iconColor: AppColors.accent,
                            title: 'Одоогоор ачаалж чадсангүй',
                            message: 'Түр хүлээгээд дахин оролдоно уу.',
                          ),
                        ),
                      ),
                    ),

                  if (feed != null && feed.isEmpty)
                    SliverFillRemaining(
                      key: const ValueKey('feed-empty'),
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: bottomPad),
                        child: Center(
                          child: EmptyState(
                            icon: Icons.video_library_outlined,
                            title: 'Одоогоор видео алга байна',
                            message: 'Дараа дахин шалгаарай. Шинэ видео, '
                                'судалгаа нэмэгдэхэд энд харагдана.',
                            action: AppButton(
                              label: 'Шинэчлэх',
                              icon: Icons.refresh_rounded,
                              variant: AppButtonVariant.secondary,
                              expand: false,
                              loading: _reloading,
                              onPressed: _reload,
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (feed != null && feed.isNotEmpty) ...[
                    SliverPadding(
                      key: const ValueKey('feed-hero'),
                      padding: pad(top: AppSpacing.xl),
                      sliver: SliverToBoxAdapter(
                        child: FadeSlideIn(
                          child: EarningsHeroCard(summary: summary!),
                        ),
                      ),
                    ),
                    if (showFilter)
                      SliverPadding(
                        key: const ValueKey('feed-filter'),
                        padding: pad(top: AppSpacing.xl),
                        sliver: SliverToBoxAdapter(
                          child: FadeSlideIn(
                            index: 1,
                            child: FeedFilterBar(
                              value: filter,
                              onChanged: _onFilterChanged,
                            ),
                          ),
                        ),
                      ),
                    SliverPadding(
                      key: const ValueKey('feed-list'),
                      padding: pad(top: AppSpacing.lg),
                      // Keyed by filter: switching tabs remounts the list so
                      // the cards cascade in again.
                      sliver: SliverList.separated(
                        key: ValueKey('feed-list-${filter.name}'),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.lg),
                        itemBuilder: (context, i) {
                          final c = visible[i];
                          return FadeSlideIn(
                            key: ValueKey('campaign-${c.id}'),
                            index: i + 2,
                            child: CampaignCard(
                              campaign: c,
                              onTap: () => _openCampaign(c),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  if (feed != null ? feed.isNotEmpty : error == null)
                    SliverToBoxAdapter(
                      key: const ValueKey('feed-bottom'),
                      child: SizedBox(height: bottomPad),
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
