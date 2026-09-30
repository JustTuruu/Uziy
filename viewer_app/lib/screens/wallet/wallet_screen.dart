import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/user.dart';
import '../../routes/app_router.dart';
import '../../services/auth_service.dart';
import '../../services/viewer_service.dart';
import '../../widgets/ui.dart';
import 'wallet_logic.dart';
import 'wallet_widgets.dart';

/// Wallet tab: gold balance card, payout action (+ progress toward the
/// 1,000 ₮ minimum), how rewards work, and the transaction history area.
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
  String? _error;

  static const _unverifiedNote =
      'Эхний удаа мөнгө татахад админ дансны нэрийг таны бүртгэлтэй '
      'мэдээлэлтэй тулгаж баталгаажуулна.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await ViewerService.instance.me();
      if (!mounted) return;
      setState(() {
        _me = me;
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

  /// Retry from the error banner: clear the error (so the skeleton shows
  /// again while nothing is loaded yet) and reload.
  void _retry() {
    setState(() => _error = null);
    _load();
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
          onRefresh: _load,
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceElevated,
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
                    const SizedBox(height: AppSpacing.xxxl),
                    const FadeSlideIn(
                      index: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionHeader(title: 'Хэрхэн ажилладаг вэ'),
                          SizedBox(height: AppSpacing.md),
                          HowItWorksCard(),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    const FadeSlideIn(
                      index: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionHeader(title: 'Гүйлгээний түүх'),
                          EmptyState(
                            icon: Icons.receipt_long_rounded,
                            title: 'Одоогоор гүйлгээ алга',
                            message: 'Гүйлгээний түүх удахгүй энд харагдана.',
                          ),
                        ],
                      ),
                    ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: const Text('Хэтэвч', style: AppTextStyles.display),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Урамшууллаа цуглуулж, дансандаа татаарай',
          style: AppTextStyles.bodySmall,
        ),
      ],
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
              onPressed: canPayout ? () => context.push(Routes.payout) : null,
            ),
            if (!me.isVerified) ...[
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
