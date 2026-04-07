/// Tenant management screen for the super admin panel.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/super_admin_models.dart';
import '../providers/super_admin_provider.dart';

final _dateFmt = DateFormat('yyyy-MM-dd');

/// DataTable-based screen listing all tenants with
/// provision / suspend / migrate actions.
class TenantManagementScreen extends ConsumerWidget {
  /// Creates a [TenantManagementScreen].
  const TenantManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(tenantListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(tenantListProvider.notifier).refresh(),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _showProvisionDialog(context, ref),
            icon: const Icon(Icons.add_business),
            label: const Text('New Store'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: tenantsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Error loading tenants: $e',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
        data: (page) => _TenantTable(page: page),
      ),
    );
  }

  Future<void> _showProvisionDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ProvisionDialog(ref: ref),
    );
  }
}

class _TenantTable extends ConsumerWidget {
  const _TenantTable({required this.page});

  final TenantPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(tenantListProvider.notifier);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Slug')),
                  DataColumn(label: Text('Plan')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Created')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: page.items
                    .map(
                      (t) => _tenantRow(context, t, notifier),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
        _PaginationBar(page: page, notifier: notifier),
      ],
    );
  }

  DataRow _tenantRow(
    BuildContext context,
    SuperAdminTenant tenant,
    TenantListNotifier notifier,
  ) {
    return DataRow(
      cells: [
        DataCell(Text(tenant.name)),
        DataCell(Text(tenant.slug)),
        DataCell(
          _PlanChip(tenant: tenant, notifier: notifier),
        ),
        DataCell(
          _StatusBadge(isActive: tenant.isActive),
        ),
        DataCell(Text(_dateFmt.format(tenant.createdAt))),
        DataCell(
          _ActionMenu(tenant: tenant, notifier: notifier),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(isActive ? 'Active' : 'Suspended'),
      backgroundColor: isActive
          ? Colors.green.shade100
          : Colors.red.shade100,
      labelStyle: TextStyle(
        color: isActive
            ? Colors.green.shade800
            : Colors.red.shade800,
        fontSize: 12,
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.tenant, required this.notifier});
  final SuperAdminTenant tenant;
  final TenantListNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(tenant.plan),
      onPressed: () => _showPlanPicker(context),
    );
  }

  Future<void> _showPlanPicker(BuildContext context) async {
    const plans = ['starter', 'standard', 'premium'];
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Change Plan'),
        children: plans
            .map(
              (p) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, p),
                child: Text(p),
              ),
            )
            .toList(),
      ),
    );
    if (chosen != null && chosen != tenant.plan) {
      await notifier.setPlan(tenant.slug, chosen);
    }
  }
}

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({required this.tenant, required this.notifier});
  final SuperAdminTenant tenant;
  final TenantListNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (action) => _onAction(context, action),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'toggle',
          child: Text(
            tenant.isActive ? 'Suspend' : 'Reactivate',
          ),
        ),
        const PopupMenuItem(
          value: 'migrate',
          child: Text('Run Migration'),
        ),
      ],
      child: const Icon(Icons.more_vert),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    String action,
  ) async {
    if (action == 'toggle') {
      final confirmed = await _confirm(
        context,
        title: tenant.isActive ? 'Suspend Store' : 'Reactivate Store',
        message: tenant.isActive
            ? 'Suspend "${tenant.name}"? Users will lose access.'
            : 'Reactivate "${tenant.name}"?',
      );
      if (confirmed) {
        await notifier.setActive(
          tenant.slug,
          active: !tenant.isActive,
        );
      }
    } else if (action == 'migrate') {
      final confirmed = await _confirm(
        context,
        title: 'Run Migration',
        message: 'Run Alembic upgrade on "${tenant.name}"?',
      );
      if (confirmed) {
        await notifier.ref
            .read(superAdminRepositoryProvider)
            .migrateTenant(tenant.slug);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Migration completed for ${tenant.name}'),
            ),
          );
        }
      }
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({required this.page, required this.notifier});

  final TenantPage page;
  final TenantListNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final totalPages =
        (page.total / page.pageSize).ceil().clamp(1, 9999);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: page.page > 1
                ? () => notifier.goToPage(page.page - 1)
                : null,
          ),
          Text('Page ${page.page} of $totalPages'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: page.page < totalPages
                ? () => notifier.goToPage(page.page + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

class _ProvisionDialog extends StatefulWidget {
  const _ProvisionDialog({required this.ref});
  final WidgetRef ref;

  @override
  State<_ProvisionDialog> createState() => _ProvisionDialogState();
}

class _ProvisionDialogState extends State<_ProvisionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _plan = 'starter';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.ref
          .read(tenantListProvider.notifier)
          .provision(
            name: _nameCtrl.text.trim(),
            slug: _slugCtrl.text.trim().toLowerCase(),
            plan: _plan,
            adminEmail: _emailCtrl.text.trim(),
            adminPassword: _passwordCtrl.text,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Provision New Store'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Store Name'),
                validator: (v) =>
                    (v?.isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _slugCtrl,
                decoration:
                    const InputDecoration(labelText: 'Slug'),
                validator: (v) =>
                    (v?.isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _plan,
                decoration:
                    const InputDecoration(labelText: 'Plan'),
                items: ['starter', 'standard', 'premium']
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(p),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _plan = v ?? 'starter'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration:
                    const InputDecoration(labelText: 'Admin Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v?.isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                decoration:
                    const InputDecoration(labelText: 'Admin Password'),
                obscureText: true,
                validator: (v) => (v?.length ?? 0) < 8
                    ? 'Min 8 characters'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Provision'),
        ),
      ],
    );
  }
}
