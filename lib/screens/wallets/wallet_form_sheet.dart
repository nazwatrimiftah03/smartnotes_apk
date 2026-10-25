import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/app_events.dart';
import '../../core/thousands_formatter.dart';
import '../../models/wallet.dart';
import '../../services/wallet_service.dart';
import '../../widgets/confirm_dialog.dart';

/// Buka form dompet. Kalau [wallet] diisi, form dalam mode ubah.
Future<void> showWalletForm(
    BuildContext context, {
      Wallet? wallet,
      bool canDelete = true,
    }) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _WalletForm(wallet: wallet, canDelete: canDelete),
  );
}

class _WalletForm extends StatefulWidget {
  final Wallet? wallet;
  final bool canDelete;

  const _WalletForm({required this.wallet, required this.canDelete});

  @override
  State<_WalletForm> createState() => _WalletFormState();
}

class _WalletFormState extends State<_WalletForm> {
  static const Map<String, IconData> _typeIcons = {
    'cash': Icons.payments,
    'bank': Icons.account_balance,
    'ewallet': Icons.phone_android,
    'other': Icons.wallet,
  };

  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _balanceC = TextEditingController();
  final _service = WalletService();

  String _type = 'cash';
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.wallet != null;

  @override
  void initState() {
    super.initState();
    final w = widget.wallet;
    if (w != null) {
      _nameC.text = w.name;
      _type = w.type;
      if (w.initialBalance > 0) {
        _balanceC.text = ThousandsFormatter()
            .formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: w.initialBalance.round().toString()),
        )
            .text;
      }
    }
  }

  @override
  void dispose() {
    _nameC.dispose();
    _balanceC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final balance = double.tryParse(_balanceC.text.replaceAll('.', '')) ?? 0;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await _service.updateWallet(
          id: widget.wallet!.id,
          name: _nameC.text.trim(),
          type: _type,
          initialBalance: balance,
        );
      } else {
        await _service.addWallet(
          name: _nameC.text.trim(),
          type: _type,
          initialBalance: balance,
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
      title: 'Hapus dompet?',
      message:
      'Dompet "${widget.wallet!.name}" beserta semua transaksi di dalamnya akan dihapus permanen.',
    );
    if (!ok) return;

    try {
      await _service.deleteWallet(widget.wallet!.id);
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
              _isEdit ? 'Ubah dompet' : 'Dompet baru',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _nameC,
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama dompet',
                hintText: 'Contoh: BCA, GoPay, Dompet Harian',
                counterText: '',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Nama dompet wajib diisi'
                  : null,
            ),
            const SizedBox(height: 16),
            const Text('Jenis', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in Wallet.typeLabels.entries)
                  ChoiceChip(
                    avatar: Icon(_typeIcons[entry.key], size: 18),
                    label: Text(entry.value),
                    selected: _type == entry.key,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _type = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _balanceC,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsFormatter()],
              decoration: const InputDecoration(
                labelText: 'Saldo awal',
                prefixText: 'Rp ',
                hintText: '0',
                helperText:
                'Saldo sekarang = saldo awal + semua pemasukan - pengeluaran.',
                helperMaxLines: 2,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 20),
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
              if (widget.canDelete)
                TextButton.icon(
                  onPressed: _saving ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Hapus dompet'),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Dompet terakhir tidak bisa dihapus. Minimal harus ada satu dompet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}