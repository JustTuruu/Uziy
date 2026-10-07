import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/ui.dart';

const String kGuestGateTitle = 'Та урамшууллыг өөрийг болгохын тулд';
const String kGuestGateMessage = 'Нэвтэх эсвэл Бүртгүүлэнэ үү.';
const String kGuestRegisterLabel = 'Бүртгүүлэх';
const String kGuestLoginLabel = 'Нэвтрэх';

/// Which door the guest picked in the sheet.
enum GuestChoice { register, login }

/// Asks a guest who tapped a campaign to register or sign in. Resolves to
/// the choice, or null when the sheet is dismissed.
///
/// Uses the root navigator so the sheet covers the floating tab bar.
Future<GuestChoice?> showGuestGateSheet(BuildContext context) {
  return showModalBottomSheet<GuestChoice>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const GuestGateSheet(),
  );
}

class GuestGateSheet extends StatelessWidget {
  const GuestGateSheet({super.key});

  void _pick(BuildContext context, GuestChoice choice) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.screenPadding,
        AppSpacing.sm,
        AppLayout.screenPadding,
        AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.28),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  AppIcons.watched,
                  size: 30,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: const Text(
              kGuestGateTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.headline,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            kGuestGateMessage,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: kGuestRegisterLabel,
            onPressed: () => _pick(context, GuestChoice.register),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: kGuestLoginLabel,
            variant: AppButtonVariant.secondary,
            onPressed: () => _pick(context, GuestChoice.login),
          ),
        ],
      ),
    );
  }
}
