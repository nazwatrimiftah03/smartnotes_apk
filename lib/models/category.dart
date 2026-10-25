import 'package:flutter/material.dart';

import '../core/category_style.dart';

class Category {
  final String id;
  final String name;
  final String type; // income | expense
  final String icon;
  final String color;

  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
  });

  factory Category.fromMap(Map<String, dynamic> m) => Category(
    id: m['id'] as String,
    name: m['name'] as String,
    type: m['type'] as String,
    icon: m['icon'] as String,
    color: m['color'] as String,
  );

  bool get isIncome => type == 'income';
  IconData get iconData => CategoryStyle.icon(icon);
  Color get colorValue => CategoryStyle.color(color);
}