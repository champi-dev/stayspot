import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stayspot/app/theme.dart';
import 'package:stayspot/features/auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (auth.status != AuthStatus.authenticated || auth.user == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_outline, size: 64, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                Text('Profile', style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 8),
                const Text(
                  'Log in to view your profile',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('Log in'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = auth.user!;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xxl),
              // Avatar
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.surface,
                child: Text(
                  user.firstName[0],
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user.fullName,
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Member since ${user.createdAt.year}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (user.isSuperhost) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.star.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 16, color: AppColors.star),
                      SizedBox(width: 4),
                      Text(
                        'Superhost',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB8860B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              // Settings list
              _buildSettingsItem(
                context,
                icon: Icons.person_outline,
                title: 'Personal info',
                onTap: () => context.push('/edit-profile'),
              ),
              _buildSettingsItem(
                context,
                icon: Icons.payment_outlined,
                title: 'Payments',
                subtitle: 'Demo only',
                onTap: () {},
              ),
              _buildSettingsItem(
                context,
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Demo only',
                onTap: () {},
              ),
              _buildSettingsItem(
                context,
                icon: Icons.help_outline,
                title: 'Help',
                onTap: () {},
              ),
              const SizedBox(height: AppSpacing.xxl),
              // Logout
              TextButton(
                onPressed: () {
                  ref.read(authProvider.notifier).logout();
                  context.go('/explore');
                },
                child: const Text(
                  'Log out',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const Text(
                'StaySpot v1.0.0',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: AppColors.textPrimary),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: subtitle != null
              ? Text(subtitle, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12))
              : null,
          trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          onTap: onTap,
        ),
        const Divider(),
      ],
    );
  }
}
