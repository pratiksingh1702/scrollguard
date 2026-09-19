import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:scrollguard/core/models/guard_models.dart';
import 'package:scrollguard/core/providers/guard_providers.dart';

class PermissionsScreen extends ConsumerWidget {
  const PermissionsScreen({super.key});

  Future<void> _showOemGuideSheet(BuildContext context) async {
    try {
      final jsonStr = await rootBundle.loadString('assets/oem_guides.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final oems = (data['oems'] as List<dynamic>?) ?? [];

      if (!context.mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          final theme = Theme.of(ctx);
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            expand: false,
            builder: (_, scrollController) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'OEM Background Survival Guide',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Many Android manufacturers aggressively kill background apps. '
                      'Follow the steps for your device brand to ensure ScrollGuard remains active:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: oems.length,
                        itemBuilder: (ctx, idx) {
                          final oem = oems[idx] as Map<String, dynamic>;
                          final name = oem['name'] as String;
                          final steps = (oem['steps'] as List<dynamic>?) ?? [];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...steps.map((s) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 3,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('• '),
                                            Expanded(
                                              child: Text(
                                                s as String,
                                                style:
                                                    theme.textTheme.bodyMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } on Exception catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load OEM guides.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bridge = ref.watch(nativeBridgeProvider);
    final guardStatusAsync = ref.watch(guardStatusProvider);
    final status = guardStatusAsync.value ?? const GuardStatus();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions Checklist'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enable Protection',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ScrollGuard needs these permissions to detect short-video feeds '
                'and keep running reliably.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _buildPermissionTile(
                      theme: theme,
                      title: 'Accessibility Service',
                      subtitle: 'Required to detect short-video containers (Shorts/Reels).',
                      isGranted: status.isAccessibilityServiceEnabled,
                      isRequired: true,
                      onTap: bridge.openAccessibilitySettings,
                    ),
                    const SizedBox(height: 12),
                    _buildPermissionTile(
                      theme: theme,
                      title: 'Usage Access',
                      subtitle: 'Cross-checks total app foreground duration and prevents tampering.',
                      isGranted: status.hasUsageStatsPermission,
                      isRequired: false,
                      onTap: bridge.openUsageAccessSettings,
                    ),
                    const SizedBox(height: 12),
                    _buildPermissionTile(
                      theme: theme,
                      title: 'Notifications',
                      subtitle: 'Alerts you when protection is disabled and provides daily summaries.',
                      isGranted: status.hasNotificationPermission,
                      isRequired: false,
                      onTap: bridge.requestNotificationPermission,
                    ),
                    const SizedBox(height: 12),
                    _buildPermissionTile(
                      theme: theme,
                      title: 'Battery Optimization',
                      subtitle: 'Prevents the Android background killer from turning off ScrollGuard.',
                      isGranted: status.isIgnoringBatteryOptimizations,
                      isRequired: false,
                      onTap: bridge.openBatterySettings,
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.help_outline),
                      label: const Text('OEM Battery Survival Guide'),
                      onPressed: () => _showOemGuideSheet(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: status.isAccessibilityServiceEnabled
                    ? () => context.go('/dashboard')
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Continue to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required bool isGranted,
    required bool isRequired,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: isGranted
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isGranted
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : Colors.transparent,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Icon(
          isGranted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isGranted
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          size: 28,
        ),
        title: Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Required',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing: isGranted
            ? const Icon(Icons.done, color: Colors.green)
            : TextButton(
                onPressed: onTap,
                child: const Text('Grant'),
              ),
      ),
    );
  }
}
