import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/app_events.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/thousands_formatter.dart';
import '../../models/category.dart';
import '../../models/transaction_item.dart';
import '../../models/wallet.dart';
import '../../services/category_service.dart';
import '../../services/transaction_service.dart';
import '../../services/wallet_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/soft_card.dart';

/// Buka form. Kalau [item] diisi, form dalam mode ubah.
Future<void> openTransactionForm(
    BuildContext context, {
      TransactionItem? item,
    }) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => TransactionFormScreen(item: item)),
  );
}

class TransactionFormScreen extends StatefulWidget {
  final TransactionItem? item;

  const TransactionFormScreen({super.key, this.item});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountC = TextEditingController();
  final _noteC = TextEditingController();

  final _walletService = WalletService();
  final _categoryService = CategoryService();
  final _trxService = TransactionService();

  List<Wallet> _wallets = [];
  List<Category> _categories = [];

  String _type = 'expense';
  String? _walletId;
  String? _categoryId;
  DateTime _date = DateTime.now();

  bool _loading = true;
  bool _saving = false;
  bool _categoryError = false;
  String? _loadError;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();

    final item = widget.item;
    if (item != null) {
      _type = item.type;
      _walletId = item.walletId;
      _categoryId = item.categoryId;
      _date = item.date;
      _noteC.text = item.note ?? '';
      _amountC.text = ThousandsFormatter()
          .formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: item.amount.round().toString()),
      )
          .text;
    }

    _loadOptions();
  }

  @override
  void dispose() {
    _amountC.dispose();
    _noteC.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait<dynamic>([
        _walletService.getWallets(),
        _categoryService.getCategories(),
      ]);

      final wallets = results[0] as List<Wallet>;
      final categories = results[1] as List<Category>;

      if (!mounted) return;
      setState(() {
        _wallets = wallets;
        _categories = categories;

        final walletExists = wallets.any((w) => w.id == _walletId);
        if (!walletExists) {
          _walletId = wallets.isEmpty ? null : wallets.first.id;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = errorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_walletId == null) {
      _showSnack('Pilih dompet dulu.');
      return;
    }
    if (_categoryId == null) {
      setState(() => _categoryError = true);
      return;
    }

    final amount = double.parse(_amountC.text.replaceAll('.', ''));

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _trxService.updateTransaction(
          id: widget.item!.id,
          walletId: _walletId!,
          categoryId: _categoryId,
          type: _type,
          amount: amount,
          date: _date,
          note: _noteC.text,
        );
      } else {
        await _trxService.addTransaction(
          walletId: _walletId!,
          categoryId: _categoryId,
          type: _type,
          amount: amount,
          date: _date,
          note: _noteC.text,
        );
      }

      AppEvents.notifyDataChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      _showSnack(errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus transaksi?',
      message: 'Transaksi ini akan dihapus permanen.',
    );
    if (!ok) return;

    try {
      await _trxService.deleteTransaction(widget.item!.id);
      AppEvents.notifyDataChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      _showSnack(errorMessage(e));
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Ubah transaksi' : 'Catat transaksi'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(_loadError!, textAlign: TextAlign.center),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final accent = _type == 'income' ? AppColors.income : AppColors.expense;
    final cats = _categories.where((c) => c.type == _type).toList();

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          _TypeToggle(
            type: _type,
            onChanged: (value) {
              if (value == _type) return;
              setState(() {
                _type = value;
                _categoryId = null;
                _categoryError = false;
              });
            },
          ),
          const SizedBox(height: 22),

          const _Label('Nominal'),
          TextFormField(
            controller: _amountC,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
            decoration: InputDecoration(
              hintText: '0',
              prefixText: 'Rp ',
              prefixStyle: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            validator: (v) {
              final n = double.tryParse((v ?? '').replaceAll('.', '')) ?? 0;
              return n > 0 ? null : 'Masukkan nominal lebih dari 0';
            },
          ),
          const SizedBox(height: 22),

          const _Label('Kategori'),
          if (cats.isEmpty)
            Text(
              'Belum ada kategori untuk jenis ini.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in cats)
                  _PickChip(
                    icon: c.iconData,
                    label: c.name,
                    color: c.colorValue,
                    selected: _categoryId == c.id,
                    onTap: () => setState(() {
                      _categoryId = c.id;
                      _categoryError = false;
                    }),
                  ),
              ],
            ),
          if (_categoryError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Pilih salah satu kategori',
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
            ),
          const SizedBox(height: 22),

          const _Label('Dompet'),
          if (_wallets.isEmpty)
            Text(
              'Belum ada dompet.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final w in _wallets)
                  _PickChip(
                    icon: w.icon,
                    label: w.name,
                    color: scheme.primary,
                    selected: _walletId == w.id,
                    onTap: () => setState(() => _walletId = w.id),
                  ),
              ],
            ),
          const SizedBox(height: 22),

          const _Label('Tanggal'),
          SoftCard(
            onTap: _pickDate,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    Fmt.tanggal(_date),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant),
              ],
            ),
          ),
          const SizedBox(height: 22),

          const _Label('Catatan (opsional)'),
          TextFormField(
            controller: _noteC,
            maxLength: 100,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Contoh: makan siang bareng teman',
            ),
          ),
          const SizedBox(height: 12),

          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: accent),
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
        ],
      ),
    );
  }
}

// =====================  Komponen kecil  =====================

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final String type;
  final ValueChanged<String> onChanged;

  const _TypeToggle({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget segment(String label, String value, Color color) {
      final selected = type == value;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          segment('Pengeluaran', 'expense', AppColors.expense),
          segment('Pemasukan', 'income', AppColors.income),
        ],
      ),
    );
  }
}

class _PickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PickChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.16)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : scheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}