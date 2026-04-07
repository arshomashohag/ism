/// Hero section for the IMS marketing homepage.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'dashboard_mockup.dart';

/// Full-width hero section with gradient background, headline, and CTA buttons.
///
/// Renders a two-column layout on desktop (text + mockup) and a stacked
/// column on mobile. Does not use [_SectionWrapper] as it needs a
/// full-width gradient background.
class HeroSection extends StatelessWidget {
  /// Creates a [HeroSection].
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDesktop = ResponsiveBreakpoints.of(context)
        .largerOrEqualTo('DESKTOP');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 80,
            ),
            child: isDesktop
                ? _DesktopLayout(cs: cs, tt: tt)
                : _MobileLayout(cs: cs, tt: tt),
          ),
        ),
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({required this.cs, required this.tt});

  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _HeroText(cs: cs, tt: tt)),
        const SizedBox(width: 48),
        const Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: DashboardMockup(isDesktop: true),
          ),
        ),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({required this.cs, required this.tt});

  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroText(cs: cs, tt: tt),
        const SizedBox(height: 40),
        const DashboardMockup(isDesktop: false),
      ],
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText({required this.cs, required this.tt});

  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Smart Inventory Management,\nMade Simple',
          style: tt.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Track stock in real-time, automate low-stock alerts, '
          'process sales instantly, and get analytics that '
          'help your business grow — all in one place.',
          style: tt.titleMedium?.copyWith(
            color: cs.onPrimary.withValues(alpha: 0.85),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 36),
        _HeroButtons(cs: cs),
      ],
    );
  }
}

class _HeroButtons extends StatelessWidget {
  const _HeroButtons({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.login),
          label: const Text('Sign In'),
          style: FilledButton.styleFrom(
            backgroundColor: cs.onPrimary,
            foregroundColor: cs.primary,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 14,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => context.go('/register'),
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Create Account'),
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.onPrimary,
            side: BorderSide(
              color: cs.onPrimary.withValues(alpha: 0.7),
              width: 1.5,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
