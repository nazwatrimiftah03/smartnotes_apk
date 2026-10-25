import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/formatters.dart';
import '../core/month_utils.dart';
import '../models/parse.dart';
import '../models/transaction_item.dart';

class MonthSummary {
  final double income;
  final double expense;

  const MonthSummary({required this.income, required this.expense});

  double get net => income - expense;
}

class TransactionService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _select =
      '*, categories(name,icon,color), wallets(name)';

  Future<List<TransactionItem>> getTransactions({
    DateTime? from,
    DateTime? to,
    String? type,
    String? walletId,
    String? categoryId,
    String? search,
    int limit = 100,
  }) async {
    var query = _client.from('transactions').select(_select);

    if (from != null) query = query.gte('trx_date', Fmt.tanggalDb(from));
    if (to != null) query = query.lte('trx_date', Fmt.tanggalDb(to));
    if (type != null) query = query.eq('type', type);
    if (walletId != null) query = query.eq('wallet_id', walletId);
    if (categoryId != null) query = query.eq('category_id', categoryId);
    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('note', '%${search.trim()}%');
    }

    final data = await query
        .order('trx_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    return data
        .map<TransactionItem>((m) => TransactionItem.fromMap(m))
        .toList();
  }

  Future<void> addTransaction({
    required String walletId,
    required String? categoryId,
    required String type,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    await _client.from('transactions').insert({
      'wallet_id': walletId,
      'category_id': categoryId,
      'type': type,
      'amount': amount,
      'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
      'trx_date': Fmt.tanggalDb(date),
    });
  }

  Future<void> updateTransaction({
    required String id,
    required String walletId,
    required String? categoryId,
    required String type,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    await _client.from('transactions').update({
      'wallet_id': walletId,
      'category_id': categoryId,
      'type': type,
      'amount': amount,
      'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
      'trx_date': Fmt.tanggalDb(date),
    }).eq('id', id);
  }

  Future<void> deleteTransaction(String id) async {
    await _client.from('transactions').delete().eq('id', id);
  }

  /// Total pemasukan dan pengeluaran pada satu bulan.
  Future<MonthSummary> getMonthSummary(DateTime month) async {
    final data = await _client
        .from('transactions')
        .select('type, amount')
        .gte('trx_date', Fmt.tanggalDb(MonthUtils.firstDay(month)))
        .lte('trx_date', Fmt.tanggalDb(MonthUtils.lastDay(month)));

    double income = 0;
    double expense = 0;
    for (final row in data) {
      final amount = asDouble(row['amount']);
      if (row['type'] == 'income') {
        income += amount;
      } else {
        expense += amount;
      }
    }
    return MonthSummary(income: income, expense: expense);
  }

  /// Total pengeluaran per kategori pada satu bulan: {categoryId: total}.
  Future<Map<String, double>> getExpenseByCategory(DateTime month) async {
    final data = await _client
        .from('transactions')
        .select('category_id, amount')
        .eq('type', 'expense')
        .gte('trx_date', Fmt.tanggalDb(MonthUtils.firstDay(month)))
        .lte('trx_date', Fmt.tanggalDb(MonthUtils.lastDay(month)));

    final result = <String, double>{};
    for (final row in data) {
      final id = row['category_id'] as String?;
      if (id == null) continue;
      result[id] = (result[id] ?? 0) + asDouble(row['amount']);
    }
    return result;
  }
}