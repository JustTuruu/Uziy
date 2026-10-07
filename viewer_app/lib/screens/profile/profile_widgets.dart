import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/user.dart';
import '../../widgets/ui.dart';
import 'profile_logic.dart';

// Presentational pieces of the profile tab. Nothing here imports the router:
// navigation (logout -> login, balance -> wallet) is passed in as callbacks
// by ProfileScreen.

/// Themed floating snackbar used by the profile tab: a tinted icon plus the
/// [message]. Replaces any snackbar already showing.
void showProfileSnackBar(
  BuildContext context,
  String message, {
  IconData icon = Icons.schedule_rounded,
  Color color = AppColors.primary,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Logout could not clear the stored token; the user stays signed in.
void showLogoutFailedSnackBar(BuildContext context) => showProfileSnackBar(
      context,
      kLogoutFailed,
      icon: Icons.error_outline_rounded,
      color: AppColors.dangerLight,
    );

/// Opens the logout confirmation sheet. Resolves to true only when the user
/// taps 'Гарах'; dismissing the sheet or tapping 'Болих' gives false.
///
/// Uses the root navigator so the sheet covers the floating tab bar.
Future<bool> showLogoutConfirmSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const LogoutConfirmSheet(),
  );
  return result ?? false;
}

/// Body of the logout confirmation sheet.
class LogoutConfirmSheet extends StatelessWidget {
  const LogoutConfirmSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xs,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.danger.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.30),
                  ),
                  boxShadow: AppShadows.glow(
                    AppColors.danger,
                    strength: 0.35,
                    blur: 24,
                    offset: const Offset(0, 6),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  AppIcons.logout,
                  size: 30,
                  color: AppColors.dangerLight,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              header: true,
              child: const Text(
                'Гарах уу?',
                textAlign: TextAlign.center,
                style: AppTextStyles.headline,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Та дахин нэвтрэхдээ утасны дугаар, нууц үгээ оруулна.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Гарах',
              icon: AppIcons.logout,
              variant: AppButtonVariant.danger,
              haptic: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Болих',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab title plus a one-line subtitle, sized like the home and wallet tab
/// headers so switching tabs does not make the title jump.
class ProfileTitle extends StatelessWidget {
  const ProfileTitle({super.key});

  static const String title = 'Профайл';
  static const String subtitle = 'Таны бүртгэл, хувийн мэдээлэл';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: const Text(title, style: AppTextStyles.display),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(subtitle, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

/// Gold gradient ring around a dark disc with a gold person glyph. A small
/// green check sits on the ring when the account is verified.
///
/// Decorative for screen readers: the phone number and the verification
/// badge right below it say the same thing in words.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.verified = false, this.size = 96});

  final bool verified;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ring = size * 0.035; // gold ring thickness
    final gap = size * 0.035; // dark gap between ring and disc

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.gold,
                  boxShadow: AppShadows.glow(
                    AppColors.primary,
                    strength: 0.45,
                    blur: size * 0.34,
                    offset: Offset(0, size * 0.04),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(ring),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.background,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(gap),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: Alignment(-0.35, -0.55),
                            radius: 1.1,
                            colors: [
                              AppColors.surfaceHighlight,
                              AppColors.surface,
                            ],
                          ),
                        ),
                        child: Center(
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: AppGradients.gold.createShader,
                            child: Icon(
                              AppIcons.user,
                              key: const ValueKey('profile-avatar-icon'),
                              size: size * 0.5,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (verified)
              Positioned(
                right: 0,
                bottom: size * 0.02,
                child: Container(
                  key: const ValueKey('profile-avatar-verified'),
                  width: size * 0.28,
                  height: size * 0.28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppGradients.success,
                    border: Border.all(
                      color: AppColors.background,
                      width: size * 0.03,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    AppIcons.check,
                    size: size * 0.16,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 'Баталгаажсан' (green) or 'Баталгаажаагүй' (neutral) pill.
class VerificationBadge extends StatelessWidget {
  const VerificationBadge({super.key, required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    return verified
        ? const TagChip(
            label: kVerifiedLabel,
            icon: AppIcons.verified,
            tone: TagTone.success,
          )
        : const TagChip(
            label: kUnverifiedLabel,
            icon: AppIcons.unverified,
          );
  }
}

/// Hero card: avatar, formatted phone number, verification badge and, when
/// not verified yet, a short hint on how verification happens.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.user});

  final AppUser user;

  static const EdgeInsets padding = EdgeInsets.fromLTRB(
    AppSpacing.xl,
    AppSpacing.xxxl,
    AppSpacing.xl,
    AppSpacing.xxl,
  );

  @override
  Widget build(BuildContext context) {
    final verified = user.isVerified;
    final hintStyle = AppTextStyles.caption.copyWith(
      color: AppColors.textTertiary,
    );
    return AppCard(
      padding: padding,
      // Gold aura behind the avatar, fading into the card surface.
      gradient: RadialGradient(
        center: const Alignment(0, -1.15),
        radius: 1.1,
        colors: [
          Color.alphaBlend(
            AppColors.primary.withValues(alpha: 0.14),
            AppColors.surface,
          ),
          AppColors.surface,
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProfileAvatar(verified: verified),
          const SizedBox(height: AppSpacing.lg),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              phoneLabel(user.phoneNumber),
              maxLines: 1,
              style: AppTextStyles.headline.copyWith(
                fontFeatures: AppTextStyles.tabular,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          VerificationBadge(verified: verified),
          if (!verified) ...[
            const SizedBox(height: AppSpacing.md),
            // Icon as an inline span, so it stays with the first line when
            // the hint wraps (small phone, large text).
            Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: ExcludeSemantics(
                      child: Icon(
                        AppIcons.hint,
                        size: 15,
                        color: hintStyle.color,
                      ),
                    ),
                  ),
                  const TextSpan(text: '  $kUnverifiedHint'),
                ],
              ),
              key: const ValueKey('profile-unverified-hint'),
              textAlign: TextAlign.center,
              style: hintStyle,
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-width balance tile at the top of the stats bento: coin, caption and
/// the balance in headline size. With [onTap] it opens the wallet, like the
/// balance pill on the home tab.
class ProfileBalanceTile extends StatelessWidget {
  const ProfileBalanceTile({super.key, required this.balance, this.onTap});

  final double balance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: AppRadii.lg,
      gradient: AppGradients.goldSoft,
      borderColor: AppColors.primary.withValues(alpha: 0.26),
      child: Row(
        children: [
          const CoinIcon(size: 44),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Үлдэгдэл',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSpacing.xxs),
                // One value in the tile, so scaling a huge balance down to
                // fit cannot make it disagree with a neighbour.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: AnimatedMoney(
                    value: balance,
                    style: AppTextStyles.headline,
                    // The home and wallet tabs already play the count-up;
                    // here it only animates when a refresh changes it.
                    animateOnMount: false,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              AppIcons.chevron,
              color: AppColors.textSecondary,
            ),
          ],
        ],
      ),
    );

    final tap = onTap;
    if (tap == null) {
      return Semantics(
        label: balanceSemantics(balance),
        excludeSemantics: true,
        child: card,
      );
    }
    return Pressable(
      onTap: tap,
      haptic: true,
      scale: 0.98,
      semanticLabel: balanceSemantics(balance, opensWallet: true),
      excludeSemantics: true,
      child: card,
    );
  }
}

/// Half-width stat tile: leading badge, value, caption label. Every tile
/// renders its value in the same style (one line, ellipsized), so side by
/// side tiles always agree in size.
class ProfileStatCard extends StatelessWidget {
  const ProfileStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.leading,
  });

  final String label;
  final String value;
  final Widget leading;

  static final TextStyle valueStyle = AppTextStyles.title.copyWith(
    fontFeatures: AppTextStyles.tabular,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: statSemantics(label, value),
      excludeSemantics: true,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        radius: AppRadii.lg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(height: AppSpacing.md),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: valueStyle,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}

/// Round tinted icon badge used by the stat tiles.
class _StatIcon extends StatelessWidget {
  const _StatIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.16),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 17, color: color),
    );
  }
}

/// Stats bento: a full-width Үлдэгдэл tile over two half-width tiles
/// (Нас, Хот), with '—' for unknown values.
class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({super.key, required this.user, this.onBalanceTap});

  final AppUser user;

  /// Opens the wallet; null leaves the balance tile read-only.
  final VoidCallback? onBalanceTap;

  static const double gap = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileBalanceTile(balance: user.balance, onTap: onBalanceTap),
        const SizedBox(height: gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ProfileStatCard(
                label: 'Нас',
                value: ageLabel(user.age),
                leading: const _StatIcon(
                  icon: AppIcons.age,
                  color: AppColors.violet,
                ),
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: ProfileStatCard(
                label: 'Хот',
                value: displayOrDash(user.city),
                leading: const _StatIcon(
                  icon: AppIcons.district,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

IconData _iconFor(ProfileFieldKind kind, Gender? gender) => switch (kind) {
      ProfileFieldKind.gender => switch (gender) {
          Gender.male => AppIcons.male,
          Gender.female => AppIcons.female,
          null => AppIcons.genderUnknown,
        },
      ProfileFieldKind.age => AppIcons.age,
      ProfileFieldKind.city => AppIcons.city,
      ProfileFieldKind.district => AppIcons.district,
    };

/// 'Хувийн мэдээлэл' card: Хүйс, Нас, Хот (+ Дүүрэг when present).
class PersonalInfoCard extends StatelessWidget {
  const PersonalInfoCard({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return GroupedCard(
      children: [
        for (final f in personalFields(user))
          ProfileDetailRow(
            icon: _iconFor(f.kind, user.gender),
            label: f.label,
            value: f.value,
          ),
      ],
    );
  }
}

/// Read-only label/value row styled like [InfoRow], but the value gets all
/// the width the (short) label leaves, so 'Улаанбаатар' is not truncated
/// on a 320pt phone.
class ProfileDetailRow extends StatelessWidget {
  const ProfileDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Labels are one short word; this cap only matters at huge text sizes.
  static const double maxLabelWidth = 140;

  /// Same metrics as the kit's [InfoRow] (vertical padding 10, icon tile
  /// radius 10), so these rows line up with the 'Бусад' menu rows at every
  /// text size. Deliberately not rounded to the 4pt grid.
  static const double _verticalPadding = 10;
  static const double _iconTileRadius = 10;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: _verticalPadding,
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(_iconTileRadius),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 20, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxLabelWidth),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Load-error banner with a retry action. Beside the message on roomy
/// layouts (the kit's inline action); on a small phone or with large text
/// the action moves to its own full-width button under the message, so the
/// message keeps a readable width and nothing overflows.
class ProfileErrorBanner extends StatelessWidget {
  const ProfileErrorBanner({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  static const String retryLabel = 'Дахин оролдох';

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;
    if (retry == null) return StatusBanner(message: message);
    return LayoutBuilder(
      builder: (context, box) {
        final textScale = MediaQuery.textScalerOf(context).scale(100) / 100;
        if (!stackRetryAction(width: box.maxWidth, textScale: textScale)) {
          return StatusBanner(
            message: message,
            actionLabel: retryLabel,
            onAction: retry,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBanner(message: message),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              key: const ValueKey('profile-retry-stacked'),
              label: retryLabel,
              icon: AppIcons.retry,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              haptic: true,
              onPressed: retry,
            ),
          ],
        );
      },
    );
  }
}

/// Loading placeholder shaped like the header, the stats bento and the
/// info card.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonShimmer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            padding: ProfileHeader.padding,
            child: Column(
              children: [
                Skeleton(width: 96, height: 96, radius: 48),
                SizedBox(height: AppSpacing.lg),
                Skeleton(width: 180, height: 28),
                SizedBox(height: AppSpacing.sm),
                Skeleton(width: 120, height: 24, radius: AppRadii.pill),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md),
          Skeleton(height: 80, radius: AppRadii.lg),
          SizedBox(height: ProfileStatsRow.gap),
          Row(
            children: [
              Expanded(child: Skeleton(height: 100, radius: AppRadii.lg)),
              SizedBox(width: ProfileStatsRow.gap),
              Expanded(child: Skeleton(height: 100, radius: AppRadii.lg)),
            ],
          ),
          SizedBox(height: ProfileBody.sectionGap),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Skeleton(width: 150, height: 18),
          ),
          SizedBox(height: AppSpacing.md),
          Skeleton(height: 56.0 * 3, radius: AppRadii.lg),
        ],
      ),
    );
  }
}

/// The whole profile tab content (not scrollable; the screen puts it in a
/// pull-to-refresh list).
///
/// * `user == null && error == null` -> loading skeleton.
/// * `user == null && error != null` -> error banner with retry.
/// * `user != null && error != null` -> banner above the stale data.
///
/// The 'Бусад' menu and 'Гарах' stay available in every state, so the user
/// can always log out even when the profile fails to load.
class ProfileBody extends StatelessWidget {
  const ProfileBody({
    super.key,
    required this.user,
    required this.onLogout,
    this.error,
    this.onRetry,
    this.onBalanceTap,
    this.onHistoryTap,
    this.onHelpTap,
    this.onPrivacyTap,
    this.loggingOut = false,
  });

  final AppUser? user;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback onLogout;

  /// Opens the wallet from the balance tile.
  final VoidCallback? onBalanceTap;

  /// Open the pages behind the 'Бусад' menu rows.
  final VoidCallback? onHistoryTap;
  final VoidCallback? onHelpTap;
  final VoidCallback? onPrivacyTap;

  /// While true the logout row shows a spinner and ignores taps.
  final bool loggingOut;

  /// Gap between titled sections (same as the wallet tab).
  static const double sectionGap = AppSpacing.xxxl;

  /// Gap between the tab title and the first content block.
  static const double titleGap = AppSpacing.xxl;

  /// Menu-row tap: a light haptic, then [open].
  VoidCallback? _menuTap(VoidCallback? open) {
    if (open == null) return null;
    return () {
      HapticFeedback.selectionClick();
      open();
    };
  }

  Widget _section({
    required Key key,
    required int index,
    required Widget child,
    double top = 0,
  }) {
    return FadeSlideIn(
      key: key,
      index: index,
      child: Padding(padding: EdgeInsets.only(top: top), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = user;
    final loading = u == null && error == null;
    const sectionHeaderPadding = EdgeInsets.only(
      left: AppSpacing.xs,
      bottom: AppSpacing.md,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(
          key: const ValueKey('profile-title'),
          index: 0,
          child: const ProfileTitle(),
        ),
        if (error != null)
          _section(
            key: const ValueKey('profile-error'),
            index: 1,
            top: titleGap,
            child: ProfileErrorBanner(message: error!, onRetry: onRetry),
          ),
        if (loading)
          const Padding(
            key: ValueKey('profile-skeleton'),
            padding: EdgeInsets.only(top: titleGap),
            child: ProfileSkeleton(),
          ),
        if (u != null) ...[
          _section(
            key: const ValueKey('profile-header'),
            index: 1,
            top: error != null ? AppSpacing.lg : titleGap,
            child: ProfileHeader(user: u),
          ),
          _section(
            key: const ValueKey('profile-stats'),
            index: 2,
            top: AppSpacing.md,
            child: ProfileStatsRow(user: u, onBalanceTap: onBalanceTap),
          ),
          _section(
            key: const ValueKey('profile-personal'),
            index: 3,
            top: sectionGap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(
                  title: 'Хувийн мэдээлэл',
                  padding: sectionHeaderPadding,
                ),
                PersonalInfoCard(user: u),
              ],
            ),
          ),
        ],
        _section(
          key: const ValueKey('profile-other'),
          index: 4,
          top: sectionGap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                title: 'Бусад',
                padding: sectionHeaderPadding,
              ),
              GroupedCard(
                children: [
                  InfoRow(
                    icon: AppIcons.history,
                    iconColor: AppColors.accent,
                    label: 'Үзсэн видеонуудын түүх',
                    onTap: _menuTap(onHistoryTap),
                  ),
                  InfoRow(
                    icon: AppIcons.help,
                    iconColor: AppColors.violet,
                    label: 'Тусламж',
                    subtitle: 'Түгээмэл асуулт, хариулт',
                    onTap: _menuTap(onHelpTap),
                  ),
                  InfoRow(
                    icon: AppIcons.privacy,
                    iconColor: AppColors.success,
                    label: 'Нууцлалын бодлого',
                    onTap: _menuTap(onPrivacyTap),
                  ),
                ],
              ),
            ],
          ),
        ),
        _section(
          key: const ValueKey('profile-logout'),
          index: 5,
          top: AppSpacing.lg,
          child: GroupedCard(
            children: [
              InfoRow(
                icon: AppIcons.logout,
                label: 'Гарах',
                danger: true,
                onTap: loggingOut ? null : onLogout,
                trailing: loggingOut
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor:
                              AlwaysStoppedAnimation(AppColors.dangerLight),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
