/// Product create / edit form screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../domain/category.dart';
import '../domain/product.dart';
import '../providers/products_provider.dart';

/// Flattens a nested category tree into a single list.
List<Category> _flattenCategories(List<Category> cats) {
  final result = <Category>[];
  for (final c in cats) {
    result.add(c);
    result.addAll(_flattenCategories(c.children));
  }
  return result;
}

/// Form for creating or editing a product.
class ProductFormScreen extends ConsumerStatefulWidget {
  /// Creates a [ProductFormScreen].
  const ProductFormScreen({super.key, this.productId});

  /// UUID of product to edit; null for create mode.
  final String? productId;

  @override
  ConsumerState<ProductFormScreen> createState() =>
      _ProductFormScreenState();
}

class _ProductFormScreenState
    extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _skuCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _unitPriceCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();

  String? _selectedCategoryId;
  bool _saving = false;
  bool _loadingProduct = false;
  String? _errorMessage;

  bool get _isEditMode => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) _loadProduct();
  }

  @override
  void dispose() {
    _skuCtrl.dispose();
    _nameCtrl.dispose();
    _unitPriceCtrl.dispose();
    _costPriceCtrl.dispose();
    _taxRateCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    setState(() => _loadingProduct = true);
    try {
      final product = await ref
          .read(productsRepositoryProvider)
          .getProduct(widget.productId!);
      _populate(product);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _loadingProduct = false);
    }
  }

  void _populate(Product product) {
    _skuCtrl.text = product.sku;
    _nameCtrl.text = product.name;
    _unitPriceCtrl.text = product.unitPrice.toString();
    if (product.costPrice != null) {
      _costPriceCtrl.text = product.costPrice.toString();
    }
    if (product.taxRate != null) {
      _taxRateCtrl.text =
          (product.taxRate! * 100).toStringAsFixed(2);
    }
    if (product.barcode != null) {
      _barcodeCtrl.text = product.barcode!;
    }
    setState(() => _selectedCategoryId = product.categoryId);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final repo = ref.read(productsRepositoryProvider);
    final unitPrice =
        double.tryParse(_unitPriceCtrl.text.trim()) ?? 0;
    final costPrice = _costPriceCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_costPriceCtrl.text.trim());
    final taxRatePercent = _taxRateCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_taxRateCtrl.text.trim());
    final taxRate =
        taxRatePercent != null ? taxRatePercent / 100 : null;
    final barcode = _barcodeCtrl.text.trim().isEmpty
        ? null
        : _barcodeCtrl.text.trim();

    try {
      if (_isEditMode) {
        final updated = await repo.updateProduct(
          widget.productId!,
          name: _nameCtrl.text.trim(),
          unitPrice: unitPrice,
          categoryId: _selectedCategoryId,
          barcode: barcode,
          costPrice: costPrice,
          taxRate: taxRate,
        );
        ref
            .read(productListProvider.notifier)
            .replaceProduct(updated);
        if (mounted) context.pop();
      } else {
        await repo.createProduct(
          sku: _skuCtrl.text.trim(),
          name: _nameCtrl.text.trim(),
          unitPrice: unitPrice,
          categoryId: _selectedCategoryId,
          barcode: barcode,
          costPrice: costPrice,
          taxRate: taxRate,
        );
        ref.read(productListProvider.notifier).refresh();
        if (mounted) context.pop();
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final title = _isEditMode ? 'Edit Product' : 'New Product';
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _submit,
                child: Text(_isEditMode ? 'Update' : 'Create'),
              ),
            ),
        ],
      ),
      body: MaxWidthBox(
        maxWidth: 640,
        child: _loadingProduct
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null)
                        _ErrorBanner(message: _errorMessage!),
                      _FormCard(
                        title: 'Basic Information',
                        children: [
                          if (!_isEditMode)
                            _Field(
                              ctrl: _skuCtrl,
                              label: 'SKU',
                              hint: 'e.g. SKU-ELEC-001',
                              required: true,
                              validator: (v) =>
                                  (v == null || v.isEmpty)
                                      ? 'SKU is required'
                                      : null,
                            ),
                          _Field(
                            ctrl: _nameCtrl,
                            label: 'Product Name',
                            hint: 'e.g. Wireless Earbuds',
                            required: true,
                            validator: (v) =>
                                (v == null || v.isEmpty)
                                    ? 'Name is required'
                                    : null,
                          ),
                          _Field(
                            ctrl: _barcodeCtrl,
                            label: 'Barcode',
                            hint: 'EAN / UPC (optional)',
                          ),
                          _CategoryDropdown(
                            categories:
                                categoriesAsync.valueOrNull ?? [],
                            selectedId: _selectedCategoryId,
                            onChanged: (id) => setState(
                              () => _selectedCategoryId = id,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _FormCard(
                        title: 'Pricing',
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _Field(
                                  ctrl: _unitPriceCtrl,
                                  label: 'Selling Price',
                                  hint: '0.00',
                                  required: true,
                                  prefix: '\$',
                                  keyboardType:
                                      const TextInputType
                                          .numberWithOptions(
                                    decimal: true,
                                  ),
                                  validator: (v) {
                                    final d =
                                        double.tryParse(v ?? '');
                                    if (d == null) {
                                      return 'Enter a number';
                                    }
                                    if (d <= 0) {
                                      return 'Must be > 0';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _Field(
                                  ctrl: _costPriceCtrl,
                                  label: 'Cost Price',
                                  hint: '0.00',
                                  prefix: '\$',
                                  keyboardType:
                                      const TextInputType
                                          .numberWithOptions(
                                    decimal: true,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return null;
                                    }
                                    final d = double.tryParse(v);
                                    if (d == null) {
                                      return 'Enter a number';
                                    }
                                    if (d < 0) {
                                      return 'Must be >= 0';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          _Field(
                            ctrl: _taxRateCtrl,
                            label: 'Tax Rate',
                            hint: '0',
                            suffix: '%',
                            keyboardType:
                                const TextInputType
                                    .numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return null;
                              }
                              final d = double.tryParse(v);
                              if (d == null) {
                                return 'Enter a number';
                              }
                              if (d < 0 || d > 100) {
                                return '0–100 only';
                              }
                              return null;
                            },
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
          Icon(Icons.error_outline, color: cs.onErrorContainer),
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

class _FormCard extends StatelessWidget {
  const _FormCard({
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
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    letterSpacing: 0.5,
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

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.label,
    this.hint,
    this.required = false,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController ctrl;
  final String label;
  final String? hint;
  final bool required;
  final String? prefix;
  final String? suffix;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          prefixText: prefix,
          suffixText: suffix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        validator: validator,
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.categories,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final flat = _flattenCategories(categories);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String?>(
        initialValue: selectedId,
        decoration: InputDecoration(
          labelText: 'Category',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('None'),
          ),
          ...flat.map(
            (c) => DropdownMenuItem<String?>(
              value: c.id,
              child: Text(c.name),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
