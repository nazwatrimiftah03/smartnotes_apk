import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wallet.dart';

class WalletService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Wallet>> getWallets() async {
    final data = await _client.from('wallet_balances').select().order('name');
    return data.map<Wallet>((m) => Wallet.fromMap(m)).toList();
  }

  Future<void> addWallet({
    required String name,
    required String type,
    double initialBalance = 0,
  }) async {
    await _client.from('wallets').insert({
      'name': name,
      'type': type,
      'initial_balance': initialBalance,
    });
  }

  Future<void> updateWallet({
    required String id,
    required String name,
    required String type,
    required double initialBalance,
  }) async {
    await _client.from('wallets').update({
      'name': name,
      'type': type,
      'initial_balance': initialBalance,
    }).eq('id', id);
  }

  /// Menghapus dompet juga menghapus semua transaksi di dalamnya.
  Future<void> deleteWallet(String id) async {
    await _client.from('wallets').delete().eq('id', id);
  }
}