import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/ui.dart';

/// Frame shared by the pages pushed from the profile menu (history, help,
/// privacy): ambient background, transparent app bar with [title], and a
/// centred, max-width content column that scrolls.
///
/// Pattern: Template Method (by composition) — pages supply only the body
/// [children]; the frame is written once.
class ProfilePageShell extends StatelessWidget {
  const ProfilePageShell({
    super.key,
    required this.title,
    required this.children,
    this.onRefresh,
  });

  final String title;
  final List<Widget> children;

  /// When set the list supports pull-to-refresh.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = math.max(
      AppLayout.screenPadding,
      (width - AppLayout.maxContentWidth) / 2,
    );
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        gutter,
        AppSpacing.sm,
        gutter,
        AppSpacing.xxl,
      ),
      children: children,
    );
    final refresh = onRefresh;

    return AmbientBackground(
      variant: AmbientVariant.subtle,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(title),
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: refresh == null
              ? list
              : RefreshIndicator(
                  onRefresh: refresh,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surfaceElevated,
                  child: list,
                ),
        ),
      ),
    );
  }
}
