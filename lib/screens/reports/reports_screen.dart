import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_error.dart';
import '../../core/app_events.dart';
import '../../core/app_theme.dart';
import '../../core/category_style.dart';
import '../../core/formatters.dart';
import '../../core/month_utils.dart';
import '../../models/transaction_item.dart';
import '../../services/report_service.dart';
import '../../services/transaction_service.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/transaction_tile.dart';

class _CatTotal {
  final String name;
  final String icon;
  final String color;
  double total = 0;

  _CatTotal(this.name, this.icon, this.color);
}

class _ReportData {
  final DateTime month;
  final List<MonthTotal> trend;
  final List<TransactionItem> items;

  late final double income;
  late final double expense;
  late final MonthTotal? prev;
  late final List<double> daily;
  late final List<_CatTotal> expenseCats;
  late final List<_CatTotal> incomeCats;
  late final List<TransactionItem> topExpenses;

  _ReportData(this.month, this.trend, this.items) {
    income = trend.last.income;
    expense = trend.last.expense;
    prev = trend.length >= 2 ? trend[trend.length - 2] : null;

    final days = MonthUtils.lastDay(month).day;
    final d = List<double>.filled(days, 0);
    final exp = <String, _CatTotal>{};
    final inc = <String, _CatTotal>{};

    for (final t in items) {
      final map = t.isIncome ? inc : exp;
      final key = t.categoryId ?? 'none';
      final c = map.putIfAbsent(
        key,
            () => _CatTotal(t.categoryName, t.categoryIcon, t.categoryColor),
      );
      c.total += t.amount;
      if (!t.isIncome) d[t.date.day - 1] += t.amount;
    }

    daily = d;
    expenseCats = exp.values.toList()..sort((a, b) => b.total.compareTo(a.total));
    incomeCats = inc.values.toList()..sort((a, b) => b.total.compareTo(a.total));
    topExpenses = (items.where((t) => !t.isIncome).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount)))
        .take(5)
        .toList();
  }

  double get net => income - expense;
  bool get isEmpty => items.isEmpty && income == 0 && expense == 0;
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _reportService = ReportService();
  final _trxService = TransactionService();

  DateTime _month = MonthUtils.firstDay(DateTime.now());
  _ReportData? _data;
  bool _loading = true;
  bool _showExpense = true;
  String? _error;
  int _requestId = 0;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

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
    final id = ++_requestId;
    final month = _month;
    if (!_loading && mounted) setState(() => _loading = true);

    try {
      final results = await Future.wait<dynamic>([
        _reportService.getTrend(month),
        _trxService.getTransactions(
          from: MonthUtils.firstDay(month),
          to: MonthUtils.lastDay(month),
          limit: 1000,
        ),
      ]);

      if (!mounted || id != _requestId) return;
      setState(() {
        _data = _ReportData(
          month,
          results[0] as List<MonthTotal>,
          results[1] as List<TransactionItem>,
        );
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = errorMessage(e);
        _loading = false;
      });
    }
  }

  void _changeMonth(DateTime m) {
    setState(() => _month = MonthUtils.firstDay(m));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: Column(
        children: [
          _buildMonthSwitcher(),
          SizedBox(
            height: 3,
            child: _loading && _data != null
                ? const LinearProgressIndicator()
                : null,
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildMonthSwitcher() {
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
            onPressed: _isCurrentMonth
                ? null
                : () => _changeMonth(MonthUtils.nextMonth(_month)),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final data = _data;

    if (data == null) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48),
              const SizedBox(height: 12),
              Text(_error ?? 'Gagal memuat laporan.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    if (data.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 110),
        children: [
          Icon(Icons.insights_rounded, size: 60, color: scheme.primary),
          const SizedBox(height: 14),
          Text(
            'Belum ada data bulan ini',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Catat transaksi dulu, nanti laporannya muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          _buildHero(data),
          ..._buildCompare(data),
          const SizedBox(height: 26),
          const _SectionTitle('Tren 6 bulan terakhir'),
          const SizedBox(height: 10),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _TrendChart(
              trend: data.trend,
              selected: data.month,
              onSelect: _changeMonth,
            ),
          ),
          const SizedBox(height: 26),
          const _SectionTitle('Sekilas bulan ini'),
          const SizedBox(height: 10),
          _buildInsights(data),
          const SizedBox(height: 26),
          const _SectionTitle('Pengeluaran harian'),
          const SizedBox(height: 10),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _DailyChart(daily: data.daily),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              const Expanded(child: _SectionTitle('Per kategori')),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(value: true, label: Text('Keluar')),
                  ButtonSegment(value: false, label: Text('Masuk')),
                ],
                selected: {_showExpense},
                onSelectionChanged: (s) =>
                    setState(() => _showExpense = s.first),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildCategories(data),
          if (data.topExpenses.isNotEmpty) ...[
            const SizedBox(height: 26),
            const _SectionTitle('Pengeluaran terbesar'),
            const SizedBox(height: 10),
            SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < data.topExpenses.length; i++) ...[
                    TransactionTile(item: data.topExpenses[i]),
                    if (i != data.topExpenses.length - 1)
                      Divider(
                        height: 1,
                        indent: 72,
                        endIndent: 16,
                        color: scheme.outlineVariant,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHero(_ReportData d) {
    final net = d.net;
    final netText =
        '${net < 0 ? '- ' : ''}${Fmt.rupiah(net.abs())}';
    final saved = d.income > 0 ? (net / d.income) : null;

    String caption;
    if (d.income <= 0) {
      caption = 'Belum ada pemasukan bulan ini';
    } else if (net >= 0) {
      caption = 'Kamu menyisihkan ${(saved! * 100).round()}% dari pemasukan';
    } else {
      caption = 'Pengeluaran melebihi pemasukan';
    }

    final ratio =
    d.income <= 0 ? (d.expense > 0 ? 1.0 : 0.0) : (d.expense / d.income);

    return SoftCard(
      gradient: AppColors.heroGradient,
      padding: EdgeInsets.zero,
      radius: 28,
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: _GlassCircle(size: 150, alpha: 0.12),
          ),
          Positioned(
            left: -30,
            bottom: -70,
            child: _GlassCircle(size: 140, alpha: 0.08),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selisih bulan ini',
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
                    netText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.28),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  caption,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _HeroStat(
                        icon: Icons.south_west_rounded,
                        label: 'Pemasukan',
                        value: d.income,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HeroStat(
                        icon: Icons.north_east_rounded,
                        label: 'Pengeluaran',
                        value: d.expense,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCompare(_ReportData d) {
    final prev = d.prev;
    if (prev == null || prev.expense <= 0) return const [];

    final pct = ((d.expense - prev.expense) / prev.expense * 100).round();
    final up = pct > 0;
    final color = pct == 0
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : (up ? AppColors.expense : AppColors.income);

    final text = pct == 0
        ? 'Pengeluaran sama seperti bulan lalu'
        : 'Pengeluaran ${up ? 'naik' : 'turun'} ${pct.abs()}% dari bulan lalu';

    return [
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(
              pct == 0
                  ? Icons.drag_handle_rounded
                  : (up
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded),
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildInsights(_ReportData d) {
    final now = DateTime.now();
    final daysInMonth = d.daily.length;
    final elapsed = _isCurrentMonth ? now.day : daysInMonth;
    final avg = elapsed <= 0 ? 0.0 : d.expense / elapsed;

    var maxDay = 0;
    for (var i = 1; i < d.daily.length; i++) {
      if (d.daily[i] > d.daily[maxDay]) maxDay = i;
    }
    final maxAmount = d.daily.isEmpty ? 0.0 : d.daily[maxDay];
    final maxDate = DateTime(d.month.year, d.month.month, maxDay + 1);

    final topCat = d.expenseCats.isEmpty ? null : d.expenseCats.first;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InsightCard(
                icon: Icons.calendar_view_day_rounded,
                color: const Color(0xFF42A5F5),
                label: 'Rata-rata harian',
                value: Fmt.rupiah(avg),
                sub: 'pengeluaran per hari',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InsightCard(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.expense,
                label: 'Hari terboros',
                value: maxAmount > 0 ? Fmt.rupiah(maxAmount) : '-',
                sub: maxAmount > 0
                    ? DateFormat('d MMMM', 'id_ID').format(maxDate)
                    : 'belum ada',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _InsightCard(
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFFAB47BC),
                label: 'Jumlah transaksi',
                value: '${d.items.length}',
                sub: 'bulan ini',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InsightCard(
                icon: topCat == null
                    ? Icons.category_rounded
                    : CategoryStyle.icon(topCat.icon),
                color: topCat == null
                    ? const Color(0xFF78909C)
                    : CategoryStyle.color(topCat.color),
                label: 'Kategori terbesar',
                value: topCat?.name ?? '-',
                sub: topCat == null ? 'belum ada' : Fmt.rupiah(topCat.total),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategories(_ReportData d) {
    final scheme = Theme.of(context).colorScheme;
    final list = _showExpense ? d.expenseCats : d.incomeCats;

    if (list.isEmpty) {
      return SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        child: Center(
          child: Text(
            _showExpense
                ? 'Belum ada pengeluaran bulan ini.'
                : 'Belum ada pemasukan bulan ini.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final total = list.fold<double>(0, (s, c) => s + c.total);

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        children: [
          for (final c in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _CategoryRow(cat: c, total: total),
            ),
        ],
      ),
    );
  }
}

// =====================  Komponen kecil  =====================

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _GlassCircle extends StatelessWidget {
  final double size;
  final double alpha;

  const _GlassCircle({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;

  const _HeroStat({
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

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;

  const _InsightCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final _CatTotal cat;
  final double total;

  const _CategoryRow({required this.cat, required this.total});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = CategoryStyle.color(cat.color);
    final pct = total <= 0 ? 0.0 : cat.total / total;

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(CategoryStyle.icon(cat.icon), size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                cat.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Fmt.rupiah(cat.total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${(pct * 100).round()}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 7,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}

/// Grafik batang pemasukan vs pengeluaran 6 bulan. Tap bulan untuk memilihnya.
class _TrendChart extends StatelessWidget {
  static const double _barArea = 130;

  final List<MonthTotal> trend;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  const _TrendChart({
    required this.trend,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    var maxV = 1.0;
    for (final t in trend) {
      maxV = math.max(maxV, math.max(t.income, t.expense));
    }

    Widget bar(double v, Color color, bool active) {
      final h = v <= 0 ? 3.0 : math.max(4.0, _barArea * v / maxV);
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: h),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (_, value, _) => Container(
          width: 12,
          height: value,
          decoration: BoxDecoration(
            color: color.withValues(alpha: v <= 0 ? 0.25 : (active ? 1 : 0.5)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            const _LegendDot(color: AppColors.income, label: 'Pemasukan'),
            const SizedBox(width: 16),
            const _LegendDot(color: AppColors.expense, label: 'Pengeluaran'),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final t in trend)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelect(t.month),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        SizedBox(
                          height: _barArea,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              bar(
                                t.income,
                                AppColors.income,
                                _same(t.month, selected),
                              ),
                              const SizedBox(width: 3),
                              bar(
                                t.expense,
                                AppColors.expense,
                                _same(t.month, selected),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _same(t.month, selected)
                                ? scheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            DateFormat('MMM', 'id_ID').format(t.month),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _same(t.month, selected)
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: _same(t.month, selected)
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

/// Batang kecil pengeluaran per hari sepanjang bulan.
class _DailyChart extends StatelessWidget {
  static const double _height = 90;

  final List<double> daily;

  const _DailyChart({required this.daily});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxV = daily.fold<double>(0, math.max);

    if (maxV <= 0) {
      return SizedBox(
        height: 60,
        child: Center(
          child: Text(
            'Belum ada pengeluaran bulan ini.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: _height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final v in daily)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: v <= 0 ? 3.0 : math.max(4.0, _height * v / maxV),
                      ),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (_, h, _) => Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: v <= 0
                                ? scheme.surfaceContainerHighest
                                : (v == maxV
                                ? AppColors.expense
                                : AppColors.primary.withValues(alpha: 0.6)),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1', style: _axisStyle(scheme)),
            Text('${(daily.length / 2).round()}', style: _axisStyle(scheme)),
            Text('${daily.length}', style: _axisStyle(scheme)),
          ],
        ),
      ],
    );
  }

  TextStyle _axisStyle(ColorScheme s) =>
      TextStyle(fontSize: 11, color: s.onSurfaceVariant);
}