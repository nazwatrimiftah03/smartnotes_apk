import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/app_events.dart';
import '../../core/formatters.dart';
import '../../core/thousands_formatter.dart';
import '../../models/category.dart';
import '../../models/recurring_rule.dart';
import '../../models/wallet.dart';
import '../../services/category_service.dart';
import '../../services/recurring_service.dart';
import '../../services/wallet_service.dart';
import '../../widgets/confirm_dialog.dart';

/// Form aturan transaksi berulang. Kalau [rule] diisi, mode ubah.
Future<void> showRecurringForm(BuildContext context, {RecurringRule? rule}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RecurringForm(rule: rule),
  );
}

class _RecurringForm extends StatefulWidget {
  final RecurringRule? rule;

  const _RecurringForm({required this.rule});

  @override
  State<_RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends State<_RecurringForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _amountC = TextEditingController();
  final _service = RecurringService();

  List<Category> _categories = [];
  List<Wallet> _wallets = [];
  bool _loading = true;

  String _type = 'expense';
  String? _categoryId;
  String? _walletId;
  String _frequency = 'monthly';
  late DateTime _date;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.rule != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);

    final r = widget.rule;
    if (r != null) {
      _nameC.text = r.name;
      _amountC.text = ThousandsFormatter()
          .formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: r.amount.round().toString()),
      )
          .text;
      _type = r.type;
      _categoryId = r.categoryId;
      _walletId = r.walletId;
      _frequency = r.frequency;
      _date = r.nextDate;
    }
    _loadOptions();
  }

  @override
  void dispose() {
    _nameC.dispose();
    _amountC.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait<dynamic>([
        CategoryService().getCategories(),
        WalletService().getWallets(),
      ]);
      if (!mounted) return;
      final wallets = results[1] as List<Wallet>;
      setState(() {
        _categories = results[0] as List<Category>;
        _wallets = wallets;
        _walletId ??= wallets.isEmpty ? null : wallets.first.id;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _loading = false;
      });
    }
  }

  double _parse(String s) => double.tryParse(s.replaceAll('.', '')) ?? 0;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = _date.isBefore(today) ? _date : today;

    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: first,
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_categoryId == null) {
      setState(() => _error = 'Pilih kategori dulu.');
      return;
    }
    if (_walletId == null) {
      setState(() => _error = 'Pilih dompet dulu.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await _service.updateRule(
          id: widget.rule!.id,
          name: _nameC.text.trim(),
          type: _type,
          amount: _parse(_amountC.text),
          walletId: _walletId!,
          categoryId: _categoryId,
          frequency: _frequency,
          nextDate: _date,
        );
      } else {
        await _service.addRule(
          name: _nameC.text.trim(),
          type: _type,
          amount: _parse(_amountC.text),
          walletId: _walletId!,
          categoryId: _categoryId,
          frequency: _frequency,
          startDate: _date,
        );
      }

      // Kalau tanggalnya hari ini, langsung dicatat.
      final created = await _service.processDue();
      AppEvents.notifyDataChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
      if (created > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$created transaksi langsung dicatat.')),
        );
      }
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
      title: 'Hapus aturan?',
      message:
      'Aturan "${widget.rule!.name}" dihapus. Transaksi yang sudah tercatat tidak ikut terhapus.',
    );
    if (!ok) return;

    try {
      await _service.deleteRule(widget.rule!.id);
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
    final cats = _categories.where((c) => c.type == _type).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Ubah aturan' : 'Aturan berulang baru',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: 'expense',
                  label: Text('Pengeluaran'),
                  icon: Icon(Icons.north_east_rounded),
                ),
                ButtonSegment(
                  value: 'income',
                  label: Text('Pemasukan'),
                  icon: Icon(Icons.south_west_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameC,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama',
                hintText: 'Contoh: Listrik, Netflix, Gaji',
                counterText: '',
              ),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amountC,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsFormatter()],
              decoration: const InputDecoration(
                labelText: 'Jumlah',
                prefixText: 'Rp ',
                hintText: '0',
              ),
              validator: (v) =>
              _parse(v ?? '') <= 0 ? 'Jumlah harus lebih dari 0' : null,
            ),
            const SizedBox(height: 18),
            const Text('Kategori',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in cats)
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
              ),
            const SizedBox(height: 18),
            const Text('Dompet', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final w in _wallets)
                  ChoiceChip(
                    avatar: Icon(w.icon, size: 18),
                    label: Text(w.name),
                    selected: _walletId == w.id,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _walletId = w.id),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Diulang', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in RecurringRule.frequencyLabels.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _frequency == e.key,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _frequency = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: _isEdit ? 'Tanggal berikutnya' : 'Mulai tanggal',
                  prefixIcon: const Icon(Icons.event_rounded),
                ),
                child: Text(Fmt.tanggal(_date)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Transaksi dicatat otomatis saat tanggalnya tiba, ketika aplikasi dibuka.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: (_saving || _loading) ? null : _save,
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
                label: const Text('Hapus aturan'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}