/// Checkout dialog — payment method, tendered amount, change.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/sale.dart';
import '../../providers/sales_provider.dart';

/// Modal dialog to finalise a cart into a sale.
class CheckoutDialog extends ConsumerStatefulWidget {
  /// Creates a [CheckoutDialog].
  const CheckoutDialog({super.key, required this.cart});

  /// The current cart state to check out.
  final CartState cart;

  @override
  ConsumerState<CheckoutDialog> createState() =>
      _CheckoutDialogState();
}

class _CheckoutDialogState
    extends ConsumerState<CheckoutDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tenderedCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  String _method = 'cash';
  bool _submitting = false;
  String? _error;

  double get _grandTotal => widget.cart.grandTotal;

  double get _tendered =>
      double.tryParse(_tenderedCtrl.text) ?? 0.0;

  double get _change => (_tendered - _grandTotal).clamp(
        0.0,
        double.infinity,
      );

  @override
  void initState() {
    super.initState();
    _tenderedCtrl.text =
        _grandTotal.toStringAsFixed(2);
    _tenderedCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tenderedCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final cart = widget.cart;
    final lineItems = cart.items
        .map(
          (i) => <String, dynamic>{
            'product_id': i.productId,
            'qty': i.qty,
          },
        )
        .toList();

    try {
      final sale = await ref
          .read(salesRepositoryProvider)
          .createSale(
            warehouseId: cart.warehouseId!,
            lineItems: lineItems,
            paymentMethod: _method,
            amountTendered: _tendered,
            discount: cart.discount,
            reference: _referenceCtrl.text.isNotEmpty
                ? _referenceCtrl.text
                : null,
          );
      if (mounted) Navigator.of(context).pop(sale);
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Checkout'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _SummaryRow(
                  label: 'Subtotal',
                  value:
                      '\$${widget.cart.subtotal.toStringAsFixed(2)}',
                ),
                _SummaryRow(
                  label: 'Tax',
                  value:
                      '\$${widget.cart.taxTotal.toStringAsFixed(2)}',
                ),
                if (widget.cart.discount > 0)
                  _SummaryRow(
                    label: 'Discount',
                    value:
                        '-\$${widget.cart.discount.toStringAsFixed(2)}',
                  ),
                _SummaryRow(
                  label: 'Total',
                  value:
                      '\$${_grandTotal.toStringAsFixed(2)}',
                  bold: true,
                ),
                const SizedBox(height: 16),
                const Text('Payment method'),
                const SizedBox(height: 4),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'cash',
                      label: Text('Cash'),
                      icon: Icon(Icons.payments_outlined),
                    ),
                    ButtonSegment(
                      value: 'card',
                      label: Text('Card'),
                      icon: Icon(Icons.credit_card),
                    ),
                    ButtonSegment(
                      value: 'mobile',
                      label: Text('Mobile'),
                      icon: Icon(Icons.phone_android),
                    ),
                  ],
                  selected: {_method},
                  onSelectionChanged: (sel) =>
                      setState(() => _method = sel.first),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tenderedCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Amount tendered',
                    prefixText: '\$ ',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n <= 0) {
                      return 'Enter a valid amount';
                    }
                    if (n < _grandTotal) {
                      return 'Insufficient amount';
                    }
                    return null;
                  },
                ),
                if (_method == 'cash') ...[
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'Change',
                    value:
                        '\$${_change.toStringAsFixed(2)}',
                    color: Colors.green.shade600,
                  ),
                ],
                if (_method != 'cash') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _referenceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Reference (optional)',
                    ),
                    maxLength: 100,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: cs.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text('Confirm Sale'),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            )
        : Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
            );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }
}
