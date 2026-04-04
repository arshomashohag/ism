/// "How it works" step section for the IMS marketing homepage.
library;

import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

/// Displays the three-step onboarding process in a horizontal or vertical layout.
class HowItWorksSection extends StatelessWidget {
  /// Creates a [HowItWorksSection].
  const HowItWorksSection({super.key});

  static const List<_StepData> _steps = [
    _StepData(
      number: '1',
      icon: Icons.add_box_outlined,
      title: 'Add Products',
      description:
          'Import or create your product catalog with categories, '
          'SKUs, and pricing in minutes.',
    ),
    _StepData(
      number: '2',
      icon: Icons.inventory_2_outlined,
      title: 'Track Inventory',
      description:
          'Assign stock to warehouses, set alert thresholds, '
          'and start monitoring in real time.',
    ),
    _StepData(
      number: '3',
      icon: Icons.insights_outlined,
      title: 'Get Insights',
      description:
          'View sales trends, identify top performers, and make '
          'data-driven decisions every day.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDesktop = ResponsiveBreakpoints.of(context)
        .largerOrEqualTo('DESKTOP');

    return ColoredBox(
      color: cs.surface,
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
                  eyebrow: 'PROCESS',
                  title: 'Up and Running in Minutes',
                  subtitle:
                      'Getting started with IMS is straightforward. '
                      'Three simple steps and you\'re managing inventory '
                      'like a pro.',
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: 56),
                isDesktop
                    ? _DesktopSteps(steps: _steps, cs: cs, tt: tt)
                    : _MobileSteps(steps: _steps, cs: cs, tt: tt),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopSteps extends StatelessWidget {
  const _DesktopSteps({
    required this.steps,
    required this.cs,
    required this.tt,
  });

  final List<_StepData> steps;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      children.add(
        Expanded(child: _StepItem(data: steps[i], cs: cs, tt: tt)),
      );
      if (i < steps.length - 1) {
        children.add(_HorizontalConnector(cs: cs));
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _MobileSteps extends StatelessWidget {
  const _MobileSteps({
    required this.steps,
    required this.cs,
    required this.tt,
  });

  final List<_StepData> steps;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      children.add(_StepItem(data: steps[i], cs: cs, tt: tt));
      if (i < steps.length - 1) {
        children.add(_VerticalConnector(cs: cs));
      }
    }
    return Column(children: children);
  }
}

class _HorizontalConnector extends StatelessWidget {
  const _HorizontalConnector({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 28),
      width: 48,
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

class _VerticalConnector extends StatelessWidget {
  const _VerticalConnector({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 2,
        height: 32,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [cs.primary, cs.primaryContainer],
          ),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

class _StepData {
  const _StepData({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });

  final String number;
  final IconData icon;
  final String title;
  final String description;
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.data,
    required this.cs,
    required this.tt,
  });

  final _StepData data;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.topRight,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                data.icon,
                size: 28,
                color: cs.onPrimaryContainer,
              ),
            ),
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    data.number,
                    style: tt.labelSmall?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          data.title,
          style: tt.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          data.description,
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
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
