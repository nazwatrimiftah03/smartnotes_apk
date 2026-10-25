import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/formatters.dart';
import '../models/recurring_rule.dart';

class RecurringService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _select = '*, categories(name,icon,color), wallets(name)';

  Future<List<RecurringRule>> getRules() async {
    final data = await _client
        .from('recurring_rules')
        .select(_select)
        .order('next_date', ascending: true);

    return data.map<RecurringRule>((m) => RecurringRule.fromMap(m)).toList();
  }

  Future<void> addRule({
    required String name,
    required String type,
    required double amount,
    required String walletId,
    required String? categoryId,
    required String frequency,
    required DateTime startDate,
  }) async {
    await _client.from('recurring_rules').insert({
      'name': name,
      'type': type,
      'amount': amount,
      'wallet_id': walletId,
      'category_id': categoryId,
      'frequency': frequency,
      'anchor_day': startDate.day,
      'next_date': Fmt.tanggalDb(startDate),
      'active': true,
    });
  }

  Future<void> updateRule({
    required String id,
    required String name,
    required String type,
    required double amount,
    required String walletId,
    required String? categoryId,
    required String frequency,
    required DateTime nextDate,
  }) async {
    await _client.from('recurring_rules').update({
      'name': name,
      'type': type,
      'amount': amount,
      'wallet_id': walletId,
      'category_id': categoryId,
      'frequency': frequency,
      'anchor_day': nextDate.day,
      'next_date': Fmt.tanggalDb(nextDate),
    }).eq('id', id);
  }

  /// Saat diaktifkan lagi, lompati tanggal yang sudah lewat supaya
  /// tidak mencatat tagihan masa lalu sekaligus.
  Future<void> setActive(RecurringRule rule, bool active) async {
    final patch = <String, dynamic>{'active': active};

    if (active) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      var d = rule.nextDate;
      var guard = 0;
      while (d.isBefore(today) && guard < 5000) {
        d = RecurringRule.advance(d, rule.frequency, rule.anchorDay);
        guard++;
      }
      patch['next_date'] = Fmt.tanggalDb(d);
    }

    await _client.from('recurring_rules').update(patch).eq('id', rule.id);
  }

  Future<void> deleteRule(String id) async {
    await _client.from('recurring_rules').delete().eq('id', id);
  }

  /// Catat semua transaksi berulang yang sudah jatuh tempo.
  /// Mengembalikan jumlah transaksi yang dibuat.
  Future<int> processDue() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final rows = await _client
        .from('recurring_rules')
        .select()
        .eq('active', true)
        .lte('next_date', Fmt.tanggalDb(today));

    var created = 0;

    for (final m in rows) {
      final id = m['id'] as String;
      final oldNext = DateTime.parse(m['next_date'].toString());
      final freq = m['frequency'] as String;
      final anchor = (m['anchor_day'] as num?)?.toInt() ?? oldNext.day;

      // Kumpulkan semua tanggal jatuh tempo (maks 60 supaya aman).
      final dates = <DateTime>[];
      var d = oldNext;
      while (!d.isAfter(today) && dates.length < 60) {
        dates.add(d);
        d = RecurringRule.advance(d, freq, anchor);
      }
      if (dates.isEmpty) continue;

      // "Klaim" aturan dulu. Kalau sudah diproses perangkat lain, lewati.
      final claimed = await _client
          .from('recurring_rules')
          .update({'next_date': Fmt.tanggalDb(d)})
          .eq('id', id)
          .eq('next_date', Fmt.tanggalDb(oldNext))
          .select('id');
      if (claimed.isEmpty) continue;

      try {
        await _client.from('transactions').insert([
          for (final date in dates)
            {
              'wallet_id': m['wallet_id'],
              'category_id': m['category_id'],
              'type': m['type'],
              'amount': m['amount'],
              'note': m['name'],
              'trx_date': Fmt.tanggalDb(date),
            },
        ]);
        created += dates.length;
      } catch (_) {
        // Gagal mencatat: kembalikan tanggal supaya dicoba lagi nanti.
        await _client
            .from('recurring_rules')
            .update({'next_date': Fmt.tanggalDb(oldNext)}).eq('id', id);
      }
    }

    return created;
  }
}