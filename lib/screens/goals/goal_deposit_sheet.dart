import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/app_events.dart';
import '../../core/formatters.dart';
import '../../core/thousands_formatter.dart';
import '../../models/savings_goal.dart';
import '../../services/goal_service.dart';

/// Sheet untuk menyetor atau menarik tabungan dari sebuah target.
Future<void> showGoalDeposit(BuildContext context, SavingsGoal goal) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _GoalDeposit(goal: goal),
  );
}

class _GoalDeposit extends StatefulWidget {
  final SavingsGoal goal;

  const _GoalDeposit({required this.goal});

  @override
  State<_GoalDeposit> createState() => _GoalDepositState();
}

class _GoalDepositState extends State<_GoalDeposit> {
  static const List<int> _quick = [50000, 100000, 250000, 500000];

  final _formKey = GlobalKey<FormState>();
  final _amountC = TextEditingController();
  final _service = GoalService();

  bool _isDeposit = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountC.dispose();
    super.dispose();
  }

  double _parse(String s) => double.tryParse(s.replaceAll('.', '')) ?? 0;

  void _setQuick(int v) {
    _amountC.text = ThousandsFormatter()
        .formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: v.toString()),
    )
        .text;
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = _parse(_amountC.text);
    final newSaved = widget.goal.savedAmount + (_isDeposit ? amount : -amount);

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _service.setSaved(widget.goal.id, newSaved);
      AppEvents.notifyDataChanged();
      if (!mounted) return;
      Navigator.of(context).pop();

      final reached = _isDeposit &&
          !widget.goal.isDone &&
          newSaved >= widget.goal.targetAmount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reached
                ? 'Selamat! Target "${widget.goal.name}" tercapai.'
                : (_isDeposit ? 'Tabungan ditambahkan.' : 'Tabungan ditarik.'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final g = widget.goal;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              g.name,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              'Terkumpul ${Fmt.rupiah(g.savedAmount)} dari ${Fmt.rupiah(g.targetAmount)}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Setor'),
                  icon: Icon(Icons.add_rounded),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Tarik'),
                  icon: Icon(Icons.remove_rounded),
                ),
              ],
              selected: {_isDeposit},
              onSelectionChanged: (s) => setState(() {
                _isDeposit = s.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountC,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsFormatter()],
              decoration: const InputDecoration(
                labelText: 'Jumlah',
                prefixText: 'Rp ',
                hintText: '0',
              ),
              validator: (v) {
                final n = _parse(v ?? '');
                if (n <= 0) return 'Jumlah harus lebih dari 0';
                if (!_isDeposit && n > g.savedAmount) {
                  return 'Melebihi tabungan yang terkumpul';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in _quick)
                  ActionChip(
                    label: Text(Fmt.rupiah(v)),
                    onPressed: () => _setQuick(v),
                  ),
              ],
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
                  : Text(_isDeposit ? 'Setor tabungan' : 'Tarik tabungan'),
            ),
          ],
        ),
      ),
    );
  }
}