import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/gamification_service.dart';
import '../models/achievement.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final gameService =
        Provider.of<GamificationService>(context, listen: false);
    await gameService.initializeUserStats();
    if (!mounted) return;
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final gameService = Provider.of<GamificationService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('統計 & 実績')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle('実績カテゴリ'),
                _buildCategoryCard(gameService.general),
                _buildCategoryCard(gameService.notes),
                // 他のカテゴリも同様に追加
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildCategoryCard(AchievementCategory category) {
    return Card(
      child: ListTile(
        title: Text(category.name),
        subtitle: Text('${category.achievements.length}個の実績'),
      ),
    );
  }
}
