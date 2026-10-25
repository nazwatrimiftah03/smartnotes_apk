class MonthUtils {
  /// Tanggal 1 pada bulan dari [d].
  static DateTime firstDay(DateTime d) => DateTime(d.year, d.month, 1);

  /// Tanggal terakhir pada bulan dari [d].
  static DateTime lastDay(DateTime d) => DateTime(d.year, d.month + 1, 0);

  static DateTime nextMonth(DateTime d) => DateTime(d.year, d.month + 1, 1);

  static DateTime prevMonth(DateTime d) => DateTime(d.year, d.month - 1, 1);
}