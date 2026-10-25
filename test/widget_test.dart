import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/models/recurring_rule.dart';

void main() {
  group('RecurringRule.advance', () {
    test('bulanan: tanggal 31 menyesuaikan ke akhir Februari', () {
      expect(
        RecurringRule.advance(DateTime(2027, 1, 31), 'monthly', 31),
        DateTime(2027, 2, 28),
      );
    });

    test('bulanan: Februari tahun kabisat jatuh di tanggal 29', () {
      expect(
        RecurringRule.advance(DateTime(2028, 1, 31), 'monthly', 31),
        DateTime(2028, 2, 29),
      );
    });

    test('bulanan: kembali ke tanggal asli setelah bulan pendek', () {
      expect(
        RecurringRule.advance(DateTime(2027, 2, 28), 'monthly', 31),
        DateTime(2027, 3, 31),
      );
    });

    test('mingguan: maju 7 hari', () {
      expect(
        RecurringRule.advance(DateTime(2027, 1, 28), 'weekly', 28),
        DateTime(2027, 2, 4),
      );
    });

    test('harian: maju 1 hari melewati pergantian bulan', () {
      expect(
        RecurringRule.advance(DateTime(2027, 1, 31), 'daily', 31),
        DateTime(2027, 2, 1),
      );
    });

    test('tahunan: 29 Februari menjadi 28 Februari di tahun biasa', () {
      expect(
        RecurringRule.advance(DateTime(2028, 2, 29), 'yearly', 29),
        DateTime(2029, 2, 28),
      );
    });
  });
}
