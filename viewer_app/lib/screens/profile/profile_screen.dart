import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_router.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: bind to logged-in user state.
    const phone = '+976 8811 2233';
    const city = 'Улаанбаатар';
    const gender = 'Эрэгтэй';
    const age = 24;
    const isVerified = false;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'З',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      phone,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isVerified
                              ? Icons.verified
                              : Icons.error_outline,
                          size: 14,
                          color: isVerified
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isVerified
                              ? 'Баталгаажсан'
                              : 'Баталгаажаагүй',
                          style: TextStyle(
                            color: isVerified
                                ? AppColors.success
                                : AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: const [
                _InfoRow(
                    icon: Icons.male, label: 'Хүйс', value: gender),
                Divider(height: 1),
                _InfoRow(
                    icon: Icons.cake_outlined, label: 'Нас', value: '$age'),
                Divider(height: 1),
                _InfoRow(
                    icon: Icons.location_city_outlined,
                    label: 'Хот',
                    value: city),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _MenuTile(
            icon: Icons.history,
            title: 'Үзсэн видеонуудын түүх',
            onTap: () {},
          ),
          _MenuTile(
            icon: Icons.help_outline,
            title: 'Тусламж / FAQ',
            onTap: () {},
          ),
          _MenuTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Нууцлалын бодлого',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _MenuTile(
            icon: Icons.logout,
            title: 'Гарах',
            danger: true,
            onTap: () => context.go(Routes.login),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(label,
          style: const TextStyle(color: AppColors.textSecondary)),
      trailing: Text(
        value,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
