/// Testimonials section for the IMS marketing homepage.
library;

import 'package:flutter/material.dart';

/// Displays three placeholder customer testimonials in a responsive Wrap layout.
class TestimonialsSection extends StatelessWidget {
  /// Creates a [TestimonialsSection].
  const TestimonialsSection({super.key});

  static const List<_TestimonialData> _testimonials = [
    _TestimonialData(
      quote:
          'IMS transformed how we run our electronics shop. '
          'The low stock alerts alone saved us from two stockouts '
          'last quarter.',
      name: 'Maria Santos',
      role: 'Store Owner, Manila',
    ),
    _TestimonialData(
      quote:
          'Finally a system that my whole team actually uses. '
          'The salesman roles mean everyone sees exactly what '
          'they need — nothing more.',
      name: 'James Okafor',
      role: 'Operations Manager, Lagos',
    ),
    _TestimonialData(
      quote:
          'The analytics dashboard gives me a clear picture of '
          'which products drive revenue. I\'ve cut dead stock by '
          'nearly 40% in three months.',
      name: 'Priya Nair',
      role: 'Retail Manager, Bengaluru',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
                  eyebrow: 'CUSTOMERS',
                  title: 'Trusted by Businesses',
                  subtitle:
                      'Hear from small and medium business owners who '
                      'rely on IMS every day.',
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: 48),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: _testimonials
                      .map(
                        (t) => _TestimonialCard(
                          data: t,
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

class _TestimonialData {
  const _TestimonialData({
    required this.quote,
    required this.name,
    required this.role,
  });

  final String quote;
  final String name;
  final String role;
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({
    required this.data,
    required this.cs,
    required this.tt,
  });

  final _TestimonialData data;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.format_quote,
                size: 32,
                color: cs.primary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 8),
              Text(
                data.quote,
                style: tt.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: cs.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      data.name.substring(0, 1),
                      style: tt.titleSmall?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.name,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        data.role,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
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
