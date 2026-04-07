/// Footer section for the IMS marketing homepage.
library;

import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

const List<String> _footerLinks = [
  'About',
  'Contact',
  'Privacy Policy',
  'Terms',
];

/// Site footer with logo, copyright text, and non-functional navigation links.
class FooterSection extends StatelessWidget {
  /// Creates a [FooterSection].
  const FooterSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDesktop = ResponsiveBreakpoints.of(context)
        .largerOrEqualTo('DESKTOP');

    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 40,
            ),
            child: isDesktop
                ? _DesktopFooter(cs: cs, tt: tt)
                : _MobileFooter(cs: cs, tt: tt),
          ),
        ),
      ),
    );
  }
}

class _DesktopFooter extends StatelessWidget {
  const _DesktopFooter({required this.cs, required this.tt});

  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _LogoAndCopyright(cs: cs, tt: tt),
        const Spacer(),
        _FooterLinks(cs: cs),
      ],
    );
  }
}

class _MobileFooter extends StatelessWidget {
  const _MobileFooter({required this.cs, required this.tt});

  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LogoAndCopyright(cs: cs, tt: tt),
        const SizedBox(height: 20),
        _FooterLinks(cs: cs),
      ],
    );
  }
}

class _LogoAndCopyright extends StatelessWidget {
  const _LogoAndCopyright({required this.cs, required this.tt});

  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 20,
              color: cs.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'IMS',
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '© 2025 IMS. All rights reserved.',
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FooterLinks extends StatelessWidget {
  const _FooterLinks({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: _footerLinks
          .map(
            (link) => TextButton(
              onPressed: null,
              child: Text(link),
            ),
          )
          .toList(),
    );
  }
}
