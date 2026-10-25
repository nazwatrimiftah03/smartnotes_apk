import 'package:flutter/material.dart';

import 'parse.dart';

class Wallet {
  final String id;
  final String name;
  final String type; // cash | bank | ewallet | other
  final double initialBalance;
  final double balance;

  const Wallet({
    required this.id,
    required this.name,
    required this.type,
    required this.initialBalance,
    required this.balance,
  });

  factory Wallet.fromMap(Map<String, dynamic> m) => Wallet(
    id: m['id'] as String,
    name: m['name'] as String,
    type: m['type'] as String,
    initialBalance: asDouble(m['initial_balance']),
    balance: asDouble(m['balance']),
  );

  static const Map<String, String> typeLabels = {
    'cash': 'Tunai',
    'bank': 'Bank',
    'ewallet': 'E-Wallet',
    'other': 'Lainnya',
  };

  String get typeLabel => typeLabels[type] ?? 'Lainnya';

  IconData get icon {
    switch (type) {
      case 'bank':
        return Icons.account_balance;
      case 'ewallet':
        return Icons.phone_android;
      case 'cash':
        return Icons.payments;
      default:
        return Icons.wallet;
    }
  }
}