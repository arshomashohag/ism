/// Home / landing screen.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Landing page shown to unauthenticated visitors.
///
/// Introduces IMS and offers navigation to sign in or create an account.
class HomeScreen extends StatelessWidget {
  /// Creates a [HomeScreen].
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 48,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 72,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Inventory Management System',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'A complete solution for managing your store — '
                  'track products, monitor stock levels, process '
                  'sales, and get insights into your business '
                  'performance, all from one place.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                _FeatureRow(
                  icon: Icons.storefront_outlined,
                  title: 'Product Catalog',
                  description:
                      'Organise products by category with rich '
                      'details and images.',
                ),
                const SizedBox(height: 20),
                _FeatureRow(
                  icon: Icons.warehouse_outlined,
                  title: 'Stock Control',
                  description:
                      'Track quantities across warehouses and get '
                      'low-stock alerts.',
                ),
                const SizedBox(height: 20),
                _FeatureRow(
                  icon: Icons.point_of_sale_outlined,
                  title: 'Point of Sale',
                  description:
                      'Process transactions quickly and generate '
                      'invoices instantly.',
                ),
                const SizedBox(height: 20),
                _FeatureRow(
                  icon: Icons.bar_chart_outlined,
                  title: 'Analytics',
                  description:
                      'View sales trends, top products, and team '
                      'performance at a glance.',
                ),
                const SizedBox(height: 48),
                FilledButton(
                  onPressed: () => context.go('/register'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/login'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 24,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
