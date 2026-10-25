import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/app_events.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/month_utils.dart';
import '../../models/category.dart';
import '../../models/transaction_item.dart';
import '../../models/wallet.dart';
import '../../services/category_service.dart';
import '../../services/transaction_service.dart';
import '../../services/wallet_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/transaction_tile.dart';
import 'transaction_form_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _trxService = TransactionService();
  final _walletService = WalletService();
  final _categoryService = CategoryService();
  final _searchC = TextEditingController();

  Timer? _debounce;
  int _requestId = 0;

  DateTime _month = MonthUtils.firstDay(DateTime.now());
  String? _type;
  String? _walletId;
  String? _categoryId;

  List<TransactionItem> _items = [];
  List<Wallet> _wallets = [];
  List<Category> _categories = [];

  bool _loading = true;
  bool _loadedOnce = false;
  String? _error;

  bool get _hasFilter => _walletId != null || _categoryId != null;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  void initState() {
    super.initState();
    AppEvents.dataVersion.addListener(_onDataChanged);
    _loadFilterOptions();
    _load();
  }

  @override
  void dispose() {
    AppEvents.dataVersion.removeListener(_onDataChanged);
    _debounce?.cancel();
    _searchC.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    _loadFilterOptions();
    _load();
  }

  Future<void> _loadFilterOptions() async {
    try {
      final results = await Future.wait<dynamic>([
        _walletService.getWallets(),
        _categoryService.getCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _wallets = results[0] as List<Wallet>;
        _categories = results[1] as List<Category>;
      });
    } catch (_) {
      // Filter tetap bisa dipakai tanpa daftar ini; abaikan.
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    final id = ++_requestId;
    setState(() => _loading = true);

    try {
      final items = await _trxService.getTransactions(
        from: _month,
        to: MonthUtils.lastDay(_month),
        type: _type,
        walletId: _walletId,
        categoryId: _categoryId,
        search: _searchC.text,
        limit: 500,
      );

      if (!mounted || id != _requestId) return;
      setState(() {
        _items = items;
        _error = null;
        _loading = false;
        _loadedOnce = true;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = errorMessage(e);
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    setState(() {}); // memperbarui tombol hapus teks
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _changeMonth(DateTime month) {
    setState(() => _month = month);
    _load();
  }

  Future<void> _delete(TransactionItem item) async {
    setState(() => _items.removeWhere((t) => t.id == item.id));
    try {
      await _trxService.deleteTransaction(item.id);
      AppEvents.notifyDataChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      _load();
    }
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filter',
                            style: Theme.of(ctx)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setSheet(() {
                            _walletId = null;
                            _categoryId = null;
                          }),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Dompet',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Semua'),
                          selected: _walletId == null,
                          showCheckmark: false,
                          onSelected: (_) =>
                              setSheet(() => _walletId = null),
                        ),
                        for (final w in _wallets)
                          ChoiceChip(
                            label: Text(w.name),
                            selected: _walletId == w.id,
                            showCheckmark: false,
                            onSelected: (_) =>
                                setSheet(() => _walletId = w.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text('Kategori',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Semua'),
                          selected: _categoryId == null,
                          showCheckmark: false,
                          onSelected: (_) =>
                              setSheet(() => _categoryId = null),
                        ),
                        for (final c in _categories)
                          ChoiceChip(
                            label: Text(c.name),
                            selected: _categoryId == c.id,
                            showCheckmark: false,
                            onSelected: (_) =>
                                setSheet(() => _categoryId = c.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Terapkan'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (mounted) _load();
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    return Fmt.tanggal(day);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          IconButton(
            tooltip: 'Filter',
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: _hasFilter,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openTransactionForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Catat'),
      ),
      body: Column(
        children: [
          // Pencarian
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: TextField(
              controller: _searchC,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari catatan...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchC.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchC.clear();
                    _onSearchChanged('');
                  },
                ),
              ),
            ),
          ),

          // Pilih bulan
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => _changeMonth(MonthUtils.prevMonth(_month)),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              SizedBox(
                width: 170,
                child: Text(
                  Fmt.bulanTahun(_month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
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

          // Jenis
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _typeChip('Semua', null),
                const SizedBox(width: 8),
                _typeChip('Pemasukan', 'income'),
                const SizedBox(width: 8),
                _typeChip('Pengeluaran', 'expense'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          if (_loading && _loadedOnce)
            LinearProgressIndicator(
              minHeight: 2,
              color: scheme.primary,
              backgroundColor: Colors.transparent,
            )
          else
            const SizedBox(height: 2),

          Expanded(child: _buildList(context)),
        ],
      ),
    );
  }

  Widget _typeChip(String label, String? value) {
    return ChoiceChip(
      label: Text(label),
      selected: _type == value,
      showCheckmark: false,
      onSelected: (_) {
        setState(() => _type = value);
        _load();
      },
    );
  }

  Widget _buildList(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (!_loadedOnce) {
      if (_error != null) return _errorView();
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) return _errorView();

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 40,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Belum ada transaksi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Tidak ada data untuk bulan dan filter ini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    // Ringkasan dari data yang tampil
    var income = 0.0;
    var expense = 0.0;
    for (final t in _items) {
      if (t.isIncome) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }

    // Kelompokkan per tanggal
    final groups = <DateTime, List<TransactionItem>>{};
    for (final t in _items) {
      final key = DateTime(t.date.year, t.date.month, t.date.day);
      groups.putIfAbsent(key, () => []).add(t);
    }

    final children = <Widget>[
      SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _SummaryCell(
              label: 'Pemasukan',
              value: income,
              color: AppColors.income,
            ),
            _SummaryCell(
              label: 'Pengeluaran',
              value: expense,
              color: AppColors.expense,
            ),
            _SummaryCell(
              label: 'Selisih',
              value: income - expense,
              color: scheme.onSurface,
            ),
          ],
        ),
      ),
    ];

    groups.forEach((day, list) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(
            _dayLabel(day),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );

      children.add(
        SoftCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                Dismissible(
                  key: ValueKey(list[i].id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => showConfirmDialog(
                    context,
                    title: 'Hapus transaksi?',
                    message:
                    '${list[i].categoryName} • ${Fmt.rupiah(list[i].amount)} akan dihapus.',
                  ),
                  onDismissed: (_) => _delete(list[i]),
                  background: Container(
                    color: scheme.error.withValues(alpha: 0.15),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 22),
                    child: Icon(Icons.delete_rounded, color: scheme.error),
                  ),
                  child: TransactionTile(
                    item: list[i],
                    onTap: () => openTransactionForm(context, item: list[i]),
                  ),
                ),
                if (i != list.length - 1)
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
      );
    });

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
        children: children,
      ),
    );
  }

  Widget _errorView() {
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
}

class _SummaryCell extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SummaryCell({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Fmt.rupiah(value),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}