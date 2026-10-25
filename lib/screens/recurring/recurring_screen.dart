import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_error.dart';
import '../../core/app_events.dart';
import '../../core/app_theme.dart';
import '../../core/category_style.dart';
import '../../core/formatters.dart';
import '../../models/recurring_rule.dart';
import '../../services/recurring_service.dart';
import '../../widgets/soft_card.dart';
import 'recurring_form_sheet.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  final _service = RecurringService();

  List<RecurringRule> _rules = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    AppEvents.dataVersion.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    AppEvents.dataVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _service.getRules();
      if (!mounted) return;
      setState(() {
        _rules = data;
        _error = null;
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

  Future<void> _toggle(RecurringRule r, bool value) async {
    try {
      await _service.setActive(r, value);
      AppEvents.notifyDataChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi berulang')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => showRecurringForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Aturan baru'),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null && _rules.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    if (_rules.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 110),
        children: [
          Icon(Icons.event_repeat_rounded, size: 60, color: scheme.primary),
          const SizedBox(height: 14),
          Text(
            'Belum ada transaksi berulang',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Atur tagihan atau gaji yang rutin, nanti dicatat otomatis. Cocok untuk listrik, internet, langganan, dan gaji bulanan.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
          ),
        ],
      );
    }

    final active = _rules.where((r) => r.active).toList();
    final outMonthly = active
        .where((r) => !r.isIncome)
        .fold<double>(0, (s, r) => s + r.monthlyEquivalent);
    final inMonthly = active
        .where((r) => r.isIncome)
        .fold<double>(0, (s, r) => s + r.monthlyEquivalent);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
        children: [
          SoftCard(
            gradient: AppColors.heroGradient,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Perkiraan rutin per bulan',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryStat(
                        icon: Icons.south_west_rounded,
                        label: 'Pemasukan',
                        value: inMonthly,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryStat(
                        icon: Icons.north_east_rounded,
                        label: 'Pengeluaran',
                        value: outMonthly,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${active.length} aturan aktif dari ${_rules.length}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          for (final r in _rules) ...[
            _RuleCard(rule: r, onToggle: (v) => _toggle(r, v)),
            const SizedBox(height: 12),
          ],
          Text(
            'Tap aturan untuk mengubah atau menghapus.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;

  const _SummaryStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.28),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Fmt.rupiah(value),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final RecurringRule rule;
  final ValueChanged<bool> onToggle;

  const _RuleCard({required this.rule, required this.onToggle});

  String _schedule() {
    switch (rule.frequency) {
      case 'daily':
        return 'Setiap hari';
      case 'weekly':
        return 'Setiap ${DateFormat('EEEE', 'id_ID').format(rule.nextDate)}';
      case 'yearly':
        return 'Setiap tahun, ${DateFormat('d MMMM', 'id_ID').format(rule.nextDate)}';
      default:
        return 'Setiap bulan, tanggal ${rule.anchorDay}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = CategoryStyle.color(rule.categoryColor);
    final amountColor = rule.isIncome ? AppColors.income : AppColors.expense;

    return Opacity(
      opacity: rule.active ? 1 : 0.55,
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        onTap: () => showRecurringForm(context, rule: rule),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(CategoryStyle.icon(rule.categoryIcon), color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_schedule()} • ${rule.walletName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rule.active
                        ? 'Berikutnya ${Fmt.tanggal(rule.nextDate)}'
                        : 'Dijeda',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${rule.isIncome ? '+' : '-'} ${Fmt.rupiah(rule.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: amountColor,
                  ),
                ),
                Switch(value: rule.active, onChanged: onToggle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}