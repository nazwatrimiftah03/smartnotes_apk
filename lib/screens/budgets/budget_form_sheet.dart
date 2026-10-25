import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/app_events.dart';
import '../../core/category_style.dart';
import '../../core/thousands_formatter.dart';
import '../../models/budget.dart';
import '../../models/category.dart';
import '../../services/budget_service.dart';
import '../../services/category_service.dart';
import '../../widgets/confirm_dialog.dart';

/// Buka form anggaran untuk bulan [month].
/// Kalau [existing] diisi, form dalam mode ubah (kategori terkunci).
/// [usedCategoryIds] = kategori yang sudah punya anggaran bulan itu,
/// disembunyikan dari pilihan saat membuat baru.
Future<void> showBudgetForm(
    BuildContext context, {
      required DateTime month,
      BudgetProgress? existing,
      Set<String> usedCategoryIds = const {},
    }) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BudgetForm(
      month: month,
      existing: existing,
      usedCategoryIds: usedCategoryIds,
    ),
  );
}

class _BudgetForm extends StatefulWidget {
  final DateTime month;
  final BudgetProgress? existing;
  final Set<String> usedCategoryIds;

  const _BudgetForm({
    required this.month,
    required this.existing,
    required this.usedCategoryIds,
  });

  @override
  State<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<_BudgetForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountC = TextEditingController();
  final _service = BudgetService();
  final _categoryService = CategoryService();

  List<Category> _categories = [];
  String? _categoryId;
  bool _loadingCategories = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _categoryId = e.budget.categoryId;
      _amountC.text = ThousandsFormatter()
          .formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: e.budget.amountLimit.round().toString()),
      )
          .text;
      _loadingCategories = false;
    } else {
      _loadCategories();
    }
  }

  @override
  void dispose() {
    _amountC.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final all = await _categoryService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = all
            .where((c) =>
        c.type == 'expense' && !widget.usedCategoryIds.contains(c.id))
            .toList();
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _loadingCategories = false;
      });
    }
  }

  Future<void> _save() async {
    if (_categoryId == null) {
      setState(() => _error = 'Pilih kategori dulu.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountC.text.replaceAll('.', '')) ?? 0;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _service.setBudget(
        categoryId: _categoryId!,
        month: widget.month,
        amountLimit: amount,
      );
      AppEvents.notifyDataChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _saving = false;
      });
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus anggaran?',
      message:
      'Anggaran "${widget.existing!.budget.categoryName}" bulan ini dihapus. Transaksimu tidak terpengaruh.',
    );
    if (!ok) return;

    try {
      await _service.deleteBudget(widget.existing!.budget.id);
      AppEvents.notifyDataChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Ubah anggaran' : 'Anggaran baru',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            const Text(
              'Kategori',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _buildCategoryPicker(scheme),
            const SizedBox(height: 18),
            TextFormField(
              controller: _amountC,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsFormatter()],
              decoration: const InputDecoration(
                labelText: 'Batas per bulan',
                prefixText: 'Rp ',
                hintText: '0',
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll('.', '')) ?? 0;
                return n <= 0 ? 'Batas harus lebih dari 0' : null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: (_saving || _loadingCategories) ? null : _save,
              child: _saving
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
                  : Text(_isEdit ? 'Simpan perubahan' : 'Simpan'),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _saving ? null : _delete,
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Hapus anggaran'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPicker(ColorScheme scheme) {
    if (_isEdit) {
      final b = widget.existing!.budget;
      final color = CategoryStyle.color(b.categoryColor);
      return Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          avatar: Icon(CategoryStyle.icon(b.categoryIcon),
              size: 18, color: color),
          label: Text(b.categoryName),
        ),
      );
    }

    if (_loadingCategories) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_categories.isEmpty) {
      return Text(
        'Semua kategori pengeluaran sudah punya anggaran bulan ini.',
        style: TextStyle(color: scheme.onSurfaceVariant),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in _categories)
          ChoiceChip(
            avatar: Icon(c.iconData, size: 18, color: c.colorValue),
            label: Text(c.name),
            selected: _categoryId == c.id,
            showCheckmark: false,
            onSelected: (_) => setState(() {
              _categoryId = c.id;
              _error = null;
            }),
          ),
      ],
    );
  }
}