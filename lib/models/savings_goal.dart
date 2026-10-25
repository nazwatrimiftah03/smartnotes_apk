import 'parse.dart';

class SavingsGoal {
  final String id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final DateTime? deadline;
  final String icon;
  final String color;

  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.deadline,
    required this.icon,
    required this.color,
  });

  factory SavingsGoal.fromMap(Map<String, dynamic> m) => SavingsGoal(
    id: m['id'] as String,
    name: m['name'] as String,
    targetAmount: asDouble(m['target_amount']),
    savedAmount: asDouble(m['saved_amount']),
    deadline: m['deadline'] == null
        ? null
        : DateTime.tryParse(m['deadline'].toString()),
    icon: (m['icon'] as String?) ?? 'savings',
    color: (m['color'] as String?) ?? '#EC6F9B',
  );

  double get remaining =>
      (targetAmount - savedAmount) < 0 ? 0 : targetAmount - savedAmount;

  bool get isDone => savedAmount >= targetAmount;

  /// 0.0 sampai 1.0.
  double get ratio =>
      targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0.0, 1.0);

  /// Sisa hari sampai tenggat (negatif kalau sudah lewat). Null tanpa tenggat.
  int? get daysLeft {
    if (deadline == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return deadline!.difference(today).inDays;
  }

  /// Perkiraan setoran per bulan agar tepat waktu.
  double? get perMonthNeeded {
    final d = daysLeft;
    if (d == null || d <= 0 || isDone) return null;
    final months = (d / 30).ceil().clamp(1, 1200);
    return remaining / months;
  }
}