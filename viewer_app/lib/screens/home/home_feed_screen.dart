import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/campaign.dart';
import '../../models/user.dart';
import '../../routes/app_router.dart';
import '../../services/auth_service.dart';
import '../../services/viewer_service.dart';
import '../../widgets/ui.dart';
import 'feed_logic.dart';
import 'feed_widgets.dart';

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
  FeedFilter _filter = FeedFilter.all;

  /// True while a button-triggered reload (retry / 'Шинэчлэх') is running.
  bool _reloading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
    // Survey-only campaigns skip the video player.
    final target =
        c.hasVideo ? '${Routes.video}/${c.id}' : '${Routes.survey}/${c.id}';
    context.push(target, extra: c);
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
                        onBalanceTap: () => context.go(Routes.wallet),
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
                            title: 'Танд тохирсон видео түр байхгүй байна',
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
