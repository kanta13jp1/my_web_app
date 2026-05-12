import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/meal_nutrition_service.dart';

class MealNutritionTracker extends StatefulWidget {
  const MealNutritionTracker({super.key});

  @override
  State<MealNutritionTracker> createState() => _MealNutritionTrackerState();
}

class _MealNutritionTrackerState extends State<MealNutritionTracker> {
  static const _storageKey = 'meal_nutrition_logs_v1';

  final _service = MealNutritionService();
  final _mealController = TextEditingController();
  final List<MealNutritionLog> _logs = <MealNutritionLog>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _mealController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _logs
        ..clear()
        ..addAll(_service.decodeLogs(prefs.getString(_storageKey)));
      _isLoading = false;
    });
  }

  Future<void> _saveLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, _service.encodeLogs(_logs));
  }

  Future<void> _addMeal([String? quickText]) async {
    final text = (quickText ?? _mealController.text).trim();
    if (text.isEmpty) {
      return;
    }
    final estimate = _service.estimate(text);
    setState(() {
      _logs.insert(
        0,
        MealNutritionLog(loggedAt: DateTime.now(), estimate: estimate),
      );
      if (_logs.length > 60) {
        _logs.removeRange(60, _logs.length);
      }
      _mealController.clear();
    });
    await _saveLogs();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${estimate.label}: ${estimate.facts.calories} kcalで記録しました',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final summary = _service.summarize(_logs);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _buildInputPanel(context),
        const SizedBox(height: 12),
        _buildSummaryPanel(context, summary),
        const SizedBox(height: 12),
        _buildWarningPanel(context, summary),
        const SizedBox(height: 12),
        _buildWeeklyChart(context, summary),
        const SizedBox(height: 12),
        _buildLogList(context, summary.logs),
      ],
    );
  }

  Widget _buildInputPanel(BuildContext context) {
    const quickMeals = <String>['吉野家 うな重', 'すき家 うな牛', 'ラーメン', '野菜サラダ'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '食事内容を記録',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('meal_nutrition_input'),
                    controller: _mealController,
                    decoration: const InputDecoration(
                      hintText: '例: 吉野家 うな重、すき家 うな牛、野菜サラダ',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addMeal(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('meal_nutrition_add_button'),
                  onPressed: _addMeal,
                  icon: const Icon(Icons.add),
                  label: const Text('記録'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: quickMeals
                  .map(
                    (meal) => ActionChip(
                      label: Text(meal),
                      avatar: const Icon(Icons.restaurant, size: 18),
                      onPressed: () => _addMeal(meal),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryPanel(
    BuildContext context,
    NutritionWeekSummary summary,
  ) {
    final average = summary.dailyAverage;
    return Row(
      children: <Widget>[
        Expanded(
          child: _metricCard(
            context,
            '${average.calories}',
            'kcal/日',
            Icons.local_fire_department_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricCard(
            context,
            '${average.proteinG.round()}g',
            'たんぱく質',
            Icons.egg_alt_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricCard(
            context,
            '${average.vegetablesG.round()}g',
            '野菜',
            Icons.eco_outlined,
          ),
        ),
      ],
    );
  }

  Widget _metricCard(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningPanel(
    BuildContext context,
    NutritionWeekSummary summary,
  ) {
    final warnings = summary.warnings;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('meal_nutrition_alerts'),
      color: warnings.isEmpty
          ? colorScheme.primaryContainer
          : colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  warnings.isEmpty
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_outlined,
                ),
                const SizedBox(width: 8),
                Text(
                  warnings.isEmpty ? '今週の栄養バランスは安定しています' : '栄養アラート',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (warnings.isEmpty)
              const Text('外食が続く日は、野菜と塩分だけ先に確認します。')
            else
              ...warnings.map(
                (warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('・$warning'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart(BuildContext context, NutritionWeekSummary summary) {
    final average = summary.dailyAverage;
    return Card(
      key: const Key('meal_nutrition_week_chart'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '1週間の栄養バランス',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _nutritionBar(
              context,
              label: 'カロリー',
              value: average.calories.toDouble(),
              target: MealNutritionService.dailyTarget.calories.toDouble(),
              suffix: 'kcal',
            ),
            _nutritionBar(
              context,
              label: 'たんぱく質',
              value: average.proteinG,
              target: MealNutritionService.dailyTarget.proteinG,
              suffix: 'g',
            ),
            _nutritionBar(
              context,
              label: '脂質',
              value: average.fatG,
              target: MealNutritionService.dailyTarget.fatG,
              suffix: 'g',
            ),
            _nutritionBar(
              context,
              label: '炭水化物',
              value: average.carbsG,
              target: MealNutritionService.dailyTarget.carbsG,
              suffix: 'g',
            ),
            _nutritionBar(
              context,
              label: '野菜',
              value: average.vegetablesG,
              target: MealNutritionService.dailyTarget.vegetablesG,
              suffix: 'g',
            ),
            _nutritionBar(
              context,
              label: '塩分目安',
              value: average.sodiumMg.toDouble(),
              target: MealNutritionService.dailyTarget.sodiumMg.toDouble(),
              suffix: 'mg',
            ),
          ],
        ),
      ),
    );
  }

  Widget _nutritionBar(
    BuildContext context, {
    required String label,
    required double value,
    required double target,
    required String suffix,
  }) {
    final ratio = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.4);
    final progress = ratio.clamp(0.0, 1.0);
    final valueText = suffix == 'mg' || suffix == 'kcal'
        ? '${value.round()}$suffix'
        : '${value.toStringAsFixed(0)}$suffix';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox(width: 88, child: Text(label)),
              Expanded(
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 84,
                child: Text(valueText, textAlign: TextAlign.right),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogList(BuildContext context, List<MealNutritionLog> logs) {
    if (logs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('まだ食事ログがありません。上の入力欄から1食を記録してください。'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '最近の食事ログ',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...logs.take(14).map(
              (log) => Card(
                child: ListTile(
                  leading: const Icon(Icons.restaurant_menu),
                  title: Text(log.estimate.label),
                  subtitle: Text(log.estimate.advice),
                  trailing: Text('${log.estimate.facts.calories} kcal'),
                ),
              ),
            ),
      ],
    );
  }
}
