import 'package:flutter/material.dart';

import '../../widgets/stats_consent.dart';
import '../../widgets/ui.dart';
import 'privacy_content.dart';
import 'profile_page_shell.dart';

/// Privacy-policy page: an intro banner followed by titled sections.
///
/// The anonymous-statistics switch lives here, under its own section (owner,
/// 2026-10-21: off the Profile list). The consent must stay revocable, and
/// this is the place the policy points to (nobody is asked elsewhere since
/// 2026-10-21).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({
    super.key,
    this.statsApi = const ViewerStatisticsConsentApi(),
  });

  final StatisticsConsentApi statsApi;

  @override
  Widget build(BuildContext context) {
    return ProfilePageShell(
      title: kPrivacyTitle,
      children: [
        const PrivacyIntroCard(),
        for (final section in kPrivacySections) ...[
          const SizedBox(height: AppSpacing.xxl),
          PolicySectionView(section: section),
          if (section.heading == kStatsSectionHeading) ...[
            const SizedBox(height: AppSpacing.md),
            GroupedCard(children: [StatsConsentTile(api: statsApi)]),
          ],
        ],
      ],
    );
  }
}

/// Hero of the page: gold shield medallion, a short headline and the promise
/// in secondary text. Centred so it reads as a header, not as an alert.
class PrivacyIntroCard extends StatelessWidget {
  const PrivacyIntroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.primary.withValues(alpha: 0.12),
                border: Border.all(
                  color: context.colors.primary.withValues(alpha: 0.28),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                AppIcons.privacy,
                size: 30,
                color: context.colors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            kPrivacyIntroTitle,
            textAlign: TextAlign.center,
            style: context.textStyles.title,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            kPrivacyIntro,
            textAlign: TextAlign.center,
            style: context.textStyles.body
                .copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class PolicySectionView extends StatelessWidget {
  const PolicySectionView({super.key, required this.section});

  final PolicySection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: section.heading,
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
        ),
        AppCard(
          child: Text(
            section.body,
            style: context.textStyles.body
                .copyWith(color: context.colors.textSecondary),
          ),
        ),
      ],
    );
  }
}
