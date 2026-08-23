import 'package:flutter/material.dart';

import 'goal_tracker_page.dart';
import 'life_goals_page.dart';

enum GoalCenterSection { hierarchy, legacyGoals }

/// 人生目標の階層管理と、統合前の短中長期目標を1機能にまとめる入口。
class GoalCenterPage extends StatefulWidget {
  const GoalCenterPage({
    super.key,
    this.initialSection = GoalCenterSection.hierarchy,
  });

  final GoalCenterSection initialSection;

  @override
  State<GoalCenterPage> createState() => _GoalCenterPageState();
}

class _GoalCenterPageState extends State<GoalCenterPage> {
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
          LifeGoalsPage(),
          GoalTrackerPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            label: '人生目標',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            label: '従来の目標',
          ),
        ],
      ),
    );
  }
}
