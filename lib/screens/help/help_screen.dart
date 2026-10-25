import 'package:flutter/material.dart';

import '../../widgets/soft_card.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const List<(String, String, IconData)> _faq = [
    (
    'Bagaimana cara mencatat transaksi?',
    'Tap tombol Catat di Beranda, pilih Pengeluaran atau Pemasukan, isi nominal, kategori, dompet, dan tanggal, lalu simpan.',
    Icons.edit_note_rounded,
    ),
    (
    'Bagaimana saldo dompet dihitung?',
    'Saldo = saldo awal + semua pemasukan - semua pengeluaran di dompet itu. Kamu bisa mengubah saldo awal lewat Akun > Dompet.',
    Icons.account_balance_wallet_rounded,
    ),
    (
    'Apa yang terjadi kalau kategori dihapus?',
    'Transaksi lama tetap ada, hanya kategorinya menjadi "Tanpa kategori". Anggaran untuk kategori itu ikut terhapus.',
    Icons.category_rounded,
    ),
    (
    'Bagaimana cara kerja anggaran?',
    'Tentukan batas per kategori tiap bulan. Bar berubah oranye di 80% dan merah kalau melebihi batas. Gunakan "Salin dari bulan lalu" supaya tidak mengisi ulang.',
    Icons.pie_chart_rounded,
    ),
    (
    'Bagaimana membaca Laporan?',
    'Laporan menampilkan selisih bulan ini, tren 6 bulan, pengeluaran harian, dan rincian per kategori. Tap nama bulan di grafik untuk berpindah bulan.',
    Icons.bar_chart_rounded,
    ),
    (
    'Apakah dompet bisa dihapus?',
    'Bisa, tapi minimal harus ada satu dompet. Menghapus dompet juga menghapus semua transaksi di dalamnya secara permanen.',
    Icons.delete_outline_rounded,
    ),
    (
    'Apakah datanya aman?',
    'Datamu tersimpan di akunmu sendiri dan hanya bisa diakses setelah masuk. Jangan bagikan password ke siapa pun.',
    Icons.verified_user_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Panduan & FAQ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'Pertanyaan yang sering muncul. Tap untuk membuka jawabannya.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          for (final item in _faq) ...[
            SoftCard(
              padding: EdgeInsets.zero,
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  childrenPadding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.$3,
                        size: 20, color: scheme.onPrimaryContainer),
                  ),
                  title: Text(
                    item.$1,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  children: [
                    Text(
                      item.$2,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}