import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The "Incentivized Profiling" banner shown on registration.
/// Verbatim message required by the product spec — see docs/SPEC.md §4A.
class IncentiveBanner extends StatelessWidget {
  const IncentiveBanner({super.key});

  static const _message =
      'Та өөрийн нас, хүйс, байршлыг үнэн зөв оруулснаар өөрт тохирсон илүү '
      'олон, илүү өндөр дүнтэй видео судалгаануудыг хүлээн авч, орлогоо '
      'нэмэгдүүлэх боломжтой болно.';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.18),
            AppColors.primary.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.35)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('💡', style: TextStyle(fontSize: 22)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              _message,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
