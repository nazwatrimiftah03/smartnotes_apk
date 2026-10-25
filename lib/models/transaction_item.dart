import 'parse.dart';

class TransactionItem {
  final String id;
  final String walletId;
  final String? categoryId;
  final String type; // income | expense
  final double amount;
  final String? note;
  final DateTime date;
  final String walletName;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;

  const TransactionItem({
    required this.id,
    required this.walletId,
    required this.categoryId,
    required this.type,
    required this.amount,
    required this.note,
    required this.date,
    required this.walletName,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
  });

  factory TransactionItem.fromMap(Map<String, dynamic> m) {
    final cat = m['categories'] as Map<String, dynamic>?;
    final wal = m['wallets'] as Map<String, dynamic>?;

    return TransactionItem(
      id: m['id'] as String,
      walletId: m['wallet_id'] as String,
      categoryId: m['category_id'] as String?,
      type: m['type'] as String,
      amount: asDouble(m['amount']),
      note: m['note'] as String?,
      date: DateTime.parse(m['trx_date'] as String),
      walletName: (wal?['name'] as String?) ?? '-',
      categoryName: (cat?['name'] as String?) ?? 'Tanpa kategori',
      categoryIcon: (cat?['icon'] as String?) ?? 'category',
      categoryColor: (cat?['color'] as String?) ?? '#78909C',
    );
  }

  bool get isIncome => type == 'income';
}