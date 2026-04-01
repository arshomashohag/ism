/// Stock transfer screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../domain/inventory_entry.dart';
import '../providers/inventory_provider.dart';

/// Screen for transferring stock between warehouses.
class TransferScreen extends ConsumerStatefulWidget {
  /// Creates a [TransferScreen].
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() =>
      _TransferScreenState();
}

class _TransferScreenState
    extends ConsumerState<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  String? _productId;
  String? _fromWarehouseId;
  String? _toWarehouseId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_productId == null ||
        _fromWarehouseId == null ||
        _toWarehouseId == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(inventoryRepositoryProvider)
          .transferStock(
            productId: _productId!,
            fromWarehouseId: _fromWarehouseId!,
            toWarehouseId: _toWarehouseId!,
            qty: int.parse(_qtyCtrl.text.trim()),
            reason: _reasonCtrl.text.trim(),
          );
      ref.read(inventoryListProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfer completed'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final warehousesAsync = ref.watch(warehousesProvider);
    final inventoryState = ref.watch(inventoryListProvider);
    final warehouses = warehousesAsync.valueOrNull ?? [];

    final products = inventoryState.entries
        .map((e) => (id: e.productId, name: e.productName))
        .toSet()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Stock'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child:
                    CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Transfer'),
              ),
            ),
        ],
      ),
      body: MaxWidthBox(
        maxWidth: 640,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  _ErrorBanner(message: _error!),
                _SectionCard(
                  title: 'What to Transfer',
                  children: [
                    _ProductDropdown(
                      products: products,
                      selectedId: _productId,
                      onChanged: (id) =>
                          setState(() => _productId = id),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _qtyCtrl,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: false,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Quantity *',
                        hintText: 'e.g. 10',
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n <= 0) {
                          return 'Enter a positive whole number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Warehouses',
                  children: [
                    _WarehouseField(
                      label: 'From Warehouse *',
                      warehouses: warehouses,
                      selectedId: _fromWarehouseId,
                      onChanged: (id) => setState(
                        () => _fromWarehouseId = id,
                      ),
                      validator: (v) =>
                          v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _WarehouseField(
                      label: 'To Warehouse *',
                      warehouses: warehouses,
                      selectedId: _toWarehouseId,
                      onChanged: (id) => setState(
                        () => _toWarehouseId = id,
                      ),
                      validator: (v) {
                        if (v == null) return 'Required';
                        if (v == _fromWarehouseId) {
                          return 'Must differ from source';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Details',
                  children: [
                    TextFormField(
                      controller: _reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reason *',
                        hintText:
                            'e.g. Rebalancing warehouse stock',
                      ),
                      maxLines: 2,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Reason is required'
                              : null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ProductDropdown extends StatelessWidget {
  const _ProductDropdown({
    required this.products,
    required this.selectedId,
    required this.onChanged,
  });

  final List<({String id, String name})> products;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedId,
      decoration: const InputDecoration(
        labelText: 'Product *',
      ),
      items: products
          .map(
            (p) => DropdownMenuItem<String>(
              value: p.id,
              child: Text(
                p.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Required' : null,
    );
  }
}

class _WarehouseField extends StatelessWidget {
  const _WarehouseField({
    required this.label,
    required this.warehouses,
    required this.selectedId,
    required this.onChanged,
    required this.validator,
  });

  final String label;
  final List<Warehouse> warehouses;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedId,
      decoration: InputDecoration(labelText: label),
      items: warehouses
          .map(
            (w) => DropdownMenuItem<String>(
              value: w.id,
              child: Text(w.name),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}
