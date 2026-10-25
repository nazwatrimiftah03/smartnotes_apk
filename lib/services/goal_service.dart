import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/formatters.dart';
import '../models/savings_goal.dart';

class GoalService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<SavingsGoal>> getGoals() async {
    final data = await _client
        .from('savings_goals')
        .select()
        .order('created_at', ascending: false);

    return data.map<SavingsGoal>((m) => SavingsGoal.fromMap(m)).toList();
  }

  Future<void> addGoal({
    required String name,
    required double targetAmount,
    required double savedAmount,
    required DateTime? deadline,
    required String icon,
    required String color,
  }) async {
    await _client.from('savings_goals').insert({
      'user_id': _client.auth.currentUser!.id,
      'name': name,
      'target_amount': targetAmount,
      'saved_amount': savedAmount,
      'deadline': deadline == null ? null : Fmt.tanggalDb(deadline),
      'icon': icon,
      'color': color,
    });
  }

  Future<void> updateGoal({
    required String id,
    required String name,
    required double targetAmount,
    required DateTime? deadline,
    required String icon,
    required String color,
  }) async {
    await _client.from('savings_goals').update({
      'name': name,
      'target_amount': targetAmount,
      'deadline': deadline == null ? null : Fmt.tanggalDb(deadline),
      'icon': icon,
      'color': color,
    }).eq('id', id);
  }

  Future<void> setSaved(String id, double savedAmount) async {
    await _client
        .from('savings_goals')
        .update({'saved_amount': savedAmount < 0 ? 0 : savedAmount}).eq(
        'id', id);
  }

  Future<void> deleteGoal(String id) async {
    await _client.from('savings_goals').delete().eq('id', id);
  }
}