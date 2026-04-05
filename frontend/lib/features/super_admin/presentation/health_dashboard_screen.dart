/// Health dashboard screen for the super admin panel.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/super_admin_models.dart';
import '../providers/super_admin_provider.dart';

/// Displays ECS task status and RDS connection metrics.
class HealthDashboardScreen extends ConsumerWidget {
  /// Creates a [HealthDashboardScreen].
  const HealthDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(healthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Health'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(healthProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: healthAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Failed to load health metrics: $e',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
        data: (health) => _HealthBody(health: health),
      ),
    );
  }
}

class _HealthBody extends StatelessWidget {
  const _HealthBody({required this.health});

  final PlatformHealth health;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KpiRow(health: health),
          const SizedBox(height: 32),
          Text(
            'ECS Tasks',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _EcsTaskTable(tasks: health.ecsTasks),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.health});
  final PlatformHealth health;

  @override
  Widget build(BuildContext context) {
    final rdsPercent = health.rdsConnectionsLimit > 0
        ? (health.rdsConnections / health.rdsConnectionsLimit * 100)
            .toStringAsFixed(1)
        : '—';

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _KpiCard(
          label: 'Running Tasks',
          value: '${health.ecsRunningTasks}',
          icon: Icons.cloud_queue,
          color: health.ecsRunningTasks > 0
              ? Colors.green
              : Colors.red,
        ),
        _KpiCard(
          label: 'RDS Connections',
          value: '${health.rdsConnections}',
          icon: Icons.storage,
          color: Colors.blue,
        ),
        if (health.rdsConnectionsLimit > 0)
          _KpiCard(
            label: 'RDS Utilisation',
            value: '$rdsPercent %',
            icon: Icons.percent,
            color: health.rdsConnections >
                    health.rdsConnectionsLimit * 0.8
                ? Colors.orange
                : Colors.green,
          ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: color),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EcsTaskTable extends StatelessWidget {
  const _EcsTaskTable({required this.tasks});
  final List<EcsTaskInfo> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No running ECS tasks found.')),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Task ARN')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('CPU')),
            DataColumn(label: Text('Memory')),
          ],
          rows: tasks
              .map(
                (t) => DataRow(
                  cells: [
                    DataCell(
                      Text(
                        t.taskArn.split('/').last,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    DataCell(
                      Chip(
                        label: Text(t.status),
                        backgroundColor:
                            t.status == 'RUNNING'
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                      ),
                    ),
                    DataCell(Text(t.cpu)),
                    DataCell(Text('${t.memory} MiB')),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
