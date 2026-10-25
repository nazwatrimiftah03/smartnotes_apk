import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../widgets/soft_card.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String version = '1.0.0';

  static const List<(IconData, String, String)> _features = [
    (Icons.edit_note_rounded, 'Catat cepat', 'Pemasukan dan pengeluaran dalam hitungan detik.'),
    (Icons.account_balance_wallet_rounded, 'Banyak dompet', 'Tunai, bank, dan e-wallet dalam satu tempat.'),
    (Icons.pie_chart_rounded, 'Anggaran bulanan', 'Batas per kategori dengan peringatan otomatis.'),
    (Icons.bar_chart_rounded, 'Laporan jelas', 'Tren, kebiasaan harian, dan rincian kategori.'),
    (Icons.dark_mode_rounded, 'Mode gelap', 'Nyaman di mata, siang maupun malam.'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tentang aplikasi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Center(
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.savings_rounded,
                  color: Colors.white, size: 46),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Smartnotes',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Versi $version',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'Catatan keuangan pribadi yang simpel, rapi, dan menyenangkan dipakai.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 24),
          Text(
            'Fitur utama',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < _features.length; i++) ...[
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_features[i].$1,
                          size: 20, color: scheme.onPrimaryContainer),
                    ),
                    title: Text(
                      _features[i].$2,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(_features[i].$3),
                  ),
                  if (i != _features.length - 1)
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
          const SizedBox(height: 24),
          Text(
            'Dibuat dengan Flutter dan Supabase',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
