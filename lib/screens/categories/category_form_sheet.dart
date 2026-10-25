import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/app_events.dart';
import '../../core/category_style.dart';
import '../../models/category.dart';
import '../../services/category_service.dart';
import '../../widgets/confirm_dialog.dart';

/// Buka form kategori. [type] dipakai saat membuat kategori baru
/// ('income' atau 'expense'). Kalau [category] diisi, form mode ubah.
Future<void> showCategoryForm(
    BuildContext context, {
      required String type,
      Category? category,
    }) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CategoryForm(type: type, category: category),
  );
}

class _CategoryForm extends StatefulWidget {
  final String type;
  final Category? category;

  const _CategoryForm({required this.type, required this.category});

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _service = CategoryService();

  String _icon = 'category';
  String _color = CategoryStyle.palette.first;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.category != null;
  bool get _isIncome => widget.type == 'income';

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    if (c != null) {
      _nameC.text = c.name;
      _icon = c.icon;
      _color = c.color;
    }
  }

  @override
  void dispose() {
    _nameC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await _service.updateCategory(
          id: widget.category!.id,
          name: _nameC.text.trim(),
          icon: _icon,
          color: _color,
        );
      } else {
        await _service.addCategory(
          name: _nameC.text.trim(),
          type: widget.type,
          icon: _icon,
          color: _color,
        );
      }

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
      title: 'Hapus kategori?',
      message:
      'Transaksi lama tetap ada tetapi menjadi "Tanpa kategori". Anggaran untuk kategori ini ikut terhapus.',
    );
    if (!ok) return;

    try {
      await _service.deleteCategory(widget.category!.id);
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
    final color = CategoryStyle.color(_color);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(CategoryStyle.icon(_icon), color: color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEdit ? 'Ubah kategori' : 'Kategori baru',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        _isIncome ? 'Pemasukan' : 'Pengeluaran',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _nameC,
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama kategori',
                counterText: '',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Nama kategori wajib diisi'
                  : null,
            ),
            const SizedBox(height: 18),
            const Text('Ikon', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final entry in CategoryStyle.icons.entries)
                  GestureDetector(
                    onTap: () => setState(() => _icon = entry.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _icon == entry.key
                            ? color.withValues(alpha: 0.18)
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _icon == entry.key
                              ? color
                              : Colors.transparent,
                          width: 1.8,
                        ),
                      ),
                      child: Icon(
                        entry.value,
                        color:
                        _icon == entry.key ? color : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Warna', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final hex in CategoryStyle.palette)
                  GestureDetector(
                    onTap: () => setState(() => _color = hex),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: CategoryStyle.color(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color.toUpperCase() == hex.toUpperCase()
                              ? scheme.onSurface
                              : Colors.transparent,
                          width: 2.4,
                        ),
                      ),
                      child: _color.toUpperCase() == hex.toUpperCase()
                          ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20)
                          : null,
                    ),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _saving ? null : _save,
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
                label: const Text('Hapus kategori'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}