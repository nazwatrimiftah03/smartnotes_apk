import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/formatters.dart';
import '../models/transaction_item.dart';

class ExportService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _select = '*, categories(name,icon,color), wallets(name)';
  static const int _pageSize = 1000;

  /// Ambil semua transaksi pada rentang tanggal (null = tanpa batas),
  /// halaman demi halaman supaya tidak terpotong batas 1000 baris.
  Future<List<TransactionItem>> fetch({DateTime? from, DateTime? to}) async {
    final all = <TransactionItem>[];
    var offset = 0;

    while (true) {
      var query = _client.from('transactions').select(_select);
      if (from != null) query = query.gte('trx_date', Fmt.tanggalDb(from));
      if (to != null) query = query.lte('trx_date', Fmt.tanggalDb(to));

      final page = await query
          .order('trx_date', ascending: true)
          .order('created_at', ascending: true)
          .range(offset, offset + _pageSize - 1);

      all.addAll(page.map<TransactionItem>((m) => TransactionItem.fromMap(m)));
      if (page.length < _pageSize) break;
      offset += _pageSize;
    }

    return all;
  }

  String _cell(String? v) {
    final s = (v ?? '').replaceAll('\r', ' ').replaceAll('\n', ' ');
    if (s.contains(';') || s.contains('"')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  String _amount(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(2).replaceAll('.', ',');
  }

  /// CSV dengan pemisah titik koma (cocok untuk Excel berbahasa Indonesia).
  String buildCsv(List<TransactionItem> items) {
    final b = StringBuffer('Tanggal;Jenis;Kategori;Dompet;Jumlah;Catatan\r\n');

    for (final t in items) {
      b.write([
        Fmt.tanggalDb(t.date),
        t.isIncome ? 'Pemasukan' : 'Pengeluaran',
        _cell(t.categoryName),
        _cell(t.walletName),
        _amount(t.amount),
        _cell(t.note),
      ].join(';'));
      b.write('\r\n');
    }
    return b.toString();
  }

  Future<void> sharePdf(Uint8List bytes, String fileName) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
        fileNameOverrides: [fileName],
        subject: 'Laporan keuangan Smartnotes',
      ),
    );
  }

  Future<void> shareCsv(String csv, String fileName) async {
    // BOM supaya Excel membaca huruf UTF-8 dengan benar.
    final bytes = Uint8List.fromList(utf8.encode('\uFEFF$csv'));

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'text/csv')],
        fileNameOverrides: [fileName],
        subject: 'Data keuangan Smartnotes',
      ),
    );
  }
}