import 'package:flutter/material.dart';

class HabitGoalOption {
  const HabitGoalOption({required this.id, required this.title});

  final String id;
  final String title;
}

class HabitResourceEntry {
  const HabitResourceEntry({
    required this.timeCostMinutes,
    required this.fatigueScore,
    required this.goalContributionScore,
    required this.goalId,
    required this.goalTitle,
  });

  final int timeCostMinutes;
  final double fatigueScore;
  final double goalContributionScore;
  final String? goalId;
  final String? goalTitle;
}

class HabitResourceMetricsDialog extends StatefulWidget {
  const HabitResourceMetricsDialog({
    super.key,
    required this.habitTitle,
    required this.goals,
    this.dialogTitle = '実績コストを記録',
    this.submitLabel = '完了を記録',
    this.initialTimeCostMinutes = 15,
    this.initialFatigueScore = 3,
    this.initialGoalContributionScore = 50,
    this.initialGoalId,
  });

  final String habitTitle;
  final List<HabitGoalOption> goals;
  final String dialogTitle;
  final String submitLabel;
  final int initialTimeCostMinutes;
  final double initialFatigueScore;
  final double initialGoalContributionScore;
  final String? initialGoalId;

  @override
  State<HabitResourceMetricsDialog> createState() =>
      _HabitResourceMetricsDialogState();
}

class _HabitResourceMetricsDialogState
    extends State<HabitResourceMetricsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _timeController;
  late double _fatigueScore;
  late double _goalContributionScore;
  String? _goalId;

  @override
  void initState() {
    super.initState();
    _timeController = TextEditingController(
      text: widget.initialTimeCostMinutes.clamp(1, 1440).toString(),
    );
    _fatigueScore = widget.initialFatigueScore.clamp(1, 10);
    _goalContributionScore = widget.initialGoalContributionScore.clamp(0, 100);
    _goalId = widget.goals.any((goal) => goal.id == widget.initialGoalId)
        ? widget.initialGoalId
        : null;
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final goal = _goalId == null
        ? null
        : widget.goals.where((item) => item.id == _goalId).firstOrNull;
    Navigator.of(context).pop(
      HabitResourceEntry(
        timeCostMinutes: int.parse(_timeController.text),
        fatigueScore: _fatigueScore,
        goalContributionScore: _goalContributionScore,
        goalId: goal?.id,
        goalTitle: goal?.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.dialogTitle),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.habitTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('resource_time_minutes'),
                  controller: _timeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '所要時間',
                    suffixText: '分',
                    prefixIcon: Icon(Icons.schedule),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final minutes = int.tryParse(value ?? '');
                    if (minutes == null || minutes < 1 || minutes > 1440) {
                      return '1〜1440分で入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _ScoreSlider(
                  key: const Key('resource_fatigue_score'),
                  label: '疲労度',
                  value: _fatigueScore,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  valueLabel: _fatigueScore.toStringAsFixed(0),
                  onChanged: (value) => setState(() => _fatigueScore = value),
                ),
                const SizedBox(height: 8),
                _ScoreSlider(
                  key: const Key('resource_goal_contribution'),
                  label: '目標への貢献度',
                  value: _goalContributionScore,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  valueLabel: '${_goalContributionScore.round()}%',
                  onChanged: (value) =>
                      setState(() => _goalContributionScore = value),
                ),
                if (widget.goals.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    key: const Key('resource_goal_selector'),
                    initialValue: _goalId,
                    decoration: const InputDecoration(
                      labelText: '対象目標',
                      prefixIcon: Icon(Icons.flag_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('目標を指定しない'),
                      ),
                      ...widget.goals.map(
                        (goal) => DropdownMenuItem<String?>(
                          value: goal.id,
                          child: Text(
                            goal.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _goalId = value),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton.icon(
          key: const Key('resource_metrics_submit'),
          onPressed: _submit,
          icon: const Icon(Icons.check),
          label: Text(widget.submitLabel),
        ),
      ],
    );
  }
}

class _ScoreSlider extends StatelessWidget {
  const _ScoreSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              valueLabel,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
