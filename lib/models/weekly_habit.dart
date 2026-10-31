class WeeklyHabit {
  const WeeklyHabit(this.id, this.weekday, this.title, this.minimum);
  final String id;
  final int weekday;
  final String title;
  final String minimum;
  Map<String, Object> toJson() =>
      {'id': id, 'weekday': weekday, 'title': title, 'minimum': minimum};
  static const defaults = <WeeklyHabit>[
    WeeklyHabit('guitar', 1, 'ギターの練習', '手に取って5分弾く'),
    WeeklyHabit('reading', 2, '読書', '2ページ読む'),
    WeeklyHabit('development', 3, 'アプリ開発', '改善を1つ進めて、次にやることを残す'),
    WeeklyHabit('balance', 3, '口座残高更新', '1口座の残高を確認して更新'),
    WeeklyHabit('dishes', 4, '洗い物', '残っている食器を片づける'),
    WeeklyHabit('stocks', 4, '株の整理', '保有株の記録を1件確認・整理（売買を伴わない）'),
    WeeklyHabit('bath', 5, '風呂', 'シャワーだけでも浴びる'),
    WeeklyHabit('movie', 6, '映画', '1本選んで見始める。眠ければ続きは翌日'),
    WeeklyHabit('receipts', 7, 'レシート整理', '財布のレシートを出して、1枚整理'),
  ];
}

class WeeklyHabitCompletion {
  const WeeklyHabitCompletion(
    this.date,
    this.habitId,
    this.title,
    this.minimum,
  );
  final String date;
  final String habitId;
  final String title;
  final String minimum;
  String get key => '$date/$habitId';
  Map<String, String> toJson() =>
      {'date': date, 'habitId': habitId, 'title': title, 'minimum': minimum};
}

class WeeklyHabitState {
  WeeklyHabitState({required this.habits, required this.completions});
  final List<WeeklyHabit> habits;
  final Map<String, WeeklyHabitCompletion> completions;
  factory WeeklyHabitState.initial() =>
      WeeklyHabitState(habits: List.of(WeeklyHabit.defaults), completions: {});
  List<WeeklyHabit> forDate(DateTime date) =>
      habits.where((habit) => habit.weekday == date.weekday).toList();
  static DateTime japanDate(DateTime instant) {
    final japan = instant.toUtc().add(const Duration(hours: 9));
    return DateTime.utc(japan.year, japan.month, japan.day);
  }

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  WeeklyHabitCompletion? completion(DateTime date, String habitId) =>
      completions['${dateKey(date)}/$habitId'];
  WeeklyHabitState withHabit(WeeklyHabit habit) => WeeklyHabitState(
        habits: [
          for (final current in habits)
            if (current.id != habit.id) current,
          habit,
        ],
        completions: Map.of(completions),
      );
  WeeklyHabitState withoutHabit(String id) => WeeklyHabitState(
        habits: habits.where((habit) => habit.id != id).toList(),
        completions: Map.of(completions),
      );
  WeeklyHabitState withCompleted(DateTime date, WeeklyHabit habit, bool done) {
    final next = Map.of(completions);
    final record = WeeklyHabitCompletion(
      dateKey(date),
      habit.id,
      habit.title,
      habit.minimum,
    );
    if (done) {
      next[record.key] = record;
    } else {
      next.remove(record.key);
    }
    return WeeklyHabitState(habits: List.of(habits), completions: next);
  }

  WeeklyHabitState withoutCompletion(String key) => WeeklyHabitState(
        habits: List.of(habits),
        completions: Map.of(completions)..remove(key),
      );
  Map<String, Object> toJson() => {
        'version': 2,
        'habits': habits.map((habit) => habit.toJson()).toList(),
        'completions':
            completions.map((key, value) => MapEntry(key, value.toJson())),
      };
  static String _text(dynamic value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Invalid weekly habit text');
    }
    return value;
  }

  static String _date(dynamic value) {
    final text = _text(value);
    final parsed = DateTime.tryParse(text);
    if (parsed == null || parsed.year < 2000 || dateKey(parsed) != text) {
      throw const FormatException('Invalid weekly habit date');
    }
    return text;
  }

  factory WeeklyHabitState.fromJson(Map<String, dynamic> json) {
    final raw = json['habits'];
    final records = json['completions'];
    final version = json['version'];
    if ((version != 1 && version != 2) || raw is! List || records is! Map) {
      throw const FormatException('Unsupported weekly habit schema');
    }
    final habits = <WeeklyHabit>[];
    final ids = <String>{};
    final oldDays = <int>{};
    for (final item in raw) {
      if (item is! Map) throw const FormatException('Invalid weekly habit');
      final day = item['weekday'];
      if (day is! int || day < 1 || day > 7) {
        throw const FormatException('Invalid weekday');
      }
      final id = version == 1 ? 'legacy-$day' : _text(item['id']);
      final title = _text(item['title']);
      final minimum = _text(item['minimum']);
      if (!ids.add(id) ||
          id.contains('/') ||
          title.length > 60 ||
          minimum.length > 200 ||
          (version == 1 && !oldDays.add(day))) {
        throw const FormatException('Invalid weekly habit');
      }
      habits.add(WeeklyHabit(id, day, title, minimum));
    }
    if (version == 1 && oldDays.length != 7) {
      throw const FormatException('Invalid legacy week');
    }
    if (version == 1) {
      habits.addAll(
        WeeklyHabit.defaults
            .where((habit) => habit.id == 'balance' || habit.id == 'stocks'),
      );
    }
    final completions = <String, WeeklyHabitCompletion>{};
    for (final entry in records.entries) {
      final value = entry.value;
      if (value is! Map) throw const FormatException('Invalid completion');
      final date = _date(version == 1 ? entry.key : value['date']);
      final id = version == 1
          ? 'legacy-${DateTime.parse(date).weekday}'
          : _text(value['habitId']);
      final record = WeeklyHabitCompletion(
        date,
        id,
        _text(value['title']),
        _text(value['minimum']),
      );
      if (id.contains('/') || (version == 2 && record.key != entry.key)) {
        throw const FormatException('Invalid completion key');
      }
      completions[record.key] = record;
    }
    return WeeklyHabitState(habits: habits, completions: completions);
  }
}
