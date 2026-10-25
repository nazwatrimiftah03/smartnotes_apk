import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../core/app_events.dart';
import '../../core/app_theme.dart';
import '../../core/category_style.dart';
import '../../core/formatters.dart';
import '../../models/category.dart';
import '../../models/transaction_item.dart';
import '../../models/wallet.dart';
import '../../services/category_service.dart';
import '../../services/transaction_service.dart';
import '../../services/wallet_service.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/user_avatar.dart';
import '../transactions/transaction_form_screen.dart';
import '../wallets/wallets_screen.dart';

class _HomeData {
  final List<Wallet> wallets;
  final List<Category> categories;
  final MonthSummary summary;
  final Map<String, double> expenseByCategory;
  final List<TransactionItem> recent;

  _HomeData({
    required this.wallets,
    required this.categories,
    required this.summary,
    required this.expenseByCategory,
    required this.recent,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _walletService = WalletService();
  final _categoryService = CategoryService();
  final _trxService = TransactionService();

  _HomeData? _data;
  String? _error;
  bool _loading = true;

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
      final now = DateTime.now();
      final results = await Future.wait<dynamic>([
        _walletService.getWallets(),
        _categoryService.getCategories(),
        _trxService.getMonthSummary(now),
        _trxService.getExpenseByCategory(now),
        _trxService.getTransactions(limit: 6),
      ]);

      if (!mounted) return;
      setState(() {
        _data = _HomeData(
          wallets: results[0] as List<Wallet>,
          categories: results[1] as List<Category>,
          summary: results[2] as MonthSummary,
          expenseByCategory: results[3] as Map<String, double>,
          recent: results[4] as List<TransactionItem>,
        );
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

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openTransactionForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Catat'),
      ),
      body: SafeArea(
        bottom: false,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final data = _data;

    if (data == null) {
      if (_loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48),
              const SizedBox(height: 12),
              Text(_error ?? 'Gagal memuat data.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }

    final user = Supabase.instance.client.auth.currentUser;
    final name = (user?.userMetadata?['full_name'] as String?) ?? 'Pengguna';
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          // ===== Header =====
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                      Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              UserAvatar(name: name),
            ],
          ),
          const SizedBox(height: 18),

          // ===== Kartu saldo =====
          _buildHero(data),
          const SizedBox(height: 26),

          // ===== Dompet =====
          Row(
            children: [
              const Expanded(child: _SectionTitle('Dompet')),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WalletsScreen()),
                ),
                child: const Text('Kelola'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildWallets(data),
          const SizedBox(height: 26),

          // ===== Pengeluaran per kategori =====
          const _SectionTitle('Pengeluaran bulan ini'),
          const SizedBox(height: 10),
          _buildSpending(context, data),
          const SizedBox(height: 26),

          // ===== Transaksi terakhir =====
          const _SectionTitle('Transaksi terakhir'),
          const SizedBox(height: 10),
          _buildRecent(context, data),
        ],
      ),
    );
  }

  Widget _buildHero(_HomeData data) {
    final total = data.wallets.fold<double>(0, (sum, w) => sum + w.balance);

    return SoftCard(
      gradient: AppColors.heroGradient,
      padding: EdgeInsets.zero,
      radius: 28,
      child: Stack(
        children: [
          const Positioned(
            right: -40,
            top: -40,
            child: _GlassCircle(size: 150, alpha: 0.12),
          ),
          const Positioned(
            right: 40,
            bottom: -60,
            child: _GlassCircle(size: 120, alpha: 0.08),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Total saldo',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        Fmt.bulanTahun(DateTime.now()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Fmt.rupiah(total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.south_west_rounded,
                        label: 'Pemasukan',
                        value: data.summary.income,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.north_east_rounded,
                        label: 'Pengeluaran',
                        value: data.summary.expense,
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

  Widget _buildWallets(_HomeData data) {
    if (data.wallets.isEmpty) {
      return const _EmptyHint(
        icon: Icons.account_balance_wallet_outlined,
        text: 'Belum ada dompet.',
      );
    }

    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: data.wallets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final w = data.wallets[i];
          final scheme = Theme.of(context).colorScheme;

          return SizedBox(
            width: 170,
            child: SoftCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          w.icon,
                          size: 18,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          w.typeLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Fmt.rupiah(w.balance),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpending(BuildContext context, _HomeData data) {
    final catById = {for (final c in data.categories) c.id: c};
    final entries = data.expenseByCategory.entries
        .where((e) => catById.containsKey(e.key) && e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return const _EmptyHint(
        icon: Icons.donut_large_rounded,
        text: 'Belum ada pengeluaran bulan ini.',
      );
    }

    final total = entries.fold<double>(0, (s, e) => s + e.value);
    final scheme = Theme.of(context).colorScheme;

    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 36,
                sections: [
                  for (final e in entries)
                    PieChartSectionData(
                      value: e.value,
                      color: catById[e.key]!.colorValue,
                      radius: 22,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: [
                for (final e in entries.take(4))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: catById[e.key]!.colorValue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            catById[e.key]!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          '${(e.value / total * 100).round()}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecent(BuildContext context, _HomeData data) {
    if (data.recent.isEmpty) {
      return const _EmptyHint(
        icon: Icons.receipt_long_outlined,
        text: 'Belum ada transaksi.\nTap tombol Catat untuk memulai.',
      );
    }

    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < data.recent.length; i++) ...[
            _TransactionTile(item: data.recent[i]),
            if (i != data.recent.length - 1)
              Divider(
                height: 1,
                indent: 72,
                endIndent: 16,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
          ],
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

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;

  const _MiniStat({
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

class _TransactionTile extends StatelessWidget {
  final TransactionItem item;

  const _TransactionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = CategoryStyle.color(item.categoryColor);
    final hasNote = item.note != null && item.note!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(CategoryStyle.icon(item.categoryIcon), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  hasNote
                      ? item.note!.trim()
                      : '${item.walletName} • ${Fmt.tanggal(item.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
            '${item.isIncome ? '+' : '-'} ${Fmt.rupiah(item.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: item.isIncome ? AppColors.income : AppColors.expense,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      child: Column(
        children: [
          Icon(icon, size: 34, color: scheme.primary),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}