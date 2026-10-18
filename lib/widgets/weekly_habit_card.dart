import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weekly_habit.dart';
import '../services/weekly_habit_store.dart';

class WeeklyHabitCard extends StatefulWidget {
  const WeeklyHabitCard({super.key, required this.userId, this.now});

  final String? userId;
  final DateTime Function()? now;

  @override
  State<WeeklyHabitCard> createState() => _WeeklyHabitCardState();
}

class _WeeklyHabitCardState extends State<WeeklyHabitCard>
    with WidgetsBindingObserver {
  static const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
  WeeklyHabitStore? _store;
  WeeklyHabitState _data = WeeklyHabitState.initial();
  late DateTime _today;
  late DateTime _selected;
  Timer? _timer;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _loadGeneration = 0;

  DateTime _japanToday() =>
      WeeklyHabitState.japanDate(widget.now?.call() ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _today = _japanToday();
    _selected = _today;
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refreshDay());
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant WeeklyHabitCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDay();
  }

  void _refreshDay() {
    final next = _japanToday();
    if (!mounted || next == _today) return;
    setState(
      () {
        if (_selected == _today) _selected = next;
        _today = next;
      },
    );
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(
      () {
        _loading = true;
        _store = null;
        _data = WeeklyHabitState.initial();
        _error = null;
      },
    );
    try {
      final id = widget.userId;
      if (id != null) {
        final preferences = await SharedPreferences.getInstance();
        final store = WeeklyHabitStore(preferences, userId: id);
        final data = store.load();
        if (!mounted || generation != _loadGeneration) return;
        setState(
          () {
            _store = store;
            _data = data;
          },
        );
      }
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = '習慣の読込に失敗しました。元の保存内容は変更していません。');
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save(WeeklyHabitState next) async {
    final store = _store;
    final generation = _loadGeneration;
    if (store == null || _saving || _selected.isAfter(_japanToday())) return;
    setState(
      () {
        _saving = true;
        _error = null;
      },
    );
    try {
      await store.save(next);
      if (mounted && generation == _loadGeneration) {
        setState(() => _data = next);
      }
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = '保存できませんでした。達成・設定は変更していません。');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit(WeeklyHabit habit) async {
    final generation = _loadGeneration;
    final title = TextEditingController(text: habit.title);
    final minimum = TextEditingController(text: habit.minimum);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<WeeklyHabit>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${weekdays[habit.weekday - 1]}曜日の習慣'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: title,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: '習慣'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? '習慣を入力してください'
                      : null,
                ),
                TextFormField(
                  controller: minimum,
                  maxLength: 200,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: '達成とする最低ライン'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? '最低ラインを入力してください'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(
                  context,
                  WeeklyHabit(
                    habit.weekday,
                    title.text.trim(),
                    minimum.text.trim(),
                  ),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    // The dialog route can still render its reverse animation after pop.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    title.dispose();
    minimum.dispose();
    if (result != null && mounted && generation == _loadGeneration) {
      await _save(_data.withHabit(result));
    }
  }

  Future<void> _chooseDate() async {
    _refreshDay();
    final date = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2000),
      lastDate: _today,
    );
    if (date != null && mounted) {
      setState(() => _selected = DateTime.utc(date.year, date.month, date.day));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateKey = WeeklyHabitState.dateKey(_selected);
    final habit = _data.forDate(_selected);
    final completion = _data.completions[dateKey];
    final canWrite = !_loading && !_saving && _store != null;
    final history = _data.completions.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('寝る前の曜日習慣', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('最低ラインで達成。未達を翌日に上乗せせず、睡眠を削らない。'),
            const Text('洗い物・入浴は普段も必要に応じて行い、木・金は特に溜めない日。'),
            const SizedBox(height: 8),
            const Text('このアカウントの端末・ブラウザー内に保存（端末間同期なし）。ブラウザーデータを削除すると消えます。'),
            if (widget.userId == null)
              const Text('記録にはログインしてください。現在は初期設定の見本です。'),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: _saving ? null : _load,
                child: const Text('再読込'),
              ),
            ],
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '$dateKey（${weekdays[_selected.weekday - 1]}）日本時間${_selected == _today ? '・今日' : '・過去の日'}',
                ),
                TextButton(
                  onPressed: _loading || _saving ? null : _chooseDate,
                  child: const Text('日付を選ぶ'),
                ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () {
                          _refreshDay();
                          setState(() => _selected = _today);
                        },
                  child: const Text('今日へ'),
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(completion?.title ?? habit.title),
              subtitle: Text(completion?.minimum ?? habit.minimum),
              value: completion != null,
              onChanged: canWrite
                  ? (value) =>
                      _save(_data.withCompleted(_selected, value ?? false))
                  : null,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (_saving) const Text('保存中…'),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('曜日ごとの設定'),
              children: [
                for (final item in _data.habits)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${weekdays[item.weekday - 1]}：${item.title}'),
                    subtitle: Text(item.minimum),
                    trailing: IconButton(
                      tooltip: '${weekdays[item.weekday - 1]}曜日を編集',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: canWrite ? () => _edit(item) : null,
                    ),
                  ),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('達成履歴（${history.length}日）'),
              children: [
                if (history.isEmpty)
                  const ListTile(title: Text('達成記録はまだありません。自動で達成にはなりません。')),
                for (final date in history.take(30))
                  ListTile(
                    title: Text('$date：${_data.completions[date]!.title}'),
                    subtitle: Text(_data.completions[date]!.minimum),
                    onTap: _saving ||
                            date.compareTo(WeeklyHabitState.dateKey(_today)) > 0
                        ? null
                        : () => setState(
                              () => _selected =
                                  DateTime.parse('${date}T00:00:00Z'),
                            ),
                  ),
                if (history.length > 30)
                  const Text('直近30件を表示。以前の記録は「日付を選ぶ」から確認できます。'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
