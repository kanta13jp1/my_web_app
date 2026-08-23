import 'package:flutter/material.dart';

import 'daily_habits_page.dart';
import 'habit_gamification_page.dart';

enum HabitCenterSection { habits, rewards }

/// 日々の習慣実行と、統合前のXP・バッジ・ランキングを1機能にまとめる入口。
class HabitCenterPage extends StatefulWidget {
  const HabitCenterPage({
    super.key,
    this.initialSection = HabitCenterSection.habits,
  });

  final HabitCenterSection initialSection;

  @override
  State<HabitCenterPage> createState() => _HabitCenterPageState();
}

class _HabitCenterPageState extends State<HabitCenterPage> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialSection.index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const <Widget>[
          DailyHabitsPage(),
          HabitGamificationPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.repeat),
            label: '今日の習慣',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            label: 'XP・バッジ',
          ),
        ],
      ),
    );
  }
}
