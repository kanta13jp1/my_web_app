/// 資産管理画面「今日やること」機能のモデル。
///
/// 思想: 「今日やるべきタスクをやらずに寝ると、それは翌日やらねばならない
/// タスク＝概念的な借金になる」。未完了で予定日を過ぎたタスクは
/// 「繰り越し(明日への借金)」として日数付きで重く扱い、日々こなした実績は
/// 完遂ログとして蓄積して細木数子AIの行動アドバイス材料にする。
library;

/// 日付のみ(ローカル、時刻を切り捨て)へ正規化する。
DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// `yyyy-MM-dd` 形式の日付キー(ローカル)。
String dailyTodoDateKey(DateTime value) {
  final d = _dateOnly(value);
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// 「今日やること」1件。
class DailyTodoTask {
  final String id;
  final String title;

  /// 「その日にやる」と決めた日(日付のみ, ローカル)。未完了のまま過ぎると
  /// 繰り越し(借金)になる基準日。
  final DateTime plannedDate;
  final bool completed;
  final DateTime? completedAt;
  final String note;

  DailyTodoTask({
    required this.id,
    required this.title,
    required DateTime plannedDate,
    this.completed = false,
    this.completedAt,
    this.note = '',
  }) : plannedDate = _dateOnly(plannedDate);

  DailyTodoTask copyWith({
    String? id,
    String? title,
    DateTime? plannedDate,
    bool? completed,
    Object? completedAt = _sentinel,
    String? note,
  }) {
    return DailyTodoTask(
      id: id ?? this.id,
      title: title ?? this.title,
      plannedDate: plannedDate ?? this.plannedDate,
      completed: completed ?? this.completed,
      completedAt: completedAt == _sentinel
          ? this.completedAt
          : completedAt as DateTime?,
      note: note ?? this.note,
    );
  }

  /// 未完了かつ予定日が [today] より前 = 繰り越し(明日への借金)。
  bool isCarriedOverAsOf(DateTime today) =>
      !completed && plannedDate.isBefore(_dateOnly(today));

  /// 繰り越し日数(予定日から [today] までの経過日数)。繰り越しでなければ 0。
  int carryOverDaysAsOf(DateTime today) {
    if (!isCarriedOverAsOf(today)) {
      return 0;
    }
    return _dateOnly(today).difference(plannedDate).inDays;
  }

  /// 予定日が [today] と同じ日か。
  bool isForToday(DateTime today) => plannedDate == _dateOnly(today);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'planned_date': dailyTodoDateKey(plannedDate),
        'completed': completed,
        'completed_at': completedAt?.toUtc().toIso8601String(),
        'note': note,
      };

  /// 破損データは null を返す(呼び出し側で除外)。
  static DailyTodoTask? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final id = raw['id']?.toString().trim() ?? '';
    final title = raw['title']?.toString().trim() ?? '';
    if (id.isEmpty || title.isEmpty) {
      return null;
    }
    final plannedDate = _parseDate(raw['planned_date']);
    if (plannedDate == null) {
      return null;
    }
    final completed = raw['completed'] == true;
    final completedAt = DateTime.tryParse(
      raw['completed_at']?.toString() ?? '',
    )?.toLocal();
    return DailyTodoTask(
      id: id,
      title: title,
      plannedDate: plannedDate,
      completed: completed,
      completedAt: completed ? completedAt : null,
      note: raw['note']?.toString() ?? '',
    );
  }

  static const Object _sentinel = Object();
}

/// 完遂ログの1件(append-only)。日々こなしたタスクの durable な記録。
class DailyTodoCompletionLogEntry {
  /// 完了した日(ローカル, `yyyy-MM-dd`)。
  final String dateKey;
  final String title;
  final DateTime completedAt;

  DailyTodoCompletionLogEntry({
    required this.dateKey,
    required this.title,
    required this.completedAt,
  });

  /// 和集合マージ時の一意キー(日 × タイトル × 完了時刻)。
  String get mergeKey =>
      '$dateKey|$title|${completedAt.toUtc().toIso8601String()}';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': dateKey,
        'title': title,
        'completed_at': completedAt.toUtc().toIso8601String(),
      };

  static DailyTodoCompletionLogEntry? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final title = raw['title']?.toString().trim() ?? '';
    final completedAt = DateTime.tryParse(
      raw['completed_at']?.toString() ?? '',
    )?.toLocal();
    if (title.isEmpty || completedAt == null) {
      return null;
    }
    final rawDate = raw['date']?.toString().trim() ?? '';
    final dateKey =
        rawDate.isNotEmpty ? rawDate : dailyTodoDateKey(completedAt);
    return DailyTodoCompletionLogEntry(
      dateKey: dateKey,
      title: title,
      completedAt: completedAt,
    );
  }
}

/// 1日分の完遂サマリ(細木数子AIへ渡す日別の行動記録)。
class DailyTodoDaySummary {
  final String dateKey;
  final List<String> completedTitles;

  const DailyTodoDaySummary({
    required this.dateKey,
    required this.completedTitles,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': dateKey,
        'completed_titles': completedTitles,
        'completed_count': completedTitles.length,
      };
}

/// タスク・完遂ログから算出した、UI表示と細木数子AI入力の両方に使う要約。
class DailyTodoDigest {
  final DateTime asOf;
  final int todayTotal;
  final int todayCompleted;
  final int todayPending;

  /// 繰り越し(未完了で予定日超過 = 明日への借金)の件数。
  final int carriedOverCount;

  /// 最も長く繰り越されているタスクの日数。
  final int maxCarryOverDays;

  /// 繰り越しタスクのタイトル(古い順, 最大5件)。
  final List<String> carriedOverTitles;

  /// 直近7日間の完了件数。
  final int completedLast7Days;

  /// 今日まで連続で1件以上完了した日数(連続実行日数)。
  final int activeStreakDays;

  /// 直近7日間の日別完遂サマリ(新しい日が先頭)。
  final List<DailyTodoDaySummary> recentDays;

  const DailyTodoDigest({
    required this.asOf,
    required this.todayTotal,
    required this.todayCompleted,
    required this.todayPending,
    required this.carriedOverCount,
    required this.maxCarryOverDays,
    required this.carriedOverTitles,
    required this.completedLast7Days,
    required this.activeStreakDays,
    required this.recentDays,
  });

  /// タスク一覧が空でログも無い = ToDo 未利用。
  bool get isEmpty =>
      todayTotal == 0 && carriedOverCount == 0 && completedLast7Days == 0;

  /// 細木数子AIへ渡す構造化ペイロード。
  Map<String, dynamic> toAiJson() => <String, dynamic>{
        'as_of': dailyTodoDateKey(asOf),
        'today_total': todayTotal,
        'today_completed': todayCompleted,
        'today_pending': todayPending,
        'carried_over_count': carriedOverCount,
        'max_carry_over_days': maxCarryOverDays,
        'carried_over_titles': carriedOverTitles,
        'completed_last_7_days': completedLast7Days,
        'active_streak_days': activeStreakDays,
        'recent_days': recentDays.map((day) => day.toJson()).toList(),
        'philosophy': 'やらずに寝たタスクは翌日の借金になる。carried_over は溜めた行動の借金、'
            'active_streak_days と recent_days は日々こなした実績。金銭の負債と'
            '同じ熱量で、行動の借金と実績にも具体的に言及すること。',
      };

  /// AI無効時などに使う決定論的な1〜2行サマリ。
  String toHeadline() {
    if (isEmpty) {
      return '今日やることは未登録です。まず1つ登録して、やり切って寝ましょう。';
    }
    final parts = <String>[
      '本日 $todayCompleted/$todayTotal 完了',
      if (carriedOverCount > 0)
        '繰り越し(借金) $carriedOverCount件(最長$maxCarryOverDays日)'
      else
        '繰り越しの借金なし',
      if (activeStreakDays > 0) '連続$activeStreakDays日実行中',
    ];
    return parts.join(' / ');
  }

  /// タスク一覧と完遂ログから要約を算出する純関数。
  factory DailyTodoDigest.fromState({
    required List<DailyTodoTask> tasks,
    required List<DailyTodoCompletionLogEntry> log,
    required DateTime now,
  }) {
    final today = _dateOnly(now);
    final todayKey = dailyTodoDateKey(today);

    final todayTasks = tasks.where((t) => t.isForToday(today)).toList();
    final todayCompleted = todayTasks.where((t) => t.completed).length;

    final carriedOver = tasks.where((t) => t.isCarriedOverAsOf(today)).toList()
      ..sort((a, b) => a.plannedDate.compareTo(b.plannedDate));
    final maxCarryOverDays = carriedOver.isEmpty
        ? 0
        : carriedOver
            .map((t) => t.carryOverDaysAsOf(today))
            .reduce((a, b) => a > b ? a : b);

    // 日別に完了タイトルを集約(タスクの completedAt とログの両方を統合)。
    final byDay = <String, List<String>>{};
    void addToDay(String dateKey, String title) {
      (byDay[dateKey] ??= <String>[]).add(title);
    }

    for (final entry in log) {
      addToDay(entry.dateKey, entry.title);
    }
    // ログに未記録の完了タスク(古い実装や取りこぼし)も補完する。
    for (final task in tasks) {
      if (task.completed && task.completedAt != null) {
        final key = dailyTodoDateKey(task.completedAt!);
        final existing = byDay[key];
        if (existing == null || !existing.contains(task.title)) {
          addToDay(key, task.title);
        }
      }
    }

    // 直近7日(今日を含む)の日別サマリ。新しい日が先頭。
    final recentDays = <DailyTodoDaySummary>[];
    var completedLast7Days = 0;
    for (var i = 0; i < 7; i++) {
      final day = today.subtract(Duration(days: i));
      final key = dailyTodoDateKey(day);
      final titles = byDay[key] ?? const <String>[];
      completedLast7Days += titles.length;
      recentDays.add(
        DailyTodoDaySummary(
          dateKey: key,
          completedTitles: List<String>.unmodifiable(titles),
        ),
      );
    }

    // 連続実行日数: 今日から遡って1件以上完了した日が続く限りカウント。
    // 今日が未完了でも、昨日以前の連続は途切れていない扱い(今日はこれから)。
    var streak = 0;
    var cursor = today;
    if ((byDay[todayKey] ?? const <String>[]).isEmpty) {
      // 今日まだ0件なら昨日から数える(今日の猶予を残す)。
      cursor = today.subtract(const Duration(days: 1));
    }
    for (var i = 0; i < 366; i++) {
      final key = dailyTodoDateKey(cursor);
      if ((byDay[key] ?? const <String>[]).isEmpty) {
        break;
      }
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return DailyTodoDigest(
      asOf: today,
      todayTotal: todayTasks.length,
      todayCompleted: todayCompleted,
      todayPending: todayTasks.length - todayCompleted,
      carriedOverCount: carriedOver.length,
      maxCarryOverDays: maxCarryOverDays,
      carriedOverTitles: List<String>.unmodifiable(
        carriedOver.take(5).map((t) => t.title),
      ),
      completedLast7Days: completedLast7Days,
      activeStreakDays: streak,
      recentDays: List<DailyTodoDaySummary>.unmodifiable(recentDays),
    );
  }
}

DateTime? _parseDate(Object? raw) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  final parsed = DateTime.tryParse(text);
  if (parsed == null) {
    return null;
  }
  return _dateOnly(parsed.toLocal());
}
