import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shows the user's highest-priority action due today, without changing it.
class HomeTodayPriorityGoal extends StatefulWidget {
  const HomeTodayPriorityGoal({super.key});

  @override
  State<HomeTodayPriorityGoal> createState() => _HomeTodayPriorityGoalState();
}

class _HomeTodayPriorityGoalState extends State<HomeTodayPriorityGoal> {
  late final Future<List<Map<String, dynamic>>> _goals = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await client
        .from('life_goals')
        .select('id,title,target_date,priority')
        .eq('user_id', userId)
        .eq('level', 'small')
        .eq('status', 'active')
        .eq('priority', 5)
        .eq('target_date', DateFormat('yyyy-MM-dd').format(DateTime.now()))
        .order('sort_order');
    return List<Map<String, dynamic>>.from(data);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _goals,
      builder: (context, snapshot) {
        final goals = snapshot.data;
        if (goals == null || goals.isEmpty) return const SizedBox.shrink();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '本日の最優先目標',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final goal in goals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      goal['title'].toString(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamed('/life-goals?tab=small'),
                  child: const Text('目標を確認する'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
