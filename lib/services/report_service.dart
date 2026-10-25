import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/formatters.dart';
import '../core/month_utils.dart';
import '../models/parse.dart';

class MonthTotal {
  final DateTime month;
  final double income;
  final double expense;

  const MonthTotal({
    required this.month,
    required this.income,
    required this.expense,
  });

  double get net => income - expense;
}

class ReportService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Total pemasukan dan pengeluaran per bulan, [months] bulan terakhir
  /// sampai [endMonth] (urut dari yang paling lama).
  Future<List<MonthTotal>> getTrend(DateTime endMonth, {int months = 6}) async {
    final start = DateTime(endMonth.year, endMonth.month - (months - 1), 1);
    final end = MonthUtils.lastDay(endMonth);

    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await _client
          .from('transactions')
          .select('type, amount, trx_date')
          .gte('trx_date', Fmt.tanggalDb(start))
          .lte('trx_date', Fmt.tanggalDb(end))
          .order('trx_date')
          .order('id')
          .range(offset, offset + 999);
      rows.addAll(List<Map<String, dynamic>>.from(page));
      if (page.length < 1000) break;
      offset += 1000;
    }

    final income = <String, double>{};
    final expense = <String, double>{};
    for (final r in rows) {
      final key = (r['trx_date'] as String).substring(0, 7); // yyyy-MM
      final amount = asDouble(r['amount']);
      if (r['type'] == 'income') {
        income[key] = (income[key] ?? 0) + amount;
      } else {
        expense[key] = (expense[key] ?? 0) + amount;
      }
    }

    return List.generate(months, (i) {
      final m = DateTime(start.year, start.month + i, 1);
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      return MonthTotal(
        month: m,
        income: income[key] ?? 0,
        expense: expense[key] ?? 0,
      );
    });
  }
}