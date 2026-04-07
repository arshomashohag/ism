/// Features grid section for the IMS marketing homepage.
library;

import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

/// Displays the six key capabilities of IMS in a responsive grid.
class FeaturesSection extends StatelessWidget {
  /// Creates a [FeaturesSection].
  const FeaturesSection({super.key});

  static const List<_FeatureData> _features = [
    _FeatureData(
      icon: Icons.track_changes,
      title: 'Real-time Tracking',
      description:
          'Monitor stock levels across all warehouses '
          'instantly with live updates.',
    ),
    _FeatureData(
      icon: Icons.notifications_active_outlined,
      title: 'Low Stock Alerts',
      description:
          'Automatically get notified when products '
          'fall below your set thresholds.',
    ),
    _FeatureData(
      icon: Icons.point_of_sale_outlined,
      title: 'Sales Management',
      description:
          'Process transactions quickly and generate '
          'professional invoices on the spot.',
    ),
    _FeatureData(
      icon: Icons.bar_chart_rounded,
      title: 'Analytics Dashboard',
      description:
          'Visualise revenue trends, top products, and '
          'team performance at a glance.',
    ),
    _FeatureData(
      icon: Icons.admin_panel_settings_outlined,
      title: 'Role Management',
      description:
          'Control access with admin, manager, and '
          'salesman roles out of the box.',
    ),
    _FeatureData(
      icon: Icons.qr_code_scanner,
      title: 'SKU & Barcode',
      description:
          'Organise products with SKUs and barcodes for '
          'fast lookup and scanning.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDesktop = ResponsiveBreakpoints.of(context)
        .largerOrEqualTo('DESKTOP');

    return ColoredBox(
      color: cs.surfaceContainerLowest,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 80,
            ),
            child: Column(
              children: [
                _SectionHeader(
                  eyebrow: 'CAPABILITIES',
                  title: 'Everything You Need',
                  subtitle:
                      'All the tools to manage your inventory efficiently, '
                      'from a single dashboard.',
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: 48),
                GridView.count(
                  crossAxisCount: isDesktop ? 3 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isDesktop ? 1.4 : 1.1,
                  children: _features
                      .map(
                        (f) => _FeatureCard(
                          data: f,
                          cs: cs,
                          tt: tt,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureData {
  const _FeatureData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.data,
    required this.cs,
    required this.tt,
  });

  final _FeatureData data;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                data.icon,
                size: 22,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              data.title,
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                data.description,
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared section header used across marketing sections.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.cs,
    required this.tt,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          eyebrow,
          style: tt.labelSmall?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: tt.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            subtitle,
            style: tt.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
