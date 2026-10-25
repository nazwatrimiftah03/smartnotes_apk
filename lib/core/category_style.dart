import 'package:flutter/material.dart';

class CategoryStyle {
  static const Map<String, IconData> icons = {
    'restaurant': Icons.restaurant,
    'directions_bus': Icons.directions_bus,
    'shopping_bag': Icons.shopping_bag,
    'receipt_long': Icons.receipt_long,
    'movie': Icons.movie,
    'favorite': Icons.favorite,
    'school': Icons.school,
    'more_horiz': Icons.more_horiz,
    'payments': Icons.payments,
    'card_giftcard': Icons.card_giftcard,
    'trending_up': Icons.trending_up,
    'add_circle': Icons.add_circle,
    'home': Icons.home,
    'local_gas_station': Icons.local_gas_station,
    'pets': Icons.pets,
    'fitness_center': Icons.fitness_center,
    'flight': Icons.flight,
    'phone_android': Icons.phone_android,
    'savings': Icons.savings,
    'category': Icons.category,
  };

  static const List<String> palette = [
    '#FF7043', '#42A5F5', '#AB47BC', '#EF5350', '#FFCA28', '#EC407A',
    '#26A69A', '#78909C', '#66BB6A', '#9CCC65', '#26C6DA', '#8D6E63',
  ];

  static IconData icon(String key) => icons[key] ?? Icons.category;

  static Color color(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.tryParse(h, radix: 16) ?? 0xFF4CAF50);
  }

  static String toHex(Color c) {
    final rgb = c.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}