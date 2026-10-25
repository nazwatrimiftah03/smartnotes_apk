import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/month_utils.dart';
import '../../models/transaction_item.dart';
import '../../services/export_service.dart';
import '../../services/pdf_service.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/transaction_tile.dart';

class _Range {
  final String label;
  final DateTime? from;
  final DateTime? to;

  const _Range(this.label, this.from, this.to);
}

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final _service = ExportService();

  late final List<_Range> _ranges;
  int _selected = 0;

  List<TransactionItem> _items = [];
  bool _loading = true;
  bool _sharing = false;
  bool _sharingPdf = false;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final thisMonth = MonthUtils.firstDay(now);
    final lastMonth = MonthUtils.prevMonth(now);

    _ranges = [
      _Range('Bulan ini', thisMonth, MonthUtils.lastDay(now)),
      _Range('Bulan lalu', lastMonth, MonthUtils.lastDay(lastMonth)),
      _Range(
        '3 bulan terakhir',
        DateTime(now.year, now.month - 2, 1),
        MonthUtils.lastDay(now),
      ),
      _Range('Tahun ini', DateTime(now.year, 1, 1), DateTime(now.year, 12, 31)),
      const _Range('Semua data', null, null),
    ];
    _load();
  }

  Future<void> _load() async {
    final id = ++_requestId;
    final r = _ranges[_selected];

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _service.fetch(from: r.from, to: r.to);
      if (!mounted || id != _requestId) return;
      setState(() {
        _items = data;
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

  String _fileName() {
    final r = _ranges[_selected];
    if (r.from == null || r.to == null) return 'smartnotes_semua.csv';
    return 'smartnotes_${Fmt.tanggalDb(r.from!)}_${Fmt.tanggalDb(r.to!)}.csv';
  }

  String _periodLabel() {
    final r = _ranges[_selected];
    if (r.from == null || r.to == null) return 'Semua data';
    return '${Fmt.tanggal(r.from!)} - ${Fmt.tanggal(r.to!)}';
  }

  Future<void> _sharePdf() async {
    setState(() => _sharingPdf = true);
    try {
      final bytes = await PdfService.build(
        period: _periodLabel(),
        items: _items,
      );
      await _service.sharePdf(bytes, _fileName().replaceAll('.csv', '.pdf'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage(e))));
    } finally {
      if (mounted) setState(() => _sharingPdf = false);
    }
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      await _service.shareCsv(_service.buildCsv(_items), _fileName());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage(e))));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final income = _items
        .where((t) => t.isIncome)
        .fold<double>(0, (s, t) => s + t.amount);
    final expense = _items
        .where((t) => !t.isIncome)
        .fold<double>(0, (s, t) => s + t.amount);
    final preview = _items.reversed.take(5).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Ekspor data')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Pilih periode',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _ranges.length; i++)
                ChoiceChip(
                  label: Text(_ranges[i].label),
                  selected: _selected == i,
                  showCheckmark: false,
                  onSelected: (_) {
                    setState(() => _selected = i);
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),
          SoftCard(
            gradient: AppColors.heroGradient,
            padding: const EdgeInsets.all(20),
            child: _loading
                ? const SizedBox(
              height: 92,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Siap diekspor',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_items.length} transaksi',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Total(label: 'Pemasukan', value: income),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Total(label: 'Pengeluaran', value: expense),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error)),
            TextButton(onPressed: _load, child: const Text('Coba lagi')),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (_loading || _sharing || _items.isEmpty) ? null : _share,
            icon: _sharing
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.ios_share_rounded),
            label: const Text('Bagikan file CSV'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed:
            (_loading || _sharingPdf || _items.isEmpty) ? null : _sharePdf,
            icon: _sharingPdf
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
                : const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Bagikan laporan PDF'),
          ),
          if (!_loading && _items.isEmpty && _error == null) ...[
            const SizedBox(height: 10),
            Text(
              'Tidak ada transaksi pada periode ini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Pratinjau (5 terbaru)',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < preview.length; i++) ...[
                    TransactionTile(item: preview[i]),
                    if (i != preview.length - 1)
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
          const SizedBox(height: 20),
          Text(
            'CSV memakai pemisah titik koma dan bisa dibuka di Excel atau Google Sheets. PDF berisi ringkasan, rincian per kategori, dan daftar transaksi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  final String label;
  final double value;

  const _Total({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
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
    );
  }
}