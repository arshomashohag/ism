/// Audit log screen for the super admin panel.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/super_admin_models.dart';
import '../providers/super_admin_provider.dart';

final _dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

/// Paginated, filterable audit trail across all tenant schemas.
class AuditLogScreen extends ConsumerStatefulWidget {
  /// Creates an [AuditLogScreen].
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() =>
      _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  final _entityTypeCtrl = TextEditingController();
  final _actionCtrl = TextEditingController();

  @override
  void dispose() {
    _entityTypeCtrl.dispose();
    _actionCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref.read(auditLogProvider.notifier).refresh(
          entityType: _entityTypeCtrl.text.trim().isEmpty
              ? null
              : _entityTypeCtrl.text.trim(),
          action: _actionCtrl.text.trim().isEmpty
              ? null
              : _actionCtrl.text.trim(),
        );
  }

  void _clearFilters() {
    _entityTypeCtrl.clear();
    _actionCtrl.clear();
    ref.read(auditLogProvider.notifier).clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final logAsync = ref.watch(auditLogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(auditLogProvider.notifier).refresh(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            entityTypeCtrl: _entityTypeCtrl,
            actionCtrl: _actionCtrl,
            onApply: _applyFilters,
            onClear: _clearFilters,
          ),
          Expanded(
            child: logAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Error loading audit log: $e',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              data: (page) => _AuditTable(page: page),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.entityTypeCtrl,
    required this.actionCtrl,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController entityTypeCtrl;
  final TextEditingController actionCtrl;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 180,
            child: TextField(
              controller: entityTypeCtrl,
              decoration: const InputDecoration(
                labelText: 'Entity Type',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => onApply(),
            ),
          ),
          SizedBox(
            width: 160,
            child: TextField(
              controller: actionCtrl,
              decoration: const InputDecoration(
                labelText: 'Action',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => onApply(),
            ),
          ),
          FilledButton(
            onPressed: onApply,
            child: const Text('Filter'),
          ),
          OutlinedButton(
            onPressed: onClear,
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _AuditTable extends ConsumerWidget {
  const _AuditTable({required this.page});
  final AuditLogPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(auditLogProvider.notifier);
    final totalPages =
        (page.total / page.pageSize).ceil().clamp(1, 9999);

    if (page.items.isEmpty) {
      return const Center(child: Text('No audit log entries found.'));
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Time')),
                  DataColumn(label: Text('Entity')),
                  DataColumn(label: Text('Record ID')),
                  DataColumn(label: Text('Action')),
                  DataColumn(label: Text('Tenant')),
                  DataColumn(label: Text('User')),
                ],
                rows: page.items
                    .map((e) => _entryRow(e))
                    .toList(),
              ),
            ),
          ),
        ),
        Padding(
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
        ),
      ],
    );
  }

  DataRow _entryRow(AuditLogEntry entry) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            _dateTimeFmt.format(entry.createdAt.toLocal()),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        DataCell(Text(entry.entityType)),
        DataCell(
          Text(
            entry.entityId,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        DataCell(_ActionBadge(action: entry.action)),
        DataCell(
          Text(
            _short(entry.tenantId),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        DataCell(
          Text(
            _short(entry.userId),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  String _short(String? uuid) {
    if (uuid == null) return '—';
    if (uuid.length > 8) return '${uuid.substring(0, 8)}…';
    return uuid;
  }
}

class _ActionBadge extends StatelessWidget {
  const _ActionBadge({required this.action});
  final String action;

  static const _colors = {
    'create': Colors.green,
    'update': Colors.blue,
    'delete': Colors.red,
    'void': Colors.orange,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[action] ?? Colors.grey;
    return Chip(
      label: Text(action),
      backgroundColor: color.withOpacity(0.15),
      labelStyle: TextStyle(color: color, fontSize: 11),
    );
  }
}
