import 'package:supabase_flutter/supabase_flutter.dart';

String errorMessage(Object e) {
  if (e is AuthException) return e.message;

  if (e is PostgrestException) {
    switch (e.code) {
      case '23505':
        return 'Data tersebut sudah ada.';
      case '23503':
        return 'Data ini masih terhubung dengan data lain.';
      case '42501':
        return 'Kamu tidak punya izin untuk aksi ini.';
    }
    return e.message;
  }

  final text = e.toString();
  if (text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('ClientException')) {
    return 'Tidak ada koneksi internet.';
  }
  return 'Terjadi kesalahan. Coba lagi.';
}