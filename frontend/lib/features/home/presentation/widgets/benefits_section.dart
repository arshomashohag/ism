/// Benefits / outcomes section for the IMS marketing homepage.
library;

import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

/// Highlights four key business outcomes delivered by IMS.
class BenefitsSection extends StatelessWidget {
  /// Creates a [BenefitsSection].
  const BenefitsSection({super.key});

  static const List<_BenefitData> _benefits = [
    _BenefitData(
      icon: Icons.timer_outlined,
      stat: '2× faster',
      title: 'Save Time',
      description:
          'Automate repetitive stock tasks and reduce '
          'manual data entry significantly.',
    ),
    _BenefitData(
      icon: Icons.verified_outlined,
      stat: '90% fewer',
      title: 'Reduce Errors',
      description:
          'Eliminate stockout surprises and mis-counted '
          'inventory with automated alerts.',
    ),
    _BenefitData(
      icon: Icons.trending_up_outlined,
      stat: '35% growth',
      title: 'Increase Efficiency',
      description:
          'Streamline operations so your team focuses '
          'on selling, not counting.',
    ),
    _BenefitData(
      icon: Icons.lightbulb_outline,
      stat: 'Real-time',
      title: 'Better Decisions',
      description:
          'Act on live data instead of end-of-day '
          'reports that are already outdated.',
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
                  eyebrow: 'OUTCOMES',
                  title: 'Built for Results',
                  subtitle:
                      'IMS delivers measurable improvements from day one. '
                      'Here\'s what our customers experience.',
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: 48),
                GridView.count(
                  crossAxisCount: isDesktop ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.3,
                  children: _benefits
                      .map(
                        (b) => _BenefitCard(data: b, cs: cs, tt: tt),
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

class _BenefitData {
  const _BenefitData({
    required this.icon,
    required this.stat,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String stat;
  final String title;
  final String description;
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.data,
    required this.cs,
    required this.tt,
  });

  final _BenefitData data;
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
            Icon(data.icon, size: 32, color: cs.primary),
            const SizedBox(height: 8),
            Text(
              data.stat,
              style: tt.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              data.title,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                data.description,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
