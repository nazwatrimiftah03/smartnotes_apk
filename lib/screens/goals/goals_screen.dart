import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/app_events.dart';
import '../../core/app_theme.dart';
import '../../core/category_style.dart';
import '../../core/formatters.dart';
import '../../models/savings_goal.dart';
import '../../services/goal_service.dart';
import '../../widgets/soft_card.dart';
import 'goal_deposit_sheet.dart';
import 'goal_form_sheet.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _service = GoalService();

  List<SavingsGoal> _goals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    AppEvents.dataVersion.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    AppEvents.dataVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _service.getGoals();

      // Yang belum tercapai di atas (tenggat terdekat dulu), yang selesai di bawah.
      data.sort((a, b) {
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        final da = a.deadline, db = b.deadline;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

      if (!mounted) return;
      setState(() {
        _goals = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Target tabungan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showGoalForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Target baru'),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null && _goals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    if (_goals.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 110),
        children: [
          Icon(Icons.flag_rounded, size: 60, color: scheme.primary),
          const SizedBox(height: 14),
          Text(
            'Belum ada target tabungan',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Buat target seperti liburan, gadget baru, atau dana darurat, lalu isi sedikit demi sedikit.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }

    final totalSaved = _goals.fold<double>(0, (s, g) => s + g.savedAmount);
    final totalTarget = _goals.fold<double>(0, (s, g) => s + g.targetAmount);
    final doneCount = _goals.where((g) => g.isDone).length;
    final totalRatio =
    totalTarget <= 0 ? 0.0 : (totalSaved / totalTarget).clamp(0.0, 1.0);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
        children: [
          SoftCard(
            gradient: AppColors.heroGradient,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total tabungan',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Fmt.rupiah(totalSaved),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'dari target ${Fmt.rupiah(totalTarget)}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: totalRatio,
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.28),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$doneCount dari ${_goals.length} target tercapai',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          for (final g in _goals) ...[
            _GoalCard(goal: g),
            const SizedBox(height: 12),
          ],
          Text(
            'Tap kartu untuk mengubah atau menghapus target.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;

  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = CategoryStyle.color(goal.color);
    final days = goal.daysLeft;

    String status;
    Color statusColor = scheme.onSurfaceVariant;

    if (goal.isDone) {
      status = 'Target tercapai';
      statusColor = AppColors.income;
    } else if (days == null) {
      status = 'Kurang ${Fmt.rupiah(goal.remaining)}';
    } else if (days < 0) {
      status = 'Tenggat lewat ${-days} hari, kurang ${Fmt.rupiah(goal.remaining)}';
      statusColor = AppColors.expense;
    } else if (days == 0) {
      status = 'Tenggat hari ini, kurang ${Fmt.rupiah(goal.remaining)}';
      statusColor = AppColors.expense;
    } else {
      final perMonth = goal.perMonthNeeded;
      status = '$days hari lagi'
          '${perMonth == null ? '' : ' • sisihkan ${Fmt.rupiah(perMonth)}/bulan'}';
    }

    return SoftCard(
      padding: const EdgeInsets.all(16),
      onTap: () => showGoalForm(context, goal: goal),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: goal.ratio),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 6,
                          strokeCap: StrokeCap.round,
                          backgroundColor: color.withValues(alpha: 0.16),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ),
                    Icon(
                      goal.isDone
                          ? Icons.check_rounded
                          : CategoryStyle.icon(goal.icon),
                      color: color,
                      size: 24,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Fmt.rupiah(goal.savedAmount)} / ${Fmt.rupiah(goal.targetAmount)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(goal.ratio * 100).round()}%',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => showGoalDeposit(context, goal),
              icon: const Icon(Icons.savings_rounded, size: 18),
              label: Text(goal.isDone ? 'Kelola tabungan' : 'Setor tabungan'),
            ),
          ),
        ],
      ),
    );
  }
}