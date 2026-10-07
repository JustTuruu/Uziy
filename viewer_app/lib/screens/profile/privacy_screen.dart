import 'package:flutter/material.dart';

import '../../widgets/ui.dart';
import 'privacy_content.dart';
import 'profile_page_shell.dart';

/// Privacy-policy page: an intro banner followed by titled sections.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfilePageShell(
      title: kPrivacyTitle,
      children: [
        const StatusBanner(
          tone: BannerTone.info,
          icon: Icons.privacy_tip_outlined,
          message: kPrivacyIntro,
        ),
        for (final section in kPrivacySections) ...[
          const SizedBox(height: AppSpacing.xxl),
          PolicySectionView(section: section),
        ],
      ],
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
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
