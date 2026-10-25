import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Ubah error teknis menjadi pesan yang mudah dipahami.
  static String friendlyError(Object error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials')) {
        return 'Email atau password salah.';
      }
      if (msg.contains('already registered') ||
          msg.contains('already been registered')) {
        return 'Email ini sudah terdaftar. Silakan masuk.';
      }
      if (msg.contains('email not confirmed')) {
        return 'Email belum dikonfirmasi. Cek kotak masuk email kamu.';
      }
      if (msg.contains('rate limit')) {
        return 'Terlalu banyak percobaan. Coba lagi beberapa saat lagi.';
      }
      if (msg.contains('password')) {
        return 'Password tidak memenuhi syarat (minimal 6 karakter).';
      }
      return error.message;
    }

    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('ClientException')) {
      return 'Tidak ada koneksi internet.';
    }
    return 'Terjadi kesalahan. Coba lagi.';
  }
}