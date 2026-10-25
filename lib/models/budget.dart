import 'parse.dart';

class Budget {
  final String id;
  final String categoryId;
  final DateTime month;
  final double amountLimit;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;

  const Budget({
    required this.id,
    required this.categoryId,
    required this.month,
    required this.amountLimit,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
  });

  factory Budget.fromMap(Map<String, dynamic> m) {
    final cat = m['categories'] as Map<String, dynamic>?;
    return Budget(
      id: m['id'] as String,
      categoryId: m['category_id'] as String,
      month: DateTime.parse(m['month'] as String),
      amountLimit: asDouble(m['amount_limit']),
      categoryName: (cat?['name'] as String?) ?? '-',
      categoryIcon: (cat?['icon'] as String?) ?? 'category',
      categoryColor: (cat?['color'] as String?) ?? '#78909C',
    );
  }
}

/// Anggaran + berapa yang sudah terpakai bulan itu.
class BudgetProgress {
  final Budget budget;
  final double spent;

  const BudgetProgress({required this.budget, required this.spent});

  double get remaining => budget.amountLimit - spent;
  bool get isOver => spent > budget.amountLimit;

  /// 0.0 sampai 1.0 (untuk progress bar).
  double get ratio => budget.amountLimit <= 0
      ? 0
      : (spent / budget.amountLimit).clamp(0.0, 1.0);
}