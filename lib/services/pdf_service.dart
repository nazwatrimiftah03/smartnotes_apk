import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/formatters.dart';
import '../models/transaction_item.dart';

/// Membuat laporan keuangan PDF dari daftar transaksi.
class PdfService {
  static const PdfColor _brand = PdfColor.fromInt(0xFFEC6F9B);
  static const PdfColor _income = PdfColor.fromInt(0xFF2FB5A0);
  static const PdfColor _expense = PdfColor.fromInt(0xFFE5534B);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B6B76);
  static const PdfColor _line = PdfColor.fromInt(0xFFE3E3E8);
  static const PdfColor _headBg = PdfColor.fromInt(0xFFF4F1F3);

  /// Font bawaan PDF hanya mendukung karakter Latin, jadi bersihkan sisanya.
  static String _clean(String? v) {
    if (v == null) return '';
    final buf = StringBuffer();
    for (final r in v.runes) {
      if (r == 0xA0 || r == 0x202F) {
        buf.write(' ');
      } else if (r >= 32 && r <= 255) {
        buf.writeCharCode(r);
      }
    }
    return buf.toString().trim();
  }

  static String _rp(double v) => _clean(Fmt.rupiah(v));

  static pw.Widget _cell(
      String text, {
        bool bold = false,
        pw.TextAlign align = pw.TextAlign.left,
        PdfColor? color,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  static pw.Widget _title(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
    ),
  );

  static pw.Widget _summaryBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _line, width: 0.8),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _muted)),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _categoryTable(Map<String, double> totals) {
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sum = entries.fold<double>(0, (s, e) => s + e.value);

    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: 0.5),
        bottom: pw.BorderSide(color: _line, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
        2: pw.FixedColumnWidth(45),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headBg),
          children: [
            _cell('Kategori', bold: true),
            _cell('Jumlah', bold: true, align: pw.TextAlign.right),
            _cell('%', bold: true, align: pw.TextAlign.right),
          ],
        ),
        for (final e in entries)
          pw.TableRow(
            children: [
              _cell(e.key),
              _cell(_rp(e.value), align: pw.TextAlign.right),
              _cell(
                sum <= 0 ? '0%' : '${(e.value / sum * 100).round()}%',
                align: pw.TextAlign.right,
              ),
            ],
          ),
      ],
    );
  }

  static Future<Uint8List> build({
    required String period,
    required List<TransactionItem> items,
  }) async {
    var income = 0.0;
    var expense = 0.0;
    final incomeCats = <String, double>{};
    final expenseCats = <String, double>{};

    for (final t in items) {
      final name = _clean(t.categoryName);
      if (t.isIncome) {
        income += t.amount;
        incomeCats[name] = (incomeCats[name] ?? 0) + t.amount;
      } else {
        expense += t.amount;
        expenseCats[name] = (expenseCats[name] ?? 0) + t.amount;
      }
    }
    final net = income - expense;

    final doc = pw.Document(
      title: 'Laporan Keuangan Smartnotes',
      author: 'Smartnotes',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Dibuat dengan Smartnotes',
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
              pw.Text(
                'Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
            ],
          ),
        ),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: _brand,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Laporan Keuangan',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  _clean(period),
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.white),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              _summaryBox('Pemasukan', _rp(income), _income),
              pw.SizedBox(width: 10),
              _summaryBox('Pengeluaran', _rp(expense), _expense),
              pw.SizedBox(width: 10),
              _summaryBox(
                'Selisih',
                '${net < 0 ? '- ' : ''}${_rp(net.abs())}',
                net < 0 ? _expense : _income,
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '${items.length} transaksi',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
          if (expenseCats.isNotEmpty) ...[
            _title('Pengeluaran per kategori'),
            _categoryTable(expenseCats),
          ],
          if (incomeCats.isNotEmpty) ...[
            _title('Pemasukan per kategori'),
            _categoryTable(incomeCats),
          ],
          _title('Daftar transaksi'),
          if (items.isEmpty)
            pw.Text(
              'Tidak ada transaksi pada periode ini.',
              style: const pw.TextStyle(fontSize: 10, color: _muted),
            )
          else
            pw.Table(
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: _line, width: 0.5),
                bottom: pw.BorderSide(color: _line, width: 0.5),
              ),
              columnWidths: const {
                0: pw.FixedColumnWidth(58),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(3),
                4: pw.FlexColumnWidth(2.4),
              },
              children: [
                pw.TableRow(
                  repeat: true,
                  decoration: const pw.BoxDecoration(color: _headBg),
                  children: [
                    _cell('Tanggal', bold: true),
                    _cell('Kategori', bold: true),
                    _cell('Dompet', bold: true),
                    _cell('Catatan', bold: true),
                    _cell('Jumlah', bold: true, align: pw.TextAlign.right),
                  ],
                ),
                for (final t in items)
                  pw.TableRow(
                    children: [
                      _cell(_clean(Fmt.tanggalDb(t.date))),
                      _cell(_clean(t.categoryName)),
                      _cell(_clean(t.walletName)),
                      _cell(_clean(t.note)),
                      _cell(
                        '${t.isIncome ? '+' : '-'} ${_rp(t.amount)}',
                        align: pw.TextAlign.right,
                        color: t.isIncome ? _income : _expense,
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );

    return doc.save();
  }
}