import 'package:flutter/material.dart';

import '../../models/view_history_item.dart';
import '../../services/viewer_service.dart';
import '../../widgets/ui.dart';
import 'history_logic.dart';
import 'profile_logic.dart' show kGenericLoadError;
import 'profile_page_shell.dart';

/// Watch history: every completed video with its reward and time, newest
/// first, loaded from GET /viewer/history.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ViewHistoryItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ViewerService.instance.history();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = kGenericLoadError);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfilePageShell(
      title: kHistoryTitle,
      onRefresh: _load,
      children: [
        HistoryBody(
          items: _items,
          error: _error,
          onRetry: _load,
          now: DateTime.now(),
        ),
      ],
    );
  }
}

/// Presentational body of the history page: skeleton while [items] is null
/// and there is no [error], the error banner, the empty state or the list.
class HistoryBody extends StatelessWidget {
  const HistoryBody({
    super.key,
    required this.items,
    required this.error,
    required this.onRetry,
    required this.now,
  });

  final List<ViewHistoryItem>? items;
  final String? error;
  final VoidCallback onRetry;

  /// Reference time for 'Өнөөдөр' / 'Өчигдөр' labels.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final list = items;
    if (list == null) {
      return error == null
          ? const _HistorySkeleton()
          : StatusBanner(
              message: error!,
              actionLabel: 'Дахин оролдох',
              onAction: onRetry,
            );
    }
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.xxxl),
        child: EmptyState(
          icon: Icons.history_rounded,
          title: kHistoryEmptyTitle,
          message: kHistoryEmptyMessage,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HistorySummaryCard(count: list.length, total: historyTotalReward(list)),
        const SizedBox(height: AppSpacing.xxl),
        GroupedCard(
          children: [
            for (final item in list) HistoryRow(item: item, now: now),
          ],
        ),
      ],
    );
  }
}

/// Count of watched videos and the reward they paid in total.
class HistorySummaryCard extends StatelessWidget {
  const HistorySummaryCard(
      {super.key, required this.count, required this.total});

  final int count;
  final double total;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(child: _Stat(label: 'Үзсэн видео', value: '$count')),
          Expanded(
            child: _Stat(label: 'Нийт урамшуулал', value: formatTugrik(total)),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.title),
        ],
      ),
    );
  }
}

/// One watched video: title, company · day · time, and the reward paid.
class HistoryRow extends StatelessWidget {
  const HistoryRow({super.key, required this.item, required this.now});

  final ViewHistoryItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final when =
        '${historyDayLabel(item.watchedAt, now)} · ${historyTimeLabel(item.watchedAt)}';
    final subtitle =
        item.companyName.isEmpty ? when : '${item.companyName} · $when';
    return InfoRow(
      icon: Icons.play_circle_outline_rounded,
      iconColor: AppColors.accent,
      label: item.title,
      subtitle: subtitle,
      trailing: Text(
        formatTugrik(item.rewardPaid, withSign: true),
        style: AppTextStyles.body.copyWith(
          color: AppColors.success,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return const SkeletonShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Skeleton(height: 72, radius: AppRadii.lg),
          SizedBox(height: AppSpacing.xxl),
          Skeleton(height: 56, radius: AppRadii.lg),
          SizedBox(height: AppSpacing.sm),
          Skeleton(height: 56, radius: AppRadii.lg),
          SizedBox(height: AppSpacing.sm),
          Skeleton(height: 56, radius: AppRadii.lg),
        ],
      ),
    );
  }
}
