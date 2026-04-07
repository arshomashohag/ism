/// Stock adjustment dialog.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/inventory_entry.dart';
import '../../providers/inventory_provider.dart';

/// Modal dialog for adjusting stock on hand.
///
/// Allows the user to enter a signed delta and a mandatory reason.
class AdjustDialog extends ConsumerStatefulWidget {
  /// Creates an [AdjustDialog].
  const AdjustDialog({
    super.key,
    required this.entry,
    required this.warehouses,
  });

  /// The inventory entry being adjusted.
  final InventoryEntry entry;

  /// All available warehouses (for display only).
  final List<Warehouse> warehouses;

  @override
  ConsumerState<AdjustDialog> createState() =>
      _AdjustDialogState();
}

class _AdjustDialogState extends ConsumerState<AdjustDialog> {
  final _formKey = GlobalKey<FormState>();
  final _deltaCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _deltaCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final delta = int.parse(_deltaCtrl.text.trim());
    final reason = _reasonCtrl.text.trim();

    try {
      final updated = await ref
          .read(inventoryRepositoryProvider)
          .adjustStock(
            warehouseId: widget.entry.warehouseId,
            productId: widget.entry.productId,
            delta: delta,
            reason: reason,
          );
      ref
          .read(inventoryListProvider.notifier)
          .replaceEntry(updated);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlertDialog(
      title: const Text('Adjust Stock'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InfoRow(
              label: 'Product',
              value: widget.entry.productName,
            ),
            _InfoRow(
              label: 'Warehouse',
              value: widget.entry.warehouseName,
            ),
            _InfoRow(
              label: 'Current stock',
              value: '${widget.entry.qtyOnHand} units',
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                      color: cs.onErrorContainer),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _deltaCtrl,
              keyboardType: const TextInputType
                  .numberWithOptions(
                signed: true,
                decimal: false,
              ),
              decoration: const InputDecoration(
                labelText: 'Delta *',
                hintText: '+10 or -5',
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null) return 'Enter a whole number';
                if (n == 0) return 'Delta must not be zero';
                final result =
                    widget.entry.qtyOnHand + n;
                if (result < 0) {
                  return 'Would result in negative stock '
                      '(${widget.entry.qtyOnHand} + $n = $result)';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason *',
                hintText: 'e.g. Stock count, damaged goods',
              ),
              maxLines: 2,
              validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? 'Reason is required'
                      : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text('Apply'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface
                  .withValues(alpha: 0.55),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
