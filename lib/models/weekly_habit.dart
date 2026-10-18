/// The weekly minimum is independent of overdue financial/action tasks.
class WeeklyHabit {
  const WeeklyHabit(this.weekday, this.title, this.minimum);

  final int weekday;
  final String title;
  final String minimum;

  Map<String, Object> toJson() => {
        'weekday': weekday,
        'title': title,
        'minimum': minimum,
      };

  static const defaults = <WeeklyHabit>[
    WeeklyHabit(1, 'ギターの練習', '手に取って5分弾く'),
    WeeklyHabit(2, '読書', '2ページ読む'),
    WeeklyHabit(3, 'アプリ開発', '改善を1つ進めて、次にやることを残す'),
    WeeklyHabit(4, '洗い物', '残っている食器を片づける'),
    WeeklyHabit(5, '風呂', 'シャワーだけでも浴びる'),
    WeeklyHabit(6, '映画', '1本選んで見始める。眠ければ続きは翌日'),
    WeeklyHabit(7, 'レシート整理', '財布のレシートを出して、1枚整理'),
  ];
}

/// Retains the wording at completion, even if the weekly plan changes later.
class WeeklyHabitCompletion {
  const WeeklyHabitCompletion(this.title, this.minimum);
  final String title;
  final String minimum;

  Map<String, String> toJson() => {'title': title, 'minimum': minimum};
}

class WeeklyHabitState {
  WeeklyHabitState({
    required this.habits,
    required this.completions,
  });

  final List<WeeklyHabit> habits;
  final Map<String, WeeklyHabitCompletion> completions;

  factory WeeklyHabitState.initial() => WeeklyHabitState(
        habits: List.of(WeeklyHabit.defaults),
        completions: {},
      );

  WeeklyHabit forDate(DateTime date) =>
      habits.firstWhere((habit) => habit.weekday == date.weekday);

  static DateTime japanDate(DateTime instant) {
    final japan = instant.toUtc().add(const Duration(hours: 9));
    return DateTime.utc(japan.year, japan.month, japan.day);
  }

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  WeeklyHabitState withHabit(WeeklyHabit habit) => WeeklyHabitState(
        habits: [
          for (final current in habits)
            if (current.weekday == habit.weekday) habit else current,
        ],
        completions: Map.of(completions),
      );

  WeeklyHabitState withCompleted(DateTime date, bool completed) {
    final next = Map.of(completions);
    final habit = forDate(date);
    if (completed) {
      next[dateKey(date)] = WeeklyHabitCompletion(habit.title, habit.minimum);
    } else {
      next.remove(dateKey(date));
    }
    return WeeklyHabitState(habits: List.of(habits), completions: next);
  }

  Map<String, Object> toJson() => {
        'version': 1,
        'habits': habits.map((habit) => habit.toJson()).toList(),
        'completions':
            completions.map((key, value) => MapEntry(key, value.toJson())),
      };

  factory WeeklyHabitState.fromJson(Map<String, dynamic> json) {
    final raw = json['habits'];
    final records = json['completions'];
    if (json['version'] != 1 ||
        raw is! List ||
        records is! Map ||
        raw.length != 7) {
      throw const FormatException('Unsupported weekly habit schema');
    }
    final habits = <int, WeeklyHabit>{};
    for (final item in raw) {
      if (item is! Map) throw const FormatException('Invalid weekly habit');
      final day = item['weekday'];
      final title = item['title'];
      final minimum = item['minimum'];
      if (day is! int ||
          day < 1 ||
          day > 7 ||
          habits.containsKey(day) ||
          title is! String ||
          title.trim().isEmpty ||
          title.length > 60 ||
          minimum is! String ||
          minimum.trim().isEmpty ||
          minimum.length > 200) {
        throw const FormatException('Invalid weekly habit');
      }
      habits[day] = WeeklyHabit(day, title, minimum);
    }
    final completions = <String, WeeklyHabitCompletion>{};
    for (final entry in records.entries) {
      final key = entry.key;
      final value = entry.value;
      final date = key is String ? DateTime.tryParse(key) : null;
      if (date == null ||
          date.year < 2000 ||
          dateKey(date) != key ||
          value is! Map ||
          value['title'] is! String ||
          (value['title'] as String).trim().isEmpty ||
          value['minimum'] is! String ||
          (value['minimum'] as String).trim().isEmpty) {
        throw const FormatException('Invalid weekly habit completion');
      }
      completions[key as String] = WeeklyHabitCompletion(
        value['title'] as String,
        value['minimum'] as String,
      );
    }
    return WeeklyHabitState(
      habits: [for (var day = 1; day <= 7; day++) habits[day]!],
      completions: completions,
    );
  }
}
