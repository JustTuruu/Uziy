import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/payout_request.dart';
import '../../models/user.dart';
import '../../models/view_history_item.dart';
import '../../routes/app_router.dart';
import '../../services/auth_service.dart';
import '../../services/auto_refresher.dart';
import '../../services/viewer_service.dart';
import '../../widgets/ui.dart';
import 'wallet_logic.dart';
import 'wallet_widgets.dart';

/// Wallet tab: balance card, payout action (+ progress toward the 1,000 ₮
/// minimum) and the wallet history (rewards in, payouts out, each payout
/// with its status) right on the page.
///
/// Stays fresh on its own: reloads when the app returns to the foreground,
/// after the payout form closes and — while a request waits for the admin —
/// every [AutoRefresher.defaultInterval], so an approval shows up without a
/// manual pull-to-refresh.
///
/// A body inside the main shell (floating nav bar): no bottom SafeArea, the
/// scroll content ends with [AppLayout.scrollBottomPadding].
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  AppUser? _me;
  List<PayoutRequest>? _payouts;
  List<ViewHistoryItem>? _rewards;
  String? _error;
  late final AutoRefresher _refresher = AutoRefresher(onRefresh: _load);

  static const _unverifiedNote =
      'Эхний удаа мөнгө татахад дансны нэрийг таны бүртгэлтэй '
      'мэдээлэлтэй тулгаж баталгаажуулна.';

  @override
  void initState() {
    super.initState();
    _refresher.refresh();
  }

  @override
  void dispose() {
    _refresher.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ViewerService.instance.me(),
        _secondary(ViewerService.instance.myPayouts),
        _secondary(ViewerService.instance.history),
      ]);
      if (!mounted) return;
      final me = results[0] as AppUser;
      final payouts = results[1] as List<PayoutRequest>?;
      final rewards = results[2] as List<ViewHistoryItem>?;
      _announceDecisions(payouts);
      setState(() {
        _me = me;
        if (payouts != null) _payouts = payouts;
        if (rewards != null) _rewards = rewards;
        _error = null;
      });
      _refresher.polling = hasPendingPayout(_payouts ?? const []);
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

  /// The history lists are secondary: if one fails, keep what was shown
  /// last and still show the balance.
  Future<T?> _secondary<T>(Future<T> Function() load) async {
    try {
      return await load();
    } catch (_) {
      return null;
    }
  }

  /// A request that was waiting and is now decided gets a snack bar.
  void _announceDecisions(List<PayoutRequest>? payouts) {
    final before = _payouts;
    if (before == null || payouts == null) return;
    final decided = newlyDecided(before, payouts);
    if (decided.isEmpty) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      payoutDecisionSnackBar(decided.first, palette: context.colors),
    );
  }

  Future<void> _openPayoutForm() async {
    final me = _me;
    await context.push(
      Routes.payout,
      extra: me != null &&
          isBeforeFirstPayout(
            isVerified: me.isVerified,
            payouts: _payouts ?? const [],
          ),
    );
    if (mounted) await _refresher.refresh();
  }

  /// Retry from the error banner: clear the error (so the skeleton shows
  /// again while nothing is loaded yet) and reload.
  void _retry() {
    setState(() => _error = null);
    _refresher.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    final loading = me == null && _error == null;
    final width = MediaQuery.sizeOf(context).width;
    final gutter = math.max(
      AppLayout.screenPadding,
      (width - AppLayout.maxContentWidth) / 2,
    );

    return AmbientBackground(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresher.refresh,
          color: context.colors.primary,
          backgroundColor: context.colors.surfaceElevated,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  AppSpacing.md,
                  gutter,
                  AppLayout.scrollBottomPadding(context),
                ),
                sliver: SliverList.list(
                  children: [
                    FadeSlideIn(child: _header()),
                    const SizedBox(height: AppSpacing.xxl),
                    if (_error != null) ...[
                      StatusBanner(
                        message: _error!,
                        actionLabel: 'Дахин оролдох',
                        onAction: _retry,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (loading) const WalletCardSkeleton(),
                    if (me != null) ..._balanceSection(me),
                    if (me != null) ...[
                      const SizedBox(height: AppSpacing.xxxl),
                      FadeSlideIn(
                        index: 3,
                        child: WalletHistorySection(
                          rewards: _rewards ?? const [],
                          payouts: _payouts ?? const [],
                          now: DateTime.now(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Semantics(
      header: true,
      child: Text('Хэтэвч', style: context.textStyles.pageTitle),
    );
  }

  List<Widget> _balanceSection(AppUser me) {
    final canPayout = canRequestPayout(me.balance);
    return [
      FadeSlideIn(
        index: 1,
        child: WalletBalanceCard(
          balance: me.balance,
          verified: me.isVerified,
          phoneNumber: me.phoneNumber,
          holderName: walletCardName(
            lastName: me.lastName,
            firstName: me.firstName,
            payouts: _payouts ?? const [],
          ),
          progress: payoutProgress(me.balance),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      FadeSlideIn(
        index: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: 'Мөнгө татах',
              icon: Icons.account_balance_rounded,
              haptic: true,
              onPressed: canPayout ? _openPayoutForm : null,
            ),
            if (isBeforeFirstPayout(
              isVerified: me.isVerified,
              payouts: _payouts ?? const [],
            )) ...[
              const SizedBox(height: AppSpacing.md),
              const WalletNote(
                icon: Icons.verified_user_outlined,
                text: _unverifiedNote,
              ),
            ],
          ],
        ),
      ),
    ];
  }
}
