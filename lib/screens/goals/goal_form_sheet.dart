import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/app_events.dart';
import '../../core/category_style.dart';
import '../../core/formatters.dart';
import '../../core/thousands_formatter.dart';
import '../../models/savings_goal.dart';
import '../../services/goal_service.dart';
import '../../widgets/confirm_dialog.dart';

/// Form target tabungan. Kalau [goal] diisi, form dalam mode ubah.
Future<void> showGoalForm(BuildContext context, {SavingsGoal? goal}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _GoalForm(goal: goal),
  );
}

class _GoalForm extends StatefulWidget {
  final SavingsGoal? goal;

  const _GoalForm({required this.goal});

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  static const List<String> _icons = [
    'savings',
    'flight',
    'home',
    'phone_android',
    'school',
    'favorite',
    'shopping_bag',
    'directions_bus',
    'fitness_center',
    'card_giftcard',
    'movie',
    'pets',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _targetC = TextEditingController();
  final _savedC = TextEditingController();
  final _service = GoalService();

  String _icon = 'savings';
  String _color = CategoryStyle.palette.first;
  DateTime? _deadline;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.goal != null;

  String _fmtInput(double v) => ThousandsFormatter()
      .formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(text: v.round().toString()),
  )
      .text;

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    if (g != null) {
      _nameC.text = g.name;
      _targetC.text = _fmtInput(g.targetAmount);
      _icon = g.icon;
      _color = g.color;
      _deadline = g.deadline;
    }
  }

  @override
  void dispose() {
    _nameC.dispose();
    _targetC.dispose();
    _savedC.dispose();
    super.dispose();
  }

  double _parse(String s) => double.tryParse(s.replaceAll('.', '')) ?? 0;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await _service.updateGoal(
          id: widget.goal!.id,
          name: _nameC.text.trim(),
          targetAmount: _parse(_targetC.text),
          deadline: _deadline,
          icon: _icon,
          color: _color,
        );
      } else {
        await _service.addGoal(
          name: _nameC.text.trim(),
          targetAmount: _parse(_targetC.text),
          savedAmount: _parse(_savedC.text),
          deadline: _deadline,
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
      title: 'Hapus target?',
      message: 'Target "${widget.goal!.name}" dihapus permanen.',
    );
    if (!ok) return;

    try {
      await _service.deleteGoal(widget.goal!.id);
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
                  child: Text(
                    _isEdit ? 'Ubah target' : 'Target baru',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
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
                labelText: 'Nama target',
                hintText: 'Contoh: Liburan Bali, Laptop Baru',
                counterText: '',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Nama target wajib diisi'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _targetC,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsFormatter()],
              decoration: const InputDecoration(
                labelText: 'Jumlah target',
                prefixText: 'Rp ',
                hintText: '0',
              ),
              validator: (v) =>
              _parse(v ?? '') <= 0 ? 'Target harus lebih dari 0' : null,
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _savedC,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Sudah terkumpul (opsional)',
                  prefixText: 'Rp ',
                  hintText: '0',
                ),
              ),
            ],
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Tenggat (opsional)',
                  prefixIcon: const Icon(Icons.event_rounded),
                  suffixIcon: _deadline == null
                      ? null
                      : IconButton(
                    onPressed: () => setState(() => _deadline = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                child: Text(
                  _deadline == null ? 'Tanpa tenggat' : Fmt.tanggal(_deadline!),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Ikon', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final key in _icons)
                  GestureDetector(
                    onTap: () => setState(() => _icon = key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _icon == key
                            ? color.withValues(alpha: 0.18)
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _icon == key ? color : Colors.transparent,
                          width: 1.8,
                        ),
                      ),
                      child: Icon(
                        CategoryStyle.icon(key),
                        color: _icon == key ? color : scheme.onSurfaceVariant,
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
                label: const Text('Hapus target'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}