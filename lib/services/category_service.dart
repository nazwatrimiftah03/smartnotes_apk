import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';

class CategoryService {
  final SupabaseClient _client = Supabase.instance.client;

  /// [type]: 'income', 'expense', atau null untuk semua.
  Future<List<Category>> getCategories({String? type}) async {
    var query = _client.from('categories').select();
    if (type != null) query = query.eq('type', type);

    final data = await query.order('name');
    return data.map<Category>((m) => Category.fromMap(m)).toList();
  }

  Future<void> addCategory({
    required String name,
    required String type,
    required String icon,
    required String color,
  }) async {
    await _client.from('categories').insert({
      'name': name,
      'type': type,
      'icon': icon,
      'color': color,
    });
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    required String icon,
    required String color,
  }) async {
    await _client.from('categories').update({
      'name': name,
      'icon': icon,
      'color': color,
    }).eq('id', id);
  }

  /// Transaksi lama tetap ada, kategorinya jadi "Tanpa kategori".
  Future<void> deleteCategory(String id) async {
    await _client.from('categories').delete().eq('id', id);
  }
}