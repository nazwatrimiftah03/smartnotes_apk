import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileStats {
  final int transactions;
  final int wallets;
  final int categories;
  final DateTime? firstTransaction;

  const ProfileStats({
    required this.transactions,
    required this.wallets,
    required this.categories,
    required this.firstTransaction,
  });
}

class ProfileService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> updateProfile({
    required String name,
    required int avatarStyle,
    String? bio,
  }) async {
    await _client.auth.updateUser(
      UserAttributes(
        data: {
          'full_name': name.trim(),
          'avatar_style': avatarStyle,
          'bio': (bio ?? '').trim(),
        },
      ),
    );
  }

  /// Verifikasi password lama dulu, baru ganti ke yang baru.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) throw StateError('Tidak ada pengguna yang masuk.');

    await _client.auth.signInWithPassword(email: email, password: oldPassword);
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<ProfileStats> getStats() async {
    final results = await Future.wait<dynamic>([
      _client.from('transactions').count(CountOption.exact),
      _client.from('wallets').count(CountOption.exact),
      _client.from('categories').count(CountOption.exact),
      _client
          .from('transactions')
          .select('trx_date')
          .order('trx_date', ascending: true)
          .limit(1),
    ]);

    final first = results[3] as List;
    return ProfileStats(
      transactions: results[0] as int,
      wallets: results[1] as int,
      categories: results[2] as int,
      firstTransaction: first.isEmpty
          ? null
          : DateTime.tryParse(first.first['trx_date'].toString()),
    );
  }
}