import 'package:intl/intl.dart';

class Fmt {
  static final NumberFormat _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// 1500000 -> "Rp 1.500.000"
  static String rupiah(num value) => _rupiah.format(value);

  /// 2026-10-23 -> "23 Okt 2026"
  static String tanggal(DateTime date) =>
      DateFormat('d MMM yyyy', 'id_ID').format(date);

  /// 2026-10-23 -> "Oktober 2026"
  static String bulanTahun(DateTime date) =>
      DateFormat('MMMM yyyy', 'id_ID').format(date);

  /// Untuk dikirim ke database: "2026-10-23"
  static String tanggalDb(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(date);
}