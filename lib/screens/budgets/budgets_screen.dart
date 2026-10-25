import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/app_events.dart';
import '../../core/app_theme.dart';
import '../../core/category_style.dart';
import '../../core/formatters.dart';
import '../../core/month_utils.dart';
import '../../models/budget.dart';
import '../../services/budget_service.dart';
import '../../widgets/soft_card.dart';
import 'budget_form_sheet.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  static const Color _warning = Color(0xFFFFA726);

  final _service = BudgetService();

  DateTime _month = MonthUtils.firstDay(DateTime.now());
  List<BudgetProgress> _items = [];
  bool _loading = true;
  bool _copying = false;
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
    final requested = _month;
    try {
      final data = await _service.getBudgets(requested);
      if (!mounted || requested != _month) return;

      data.sort((a, b) => _percent(b).compareTo(_percent(a)));

      setState(() {
        _items = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || requested != _month) return;
      setState(() {
        _error = errorMessage(e);
        _loading = false;
      });
    }
  }

  void _changeMonth(DateTime m) {
    setState(() {
      _month = MonthUtils.firstDay(m);
      _loading = true;
    });
    _load();
  }

  /// Persentase terpakai, boleh lebih dari 1.0 (100%).
  double _percent(BudgetProgress p) =>
      p.budget.amountLimit <= 0 ? 0 : p.spent / p.budget.amountLimit;

  Color _statusColor(BudgetProgress p) {
    final pct = _percent(p);
    if (pct > 1) return AppColors.expense;
    if (pct >= 0.8) return _warning;
    return AppColors.income;
  }

  Future<void> _copyFromPrevious() async {
    setState(() => _copying = true);
    try {
      final prev = await _service.getBudgets(MonthUtils.prevMonth(_month));
      if (prev.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bulan lalu tidak punya anggaran.')),
        );
      } else {
        for (final p in prev) {
          await _service.setBudget(
            categoryId: p.budget.categoryId,
            month: _month,
            amountLimit: p.budget.amountLimit,
          );
        }
        AppEvents.notifyDataChanged();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anggaran')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBudgetForm(
          context,
          month: _month,
          usedCategoryIds: _items.map((e) => e.budget.categoryId).toSet(),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Anggaran'),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final header = _buildMonthSwitcher(scheme);

    if (_loading) {
      return Column(
        children: [
          header,
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    if (_error != null && _items.isEmpty) {
      return Column(
        children: [
          header,
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        header,
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _items.isEmpty ? _buildEmpty(scheme) : _buildList(scheme),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthSwitcher(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _changeMonth(MonthUtils.prevMonth(_month)),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              Fmt.bulanTahun(_month),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: () => _changeMonth(MonthUtils.nextMonth(_month)),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(ColorScheme scheme) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 110),
      children: [
        Icon(Icons.pie_chart_rounded, size: 56, color: scheme.primary),
        const SizedBox(height: 14),
        Text(
          'Belum ada anggaran bulan ini',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Tentukan batas pengeluaran per kategori supaya uangmu lebih terkendali.',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton.icon(
            onPressed: _copying ? null : _copyFromPrevious,
            icon: _copying
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.copy_rounded),
            label: const Text('Salin dari bulan lalu'),
          ),
        ),
      ],
    );
  }

  Widget _buildList(ColorScheme scheme) {
    final totalLimit =
    _items.fold<double>(0, (s, p) => s + p.budget.amountLimit);
    final totalSpent = _items.fold<double>(0, (s, p) => s + p.spent);
    final totalRatio =
    totalLimit <= 0 ? 0.0 : (totalSpent / totalLimit).clamp(0.0, 1.0);
    final overCount = _items.where((p) => p.isOver).length;
    final nearCount =
        _items.where((p) => !p.isOver && _percent(p) >= 0.8).length;

    return ListView(
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
                'Terpakai dari total anggaran',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${Fmt.rupiah(totalSpent)} / ${Fmt.rupiah(totalLimit)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: totalRatio,
                  minHeight: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.28),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ],
          ),
        ),
        if (overCount > 0 || nearCount > 0) ...[
          const SizedBox(height: 14),
          _AlertBanner(over: overCount, near: nearCount),
        ],
        const SizedBox(height: 16),
        for (final p in _items) ...[
          _BudgetCard(
            progress: p,
            percent: _percent(p),
            color: _statusColor(p),
            onTap: () => showBudgetForm(
              context,
              month: _month,
              existing: p,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Tap anggaran untuk mengubah atau menghapus.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final int over;
  final int near;

  const _AlertBanner({required this.over, required this.near});

  @override
  Widget build(BuildContext context) {
    final isOver = over > 0;
    final color = isOver ? AppColors.expense : const Color(0xFFFFA726);

    final parts = <String>[];
    if (over > 0) parts.add('$over kategori melebihi batas');
    if (near > 0) parts.add('$near hampir habis');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              parts.join(', '),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final BudgetProgress progress;
  final double percent;
  final Color color;
  final VoidCallback onTap;

  const _BudgetCard({
    required this.progress,
    required this.percent,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final b = progress.budget;
    final catColor = CategoryStyle.color(b.categoryColor);

    final String status;
    if (progress.isOver) {
      status = 'Melebihi ${Fmt.rupiah(-progress.remaining)}';
    } else if (percent >= 0.8) {
      status = 'Hampir habis, sisa ${Fmt.rupiah(progress.remaining)}';
    } else {
      status = 'Sisa ${Fmt.rupiah(progress.remaining)}';
    }

    return SoftCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(CategoryStyle.icon(b.categoryIcon), color: catColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Fmt.rupiah(progress.spent)} dari ${Fmt.rupiah(b.amountLimit)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(percent * 100).round()}%',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.ratio,
              minHeight: 9,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: progress.isOver || percent >= 0.8
                  ? color
                  : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}