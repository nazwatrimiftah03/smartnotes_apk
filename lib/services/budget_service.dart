import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/formatters.dart';
import '../core/month_utils.dart';
import '../models/budget.dart';
import 'transaction_service.dart';

class BudgetService {
  final SupabaseClient _client = Supabase.instance.client;
  final TransactionService _trx = TransactionService();

  Future<List<BudgetProgress>> getBudgets(DateTime month) async {
    final monthKey = Fmt.tanggalDb(MonthUtils.firstDay(month));

    final data = await _client
        .from('budgets')
        .select('*, categories(name,icon,color)')
        .eq('month', monthKey);

    final spent = await _trx.getExpenseByCategory(month);

    return data.map<BudgetProgress>((m) {
      final budget = Budget.fromMap(m);
      return BudgetProgress(
        budget: budget,
        spent: spent[budget.categoryId] ?? 0,
      );
    }).toList();
  }

  /// Buat anggaran baru, atau ubah batasnya kalau kategori+bulan sudah ada.
  Future<void> setBudget({
    required String categoryId,
    required DateTime month,
    required double amountLimit,
  }) async {
    await _client.from('budgets').upsert(
      {
        'user_id': _client.auth.currentUser!.id,
        'category_id': categoryId,
        'month': Fmt.tanggalDb(MonthUtils.firstDay(month)),
        'amount_limit': amountLimit,
      },
      onConflict: 'user_id,category_id,month',
    );
  }

  Future<void> deleteBudget(String id) async {
    await _client.from('budgets').delete().eq('id', id);
  }
}