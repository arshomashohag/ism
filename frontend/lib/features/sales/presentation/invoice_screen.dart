/// Invoice detail and print screen.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/sale.dart';
import '../providers/sales_provider.dart';

/// Provider that fetches a single sale by ID.
final _saleDetailProvider =
    FutureProvider.autoDispose.family<Sale, String>(
  (ref, id) =>
      ref.read(salesRepositoryProvider).getSale(id),
);

/// Displays a sale's full invoice and allows printing.
class InvoiceScreen extends ConsumerWidget {
  /// Creates an [InvoiceScreen].
  const InvoiceScreen({super.key, required this.saleId});

  /// UUID of the sale to display.
  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleAsync = ref.watch(_saleDetailProvider(saleId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice'),
        actions: [
          saleAsync.whenOrNull(
            data: (sale) => IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: 'Print',
              onPressed: () => _print(context, sale),
            ),
          ) ??
              const SizedBox.shrink(),
          if (saleAsync.valueOrNull?.isVoided == false)
            saleAsync.whenOrNull(
              data: (sale) => IconButton(
                icon: Icon(
                  Icons.cancel_outlined,
                  color:
                      Theme.of(context).colorScheme.error,
                ),
                tooltip: 'Void',
                onPressed: () =>
                    _confirmVoid(context, ref, sale),
              ),
            ) ??
                const SizedBox.shrink(),
          const SizedBox(width: 8),
        ],
      ),
      body: saleAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color:
                    Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text('Could not load invoice: $e'),
            ],
          ),
        ),
        data: (sale) => _InvoiceBody(sale: sale),
      ),
    );
  }

  Future<void> _print(
      BuildContext context, Sale sale) async {
    await Printing.layoutPdf(
      onLayout: (_) => _buildPdf(sale),
    );
  }

  Future<void> _confirmVoid(
    BuildContext context,
    WidgetRef ref,
    Sale sale,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void sale?'),
        content: Text(
          'Void ${sale.invoiceNumber}? '
          'This will restore all inventory.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  Theme.of(ctx).colorScheme.error,
              foregroundColor:
                  Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => ctx.pop(true),
            child: const Text('Void'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(salesRepositoryProvider)
          .voidSale(sale.id);
      ref.invalidate(_saleDetailProvider(saleId));
      ref.read(salesListProvider.notifier).refresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Void failed: $e')),
        );
      }
    }
  }

  Future<Uint8List> _buildPdf(Sale sale) async {
    final doc = pw.Document();
    final fmt = DateFormat('dd MMM yyyy HH:mm');
    final currency = NumberFormat.currency(symbol: '\$');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  sale.invoiceNumber,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              fmt.format(sale.createdAt.toLocal()),
              style: const pw.TextStyle(fontSize: 10),
            ),
            if (sale.warehouseName != null)
              pw.Text(
                'Warehouse: ${sale.warehouseName}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            pw.Divider(),
            pw.Table(
              border: null,
              columnWidths: const {
                0: pw.FlexColumnWidth(4),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  children: [
                    pw.Text(
                      'Item',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                    pw.Text(
                      'Qty',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                    pw.Text(
                      'Price',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                    pw.Text(
                      'Total',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ],
                ),
                ...sale.lineItems.map(
                  (li) => pw.TableRow(
                    children: [
                      pw.Text(
                        li.productName,
                        style:
                            const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        '${li.qty}',
                        style:
                            const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.right,
                      ),
                      pw.Text(
                        currency.format(li.unitPrice),
                        style:
                            const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.right,
                      ),
                      pw.Text(
                        currency.format(li.lineTotal),
                        style:
                            const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.Divider(),
            _pdfTotalsRow(
              'Subtotal',
              currency.format(sale.subtotal),
            ),
            _pdfTotalsRow(
              'Tax',
              currency.format(sale.taxTotal),
            ),
            if (sale.discount > 0)
              _pdfTotalsRow(
                'Discount',
                '-${currency.format(sale.discount)}',
              ),
            _pdfTotalsRow(
              'TOTAL',
              currency.format(sale.grandTotal),
              bold: true,
            ),
            if (sale.payment != null) ...[
              pw.SizedBox(height: 8),
              _pdfTotalsRow(
                'Tendered',
                currency.format(
                    sale.payment!.amountTendered),
              ),
              _pdfTotalsRow(
                'Change',
                currency
                    .format(sale.payment!.changeGiven),
              ),
            ],
            if (sale.isVoided) ...[
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text(
                  'VOIDED',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return Uint8List.fromList(await doc.save());
  }

  pw.Widget _pdfTotalsRow(
    String label,
    String value, {
    bool bold = false,
  }) {
    final style = bold
        ? pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
          )
        : const pw.TextStyle(fontSize: 9);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment:
            pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }
}

// ── Invoice body ──────────────────────────────────────────────

class _InvoiceBody extends StatelessWidget {
  const _InvoiceBody({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InvoiceHeader(sale: sale),
        const SizedBox(height: 12),
        _LineItemsCard(sale: sale),
        const SizedBox(height: 12),
        _TotalsCard(sale: sale),
        if (sale.payment != null) ...[
          const SizedBox(height: 12),
          _PaymentCard(payment: sale.payment!),
        ],
      ],
    );
  }
}

class _InvoiceHeader extends StatelessWidget {
  const _InvoiceHeader({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy  HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sale.invoiceNumber,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                _StatusChip(status: sale.status),
              ],
            ),
            const SizedBox(height: 8),
            _MetaRow(
              icon: Icons.schedule,
              text:
                  fmt.format(sale.createdAt.toLocal()),
            ),
            if (sale.warehouseName != null)
              _MetaRow(
                icon: Icons.warehouse_outlined,
                text: sale.warehouseName!,
              ),
            if (sale.salesmanName != null)
              _MetaRow(
                icon: Icons.person_outline,
                text: sale.salesmanName!,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isVoided = status == 'voided';
    return Chip(
      label: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isVoided
              ? Colors.red.shade700
              : Colors.green.shade700,
        ),
      ),
      backgroundColor: isVoided
          ? Colors.red.shade50
          : Colors.green.shade50,
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color:
                      cs.onSurface.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }
}

class _LineItemsCard extends StatelessWidget {
  const _LineItemsCard({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Product',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: cs.onSurface
                                .withValues(alpha: 0.55),
                          ),
                    ),
                  ),
                  Text(
                    'Qty',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                          color: cs.onSurface
                              .withValues(alpha: 0.55),
                        ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 80,
                    child: Text(
                      'Total',
                      textAlign: TextAlign.right,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: cs.onSurface
                                .withValues(alpha: 0.55),
                          ),
                    ),
                  ),
                ],
              ),
            ),
            for (int i = 0;
                i < sale.lineItems.length;
                i++) ...[
              _LineItemRow(item: sale.lineItems[i]),
              if (i < sale.lineItems.length - 1)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: cs.outline.withValues(alpha: 0.12),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LineItemRow extends StatelessWidget {
  const _LineItemRow({required this.item});

  final SaleLineItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '\$${item.unitPrice.toStringAsFixed(2)} ea',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: cs.onSurface
                            .withValues(alpha: 0.55),
                      ),
                ),
              ],
            ),
          ),
          Text(
            '${item.qty}',
            style: Theme.of(context)
                .textTheme
                .bodyMedium,
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 80,
            child: Text(
              '\$${item.lineTotal.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _TRow(
              label: 'Subtotal',
              value:
                  '\$${sale.subtotal.toStringAsFixed(2)}',
            ),
            Divider(
              color: cs.outline.withValues(alpha: 0.12),
              height: 16,
            ),
            _TRow(
              label: 'Tax',
              value:
                  '\$${sale.taxTotal.toStringAsFixed(2)}',
            ),
            if (sale.discount > 0)
              _TRow(
                label: 'Discount',
                value:
                    '-\$${sale.discount.toStringAsFixed(2)}',
                valueColor: Colors.green.shade600,
              ),
            Divider(
              color: cs.outline.withValues(alpha: 0.12),
              height: 16,
            ),
            _TRow(
              label: 'Grand Total',
              value:
                  '\$${sale.grandTotal.toStringAsFixed(2)}',
              bold: true,
              valueColor: cs.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _TRow extends StatelessWidget {
  const _TRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium;
    final style = bold
        ? base?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          )
        : base?.copyWith(color: valueColor);

    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
        const Spacer(),
        Text(value, style: style),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});

  final SalePayment payment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('dd MMM yyyy  HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PAYMENT',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                    color:
                        cs.onSurface.withValues(alpha: 0.55),
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: 12),
            _TRow(
              label: 'Method',
              value: payment.method.toUpperCase(),
            ),
            _TRow(
              label: 'Tendered',
              value:
                  '\$${payment.amountTendered.toStringAsFixed(2)}',
            ),
            _TRow(
              label: 'Change',
              value:
                  '\$${payment.changeGiven.toStringAsFixed(2)}',
            ),
            if (payment.reference != null)
              _TRow(
                label: 'Reference',
                value: payment.reference!,
              ),
            _TRow(
              label: 'Paid at',
              value: fmt.format(
                  payment.paidAt.toLocal()),
            ),
          ],
        ),
      ),
    );
  }
}
