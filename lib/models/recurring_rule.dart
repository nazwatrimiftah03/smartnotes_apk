import 'parse.dart';

class RecurringRule {
  final String id;
  final String name;
  final String type; // income | expense
  final double amount;
  final String walletId;
  final String walletName;
  final String? categoryId;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final String frequency; // daily | weekly | monthly | yearly
  final int anchorDay;
  final DateTime nextDate;
  final bool active;

  const RecurringRule({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.walletId,
    required this.walletName,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.frequency,
    required this.anchorDay,
    required this.nextDate,
    required this.active,
  });

  factory RecurringRule.fromMap(Map<String, dynamic> m) {
    final cat = m['categories'] as Map<String, dynamic>?;
    final wal = m['wallets'] as Map<String, dynamic>?;

    return RecurringRule(
      id: m['id'] as String,
      name: m['name'] as String,
      type: m['type'] as String,
      amount: asDouble(m['amount']),
      walletId: m['wallet_id'] as String,
      walletName: (wal?['name'] as String?) ?? '-',
      categoryId: m['category_id'] as String?,
      categoryName: (cat?['name'] as String?) ?? 'Tanpa kategori',
      categoryIcon: (cat?['icon'] as String?) ?? 'category',
      categoryColor: (cat?['color'] as String?) ?? '#90A4AE',
      frequency: m['frequency'] as String,
      anchorDay: (m['anchor_day'] as num?)?.toInt() ?? 1,
      nextDate: DateTime.parse(m['next_date'].toString()),
      active: (m['active'] as bool?) ?? true,
    );
  }

  bool get isIncome => type == 'income';

  static const Map<String, String> frequencyLabels = {
    'daily': 'Harian',
    'weekly': 'Mingguan',
    'monthly': 'Bulanan',
    'yearly': 'Tahunan',
  };

  /// Tanggal kejadian berikutnya setelah [d].
  static DateTime advance(DateTime d, String frequency, int anchorDay) {
    switch (frequency) {
      case 'daily':
        return DateTime(d.year, d.month, d.day + 1);
      case 'weekly':
        return DateTime(d.year, d.month, d.day + 7);
      case 'yearly':
        {
          final y = d.year + 1;
          final last = DateTime(y, d.month + 1, 0).day;
          return DateTime(y, d.month, anchorDay > last ? last : anchorDay);
        }
      default:
        {
          final first = DateTime(d.year, d.month + 1, 1);
          final last = DateTime(first.year, first.month + 1, 0).day;
          return DateTime(
            first.year,
            first.month,
            anchorDay > last ? last : anchorDay,
          );
        }
    }
  }

  /// Perkiraan nominal per bulan, untuk ringkasan.
  double get monthlyEquivalent {
    switch (frequency) {
      case 'daily':
        return amount * 30;
      case 'weekly':
        return amount * 52 / 12;
      case 'yearly':
        return amount / 12;
      default:
        return amount;
    }
  }
}