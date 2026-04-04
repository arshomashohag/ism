/// Call-to-action section for the IMS marketing homepage.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Full-width gradient CTA section with sign-in and register buttons.
///
/// Does not use [_SectionWrapper] as it requires a full-width
/// gradient background from primary to tertiary.
class CtaSection extends StatelessWidget {
  /// Creates a [CtaSection].
  const CtaSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.tertiary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 80,
            ),
            child: Column(
              children: [
                Text(
                  'Start Managing Your Inventory Today',
                  style: tt.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimary,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Join businesses that trust IMS to keep their stock '
                  'accurate, their sales flowing, and their teams aligned.',
                  style: tt.bodyLarge?.copyWith(
                    color: cs.onPrimary.withValues(alpha: 0.85),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.go('/register'),
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Create Free Account'),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.onPrimary,
                        foregroundColor: cs.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/login'),
                      icon: const Icon(Icons.login),
                      label: const Text('Sign In'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.onPrimary,
                        side: BorderSide(
                          color: cs.onPrimary.withValues(alpha: 0.7),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
