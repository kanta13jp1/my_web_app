import 'package:shared_preferences/shared_preferences.dart';

class MemoryDrillPack {
  const MemoryDrillPack({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.items,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final List<String> items;
}

class MemoryDrillStats {
  const MemoryDrillStats({
    required this.completedPackIdsToday,
    required this.completedTodayCount,
    required this.currentStreak,
    required this.lastCompletedDateKey,
  });

  factory MemoryDrillStats.empty() {
    return const MemoryDrillStats(
      completedPackIdsToday: <String>{},
      completedTodayCount: 0,
      currentStreak: 0,
      lastCompletedDateKey: null,
    );
  }

  final Set<String> completedPackIdsToday;
  final int completedTodayCount;
  final int currentStreak;
  final String? lastCompletedDateKey;

  bool isCompletedToday(String packId) =>
      completedPackIdsToday.contains(packId);
}

class MemoryDrillService {
  static const List<MemoryDrillPack> builtinPacks = <MemoryDrillPack>[
    MemoryDrillPack(
      id: 'countries_10',
      title: '世界の国 10個',
      description: '毎日同じ10個を声に出して列挙し、地理の基本語彙を固定します。',
      category: '地理',
      items: <String>[
        '日本',
        'アメリカ',
        'イギリス',
        'フランス',
        'ドイツ',
        'ブラジル',
        'インド',
        '中国',
        'エジプト',
        'オーストラリア',
      ],
    ),
    MemoryDrillPack(
      id: 'beatles_songs_10',
      title: 'ビートルズの楽曲 10個',
      description: '有名曲を順番に思い出しながら、音楽知識の反射速度を上げます。',
      category: '音楽',
      items: <String>[
        'Let It Be',
        'Hey Jude',
        'Yesterday',
        'Help!',
        'Something',
        'Come Together',
        'Penny Lane',
        'Eleanor Rigby',
        'In My Life',
        'All You Need Is Love',
      ],
    ),
    MemoryDrillPack(
      id: 'elements_10',
      title: '元素 10個',
      description: '理科の基礎語彙を短時間で反復するためのセットです。',
      category: '理科',
      items: <String>[
        '水素',
        'ヘリウム',
        '炭素',
        '窒素',
        '酸素',
        'ナトリウム',
        'マグネシウム',
        'アルミニウム',
        '鉄',
        '銅',
      ],
    ),
    MemoryDrillPack(
      id: 'warlords_10',
      title: '戦国武将 10人',
      description: '歴史の定番人物を毎日列挙して、名前の想起を速くします。',
      category: '歴史',
      items: <String>[
        '織田信長',
        '豊臣秀吉',
        '徳川家康',
        '武田信玄',
        '上杉謙信',
        '毛利元就',
        '今川義元',
        '明智光秀',
        '石田三成',
        '真田幸村',
      ],
    ),
  ];

  static const String _completedTodayDateKey =
      'memory_drill_completed_today_date';
  static const String _completedTodayPackIdsKey =
      'memory_drill_completed_today_pack_ids';
  static const String _lastCompletedDateKey =
      'memory_drill_last_completed_date';
  static const String _streakKey = 'memory_drill_streak';

  Future<MemoryDrillStats> loadStats({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dayKey(now ?? DateTime.now());
    final storedTodayKey = prefs.getString(_completedTodayDateKey);
    final completedPackIds = storedTodayKey == todayKey
        ? prefs.getStringList(_completedTodayPackIdsKey) ?? <String>[]
        : <String>[];

    return MemoryDrillStats(
      completedPackIdsToday: completedPackIds.toSet(),
      completedTodayCount: completedPackIds.length,
      currentStreak: prefs.getInt(_streakKey) ?? 0,
      lastCompletedDateKey: prefs.getString(_lastCompletedDateKey),
    );
  }

  Future<MemoryDrillStats> markCompleted(
    String packId, {
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = now ?? DateTime.now();
    final todayKey = _dayKey(current);
    final storedTodayKey = prefs.getString(_completedTodayDateKey);
    final existingTodayIds = storedTodayKey == todayKey
        ? List<String>.from(
            prefs.getStringList(_completedTodayPackIdsKey) ?? <String>[],
          )
        : <String>[];

    if (!existingTodayIds.contains(packId)) {
      existingTodayIds.add(packId);
    }

    var streak = prefs.getInt(_streakKey) ?? 0;
    final lastCompletedDateKey = prefs.getString(_lastCompletedDateKey);

    if (lastCompletedDateKey != todayKey && existingTodayIds.length == 1) {
      if (_isPreviousDay(lastCompletedDateKey, todayKey)) {
        streak += 1;
      } else {
        streak = 1;
      }
    } else if (streak == 0) {
      streak = 1;
    }

    await prefs.setString(_completedTodayDateKey, todayKey);
    await prefs.setStringList(_completedTodayPackIdsKey, existingTodayIds);
    await prefs.setString(_lastCompletedDateKey, todayKey);
    await prefs.setInt(_streakKey, streak);

    return MemoryDrillStats(
      completedPackIdsToday: existingTodayIds.toSet(),
      completedTodayCount: existingTodayIds.length,
      currentStreak: streak,
      lastCompletedDateKey: todayKey,
    );
  }

  String _dayKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  bool _isPreviousDay(String? previousDayKey, String currentDayKey) {
    if (previousDayKey == null) {
      return false;
    }
    final previous = DateTime.tryParse(previousDayKey);
    final current = DateTime.tryParse(currentDayKey);
    if (previous == null || current == null) {
      return false;
    }
    return current.difference(previous).inDays == 1;
  }
}
