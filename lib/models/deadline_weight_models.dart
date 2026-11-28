/// 「締め切りの重さ」の純粋ロジック。
///
/// ADHD 傾向の脳は、遠い締め切りを「身体的な重さを伴う脅威」として
/// 認識しにくい (時間盲目性 / 時間的近視眼)。残り日数は頭ではわかっても
/// 実感にならないため、ここでは締め切りを
/// **「実際に手を動かせる残り時間 = 可処分時間」** に換算する。
///
/// この層は Supabase にも Flutter にも依存せず、`now` を引数で受け取る。
/// そのため計算の全分岐を単体テストで固定できる。
library;

/// 曜日ごとの可処分時間 (分)。
///
/// キーは `DateTime.weekday` と同じ 月=1 .. 日=7。
class DisposableTimeSettings {
  const DisposableTimeSettings({required this.minutesByWeekday});

  /// 設定がまだ無いユーザーに使う初期値 (平日 2 時間 / 週末 5 時間)。
  ///
  /// migration の DEFAULT と同じ値にしてあるので、保存前後で数字が動かない。
  static const DisposableTimeSettings initial = DisposableTimeSettings(
    minutesByWeekday: <int, int>{
      DateTime.monday: 120,
      DateTime.tuesday: 120,
      DateTime.wednesday: 120,
      DateTime.thursday: 120,
      DateTime.friday: 120,
      DateTime.saturday: 300,
      DateTime.sunday: 300,
    },
  );

  final Map<int, int> minutesByWeekday;

  /// [day] の曜日に割り当てられた可処分時間 (分)。未設定の曜日は 0 とみなす。
  int minutesOn(DateTime day) {
    final raw = minutesByWeekday[day.weekday] ?? 0;
    return raw.clamp(0, 1440);
  }

  /// 1 週間あたりの可処分時間 (分)。
  int get weeklyMinutes => <int>[
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
        DateTime.sunday,
      ].fold<int>(
        0,
        (sum, weekday) => sum + (minutesByWeekday[weekday] ?? 0).clamp(0, 1440),
      );

  DisposableTimeSettings copyWith({
    required int weekday,
    required int minutes,
  }) {
    final next = Map<int, int>.from(minutesByWeekday);
    next[weekday] = minutes.clamp(0, 1440);
    return DisposableTimeSettings(minutesByWeekday: next);
  }

  /// Supabase の 1 行 (曜日ごとの列) から読み出す。行が無ければ [initial]。
  static DisposableTimeSettings fromRow(Map<String, dynamic>? row) {
    if (row == null) return initial;
    int read(String column, int fallback) {
      final value = row[column];
      if (value is int) return value.clamp(0, 1440);
      if (value is num) return value.round().clamp(0, 1440);
      return fallback;
    }

    return DisposableTimeSettings(
      minutesByWeekday: <int, int>{
        DateTime.monday: read('monday_minutes', 120),
        DateTime.tuesday: read('tuesday_minutes', 120),
        DateTime.wednesday: read('wednesday_minutes', 120),
        DateTime.thursday: read('thursday_minutes', 120),
        DateTime.friday: read('friday_minutes', 120),
        DateTime.saturday: read('saturday_minutes', 300),
        DateTime.sunday: read('sunday_minutes', 300),
      },
    );
  }

  /// Supabase へ書き戻すための列マップ。
  Map<String, dynamic> toRow() => <String, dynamic>{
        'monday_minutes': minutesByWeekday[DateTime.monday] ?? 0,
        'tuesday_minutes': minutesByWeekday[DateTime.tuesday] ?? 0,
        'wednesday_minutes': minutesByWeekday[DateTime.wednesday] ?? 0,
        'thursday_minutes': minutesByWeekday[DateTime.thursday] ?? 0,
        'friday_minutes': minutesByWeekday[DateTime.friday] ?? 0,
        'saturday_minutes': minutesByWeekday[DateTime.saturday] ?? 0,
        'sunday_minutes': minutesByWeekday[DateTime.sunday] ?? 0,
      };
}

/// 登録された 1 件の締め切り。
class DeadlineItem {
  const DeadlineItem({
    required this.id,
    required this.title,
    required this.dueOn,
    required this.requiredMinutes,
    this.completedAt,
  });

  final String id;
  final String title;

  /// 期日 (日付のみ / ローカル暦)。時刻は保持しない。
  final DateTime dueOn;

  /// 本人が見積もった「まだ必要な作業時間」(分)。
  final int requiredMinutes;

  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  static DeadlineItem fromRow(Map<String, dynamic> row) {
    final rawRequired = row['required_minutes'];
    final required = rawRequired is int
        ? rawRequired
        : (rawRequired is num ? rawRequired.round() : 0);
    return DeadlineItem(
      id: (row['id'] as String?) ?? '',
      title: (row['title'] as String?) ?? '',
      dueOn: dateOnly(_parseDate(row['due_on']) ?? DateTime.now()),
      requiredMinutes: required.clamp(0, 60000),
      completedAt: _parseDate(row['completed_at'])?.toLocal(),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

/// 時刻を落として日付だけにする (ローカル暦)。
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// 締め切りの状態。
enum DeadlineVerdict {
  /// 可処分時間が必要時間の 1.5 倍以上ある。
  comfortable,

  /// 足りてはいるが余裕が 5 割未満。
  tight,

  /// 可処分時間が必要時間に届いていない。
  short,

  /// 期日を過ぎている。
  overdue,
}

/// 「もう足りない」ときに提示する、責めない 3 つの打ち手。
///
/// どれも具体的な数字を持つ。「頑張る」ではなく「何をどれだけ動かすか」を出す。
class RecoveryOptions {
  const RecoveryOptions({
    required this.postponeDays,
    required this.cutMinutes,
    required this.extraMinutesPerDay,
  });

  /// 期日を何日後ろへ動かせば足りるか。1 年以内に解がなければ null。
  final int? postponeDays;

  /// 必要時間を何分削れば足りるか。
  final int cutMinutes;

  /// 残りの日数で割って、1 日あたり何分上乗せすれば足りるか。
  final int extraMinutesPerDay;
}

/// 画面に出す 1 枚のカード。
class DeadlineWeightCard {
  const DeadlineWeightCard({
    required this.item,
    required this.disposableMinutes,
    required this.calendarDaysLeft,
    required this.verdict,
    this.recovery,
  });

  final DeadlineItem item;

  /// 今から期日の終わりまでに手を動かせる残り時間 (分)。
  final int disposableMinutes;

  /// 今日を 1 日目として数えた残り日数。期日超過なら負。
  final int calendarDaysLeft;

  final DeadlineVerdict verdict;

  /// [DeadlineVerdict.short] のときだけ入る。
  final RecoveryOptions? recovery;

  int get requiredMinutes => item.requiredMinutes;

  /// 余り (負なら不足)。
  int get slackMinutes => disposableMinutes - requiredMinutes;

  /// 必要時間に対する可処分時間の比率。必要時間 0 なら 1.0 扱い。
  double get fillRatio => requiredMinutes <= 0
      ? 1
      : (disposableMinutes / requiredMinutes).clamp(0.0, 4.0);
}

/// 画面全体の状態。
class DeadlineWeightSnapshot {
  const DeadlineWeightSnapshot({
    required this.active,
    required this.overdue,
    required this.settings,
  });

  /// 期日が今日以降のもの (期日の近い順 → 不足の大きい順)。
  final List<DeadlineWeightCard> active;

  /// 期日を過ぎたもの (新しい順)。
  final List<DeadlineWeightCard> overdue;

  final DisposableTimeSettings settings;

  bool get isEmpty => active.isEmpty && overdue.isEmpty;

  int get totalCount => active.length + overdue.length;

  /// 「もう足りない」件数。動き出しの優先順位を 1 行で示すために使う。
  int get shortCount =>
      active.where((c) => c.verdict == DeadlineVerdict.short).length;
}

/// 期日を越えて計算を続けない上限 (暴走防止)。
const int maxLookaheadDays = 730;

/// 今から [dueOn] の終わりまでに「実際に手を動かせる」残り分数。
///
/// - 当日分は経過時間で按分する。夜に開けば今日の残りは少なく出る (体感に忠実)。
/// - 翌日から期日当日までは、曜日ごとの設定をそのまま積み上げる。
/// - 期日が過ぎていれば 0。
int disposableMinutesUntil(
  DateTime now,
  DateTime dueOn,
  DisposableTimeSettings settings,
) {
  final today = dateOnly(now);
  final due = dateOnly(dueOn);
  if (due.isBefore(today)) return 0;

  final elapsedToday = now.hour * 60 + now.minute;
  final remainingFraction = ((1440 - elapsedToday) / 1440).clamp(0.0, 1.0);
  var total = (settings.minutesOn(today) * remainingFraction).round();
  if (!due.isAfter(today)) return total;

  var cursor = DateTime(today.year, today.month, today.day + 1);
  var guard = 0;
  while (!cursor.isAfter(due) && guard < maxLookaheadDays) {
    total += settings.minutesOn(cursor);
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    guard += 1;
  }
  return total;
}

/// 今日を 1 日目として数えた残り日数。期日が昨日なら 0、一昨日なら -1。
int calendarDaysLeft(DateTime now, DateTime dueOn) =>
    dateOnly(dueOn).difference(dateOnly(now)).inDays + 1;

/// 1 件分の判定を組み立てる。
DeadlineWeightCard buildCard(
  DeadlineItem item,
  DisposableTimeSettings settings,
  DateTime now,
) {
  final daysLeft = calendarDaysLeft(now, item.dueOn);
  final disposable = disposableMinutesUntil(now, item.dueOn, settings);

  if (dateOnly(item.dueOn).isBefore(dateOnly(now))) {
    return DeadlineWeightCard(
      item: item,
      disposableMinutes: 0,
      calendarDaysLeft: daysLeft,
      verdict: DeadlineVerdict.overdue,
    );
  }

  if (disposable < item.requiredMinutes) {
    return DeadlineWeightCard(
      item: item,
      disposableMinutes: disposable,
      calendarDaysLeft: daysLeft,
      verdict: DeadlineVerdict.short,
      recovery: _buildRecovery(item, settings, now, disposable, daysLeft),
    );
  }

  final verdict = disposable >= (item.requiredMinutes * 1.5)
      ? DeadlineVerdict.comfortable
      : DeadlineVerdict.tight;
  return DeadlineWeightCard(
    item: item,
    disposableMinutes: disposable,
    calendarDaysLeft: daysLeft,
    verdict: verdict,
  );
}

RecoveryOptions _buildRecovery(
  DeadlineItem item,
  DisposableTimeSettings settings,
  DateTime now,
  int disposable,
  int daysLeft,
) {
  final shortfall = item.requiredMinutes - disposable;

  int? postponeDays;
  // 週の可処分が 0 のときは何日延ばしても埋まらない。無駄な 365 回転を避ける。
  if (settings.weeklyMinutes > 0) {
    final due = dateOnly(item.dueOn);
    for (var extra = 1; extra <= 365; extra += 1) {
      final candidate = DateTime(due.year, due.month, due.day + extra);
      if (disposableMinutesUntil(now, candidate, settings) >=
          item.requiredMinutes) {
        postponeDays = extra;
        break;
      }
    }
  }

  final spreadDays = daysLeft < 1 ? 1 : daysLeft;
  return RecoveryOptions(
    postponeDays: postponeDays,
    cutMinutes: shortfall,
    extraMinutesPerDay: (shortfall / spreadDays).ceil(),
  );
}

/// 行の集合から画面状態を組み立てる。
DeadlineWeightSnapshot buildDeadlineWeightSnapshot(
  List<Map<String, dynamic>> itemRows,
  Map<String, dynamic>? settingsRow,
  DateTime now,
) {
  final settings = DisposableTimeSettings.fromRow(settingsRow);
  final today = dateOnly(now);

  final active = <DeadlineWeightCard>[];
  final overdue = <DeadlineWeightCard>[];

  for (final row in itemRows) {
    final item = DeadlineItem.fromRow(row);
    // 完了したものは一覧から外す (残っているものだけを見せる)。
    if (item.isCompleted || item.title.trim().isEmpty) continue;
    final card = buildCard(item, settings, now);
    if (dateOnly(item.dueOn).isBefore(today)) {
      overdue.add(card);
    } else {
      active.add(card);
    }
  }

  // 期日の近い順。同じ期日なら不足の大きいものを上に。
  active.sort((a, b) {
    final byDue = a.item.dueOn.compareTo(b.item.dueOn);
    if (byDue != 0) return byDue;
    return a.slackMinutes.compareTo(b.slackMinutes);
  });
  // 過ぎたものは新しい順 (古い負債を上に積み上げて責めない)。
  overdue.sort((a, b) => b.item.dueOn.compareTo(a.item.dueOn));

  return DeadlineWeightSnapshot(
    active: active,
    overdue: overdue,
    settings: settings,
  );
}

/// 分を「18時間30分」「45分」「18時間」の形にする。
String formatMinutes(int minutes) {
  if (minutes <= 0) return '0分';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest分';
  if (rest == 0) return '$hours時間';
  return '$hours時間$rest分';
}

/// 残り日数の表記。今日を 1 日目として数える。
String formatDaysLeft(int daysLeft) {
  if (daysLeft > 1) return 'あと$daysLeft日';
  if (daysLeft == 1) return '今日まで';
  return '${1 - daysLeft}日超過';
}

/// 判定のラベル。責める言葉を使わない。
String verdictLabel(DeadlineVerdict verdict) => switch (verdict) {
      DeadlineVerdict.comfortable => '間に合う',
      DeadlineVerdict.tight => 'ギリギリ',
      DeadlineVerdict.short => '時間が足りない',
      DeadlineVerdict.overdue => '期日を過ぎた',
    };
