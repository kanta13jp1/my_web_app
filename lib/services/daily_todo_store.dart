import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_todo.dart';

/// ローカルに読み込んだ「今日やること」の状態(タスク + 完遂ログ + 更新時刻)。
class DailyTodoSnapshot {
  final List<DailyTodoTask> tasks;
  final List<DailyTodoCompletionLogEntry> log;

  /// タスク一覧をこの端末が最後に更新した時刻(端末跨ぎ LWW 判定に使う)。
  final DateTime? updatedAt;

  const DailyTodoSnapshot({
    required this.tasks,
    required this.log,
    required this.updatedAt,
  });

  static const DailyTodoSnapshot empty = DailyTodoSnapshot(
    tasks: <DailyTodoTask>[],
    log: <DailyTodoCompletionLogEntry>[],
    updatedAt: null,
  );
}

/// ミラー取り込みの結果(マージ後の状態 + 変化有無)。
class DailyTodoMergeResult {
  final DailyTodoSnapshot snapshot;
  final bool changed;

  const DailyTodoMergeResult({required this.snapshot, required this.changed});
}

/// 「今日やること」をローカル(SharedPreferences)へ永続化するストア。
///
/// 端末跨ぎ同期は `asset_pref_mirror` の 1 pref_key(`daily_todo`)を使うため
/// マイグレーション不要。値の形は
/// `{ "tasks": [...], "log": [...], "updated_at": iso }`。
///
/// タスク一覧は端末間で最終更新時刻の新しい方を採用(LWW)。完遂ログは
/// 「日々こなした実績」という durable な記録なので和集合マージで消えないよう守る。
class DailyTodoStore {
  static const String prefsKey = 'daily_todo_v1';

  /// 完遂ログを保持する日数(古い日は間引く)。
  static const int logRetentionDays = 90;

  /// 完遂ログの最大件数(保険の上限)。
  static const int maxLogEntries = 500;

  /// 完了済みタスクを一覧に残す日数(未完了は日数に関わらず常に残す)。
  static const int completedTaskRetentionDays = 14;

  /// タスク一覧の最大件数(保険の上限)。
  static const int maxTasks = 300;

  const DailyTodoStore();

  Future<DailyTodoSnapshot> load({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    return _decode(store.getString(prefsKey));
  }

  /// タスク・ログ・更新時刻をまとめて保存する。
  Future<void> save({
    required List<DailyTodoTask> tasks,
    required List<DailyTodoCompletionLogEntry> log,
    required DateTime updatedAt,
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final prunedTasks = _pruneTasks(tasks, updatedAt);
    final prunedLog = _pruneLog(log, updatedAt);
    await store.setString(
      prefsKey,
      jsonEncode(_encode(prunedTasks, prunedLog, updatedAt)),
    );
  }

  /// ミラー upsert 用の jsonb 値(現在のローカル状態を丸ごと)。空なら null。
  Future<Map<String, dynamic>?> encodeMirror({SharedPreferences? prefs}) async {
    final snapshot = await load(prefs: prefs);
    if (snapshot.tasks.isEmpty && snapshot.log.isEmpty) {
      return null;
    }
    return _encode(snapshot.tasks, snapshot.log, snapshot.updatedAt);
  }

  /// 他端末由来のミラー値をローカルへマージする。
  ///
  /// - タスク一覧: リモートの updated_at がローカルより新しければリモートを採用(LWW)。
  /// - 完遂ログ: 常に和集合マージ(実績記録を消さない)。
  ///
  /// 変化があれば永続化し、マージ後スナップショットと変化有無を返す。
  Future<DailyTodoMergeResult> mergeRemote(
    Object? remoteValue, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final local = _decode(store.getString(prefsKey));
    if (remoteValue is! Map) {
      return DailyTodoMergeResult(snapshot: local, changed: false);
    }
    final remote = _decode(jsonEncode(remoteValue));

    // ログは和集合(mergeKey で重複排除)。
    final mergedLogByKey = <String, DailyTodoCompletionLogEntry>{};
    for (final entry in local.log) {
      mergedLogByKey[entry.mergeKey] = entry;
    }
    var logChanged = false;
    for (final entry in remote.log) {
      if (!mergedLogByKey.containsKey(entry.mergeKey)) {
        mergedLogByKey[entry.mergeKey] = entry;
        logChanged = true;
      }
    }

    // タスクは LWW。リモートが厳密に新しいときだけ採用する。
    final remoteTasksNewer = remote.updatedAt != null &&
        (local.updatedAt == null ||
            remote.updatedAt!.isAfter(local.updatedAt!));
    final adoptRemoteTasks = remoteTasksNewer && remote.tasks.isNotEmpty;
    final tasks = adoptRemoteTasks ? remote.tasks : local.tasks;
    final tasksChanged = adoptRemoteTasks;

    if (!logChanged && !tasksChanged) {
      return DailyTodoMergeResult(snapshot: local, changed: false);
    }

    final mergedLog = mergedLogByKey.values.toList()
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    // タスクを採用した場合はその updated_at を、そうでなければローカルを保つ。
    final updatedAt = adoptRemoteTasks ? remote.updatedAt : local.updatedAt;
    final merged = DailyTodoSnapshot(
      tasks: _pruneTasks(tasks, updatedAt ?? DateTime.now()),
      log: _pruneLog(mergedLog, updatedAt ?? DateTime.now()),
      updatedAt: updatedAt,
    );
    await store.setString(
      prefsKey,
      jsonEncode(_encode(merged.tasks, merged.log, merged.updatedAt)),
    );
    return DailyTodoMergeResult(snapshot: merged, changed: true);
  }

  Map<String, dynamic> _encode(
    List<DailyTodoTask> tasks,
    List<DailyTodoCompletionLogEntry> log,
    DateTime? updatedAt,
  ) {
    return <String, dynamic>{
      'tasks': tasks.map((task) => task.toJson()).toList(),
      'log': log.map((entry) => entry.toJson()).toList(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }

  DailyTodoSnapshot _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return DailyTodoSnapshot.empty;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return DailyTodoSnapshot.empty;
      }
      final tasks = <DailyTodoTask>[];
      final rawTasks = decoded['tasks'];
      if (rawTasks is List) {
        for (final item in rawTasks) {
          final task = DailyTodoTask.fromJson(item);
          if (task != null) {
            tasks.add(task);
          }
        }
      }
      final log = <DailyTodoCompletionLogEntry>[];
      final rawLog = decoded['log'];
      if (rawLog is List) {
        for (final item in rawLog) {
          final entry = DailyTodoCompletionLogEntry.fromJson(item);
          if (entry != null) {
            log.add(entry);
          }
        }
      }
      final updatedAt = DateTime.tryParse(
        decoded['updated_at']?.toString() ?? '',
      )?.toLocal();
      return DailyTodoSnapshot(tasks: tasks, log: log, updatedAt: updatedAt);
    } catch (_) {
      return DailyTodoSnapshot.empty;
    }
  }

  List<DailyTodoTask> _pruneTasks(List<DailyTodoTask> tasks, DateTime now) {
    final cutoff = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: completedTaskRetentionDays));
    final kept = <DailyTodoTask>[];
    for (final task in tasks) {
      if (!task.completed) {
        kept.add(task);
        continue;
      }
      final completedAt = task.completedAt;
      if (completedAt == null || !completedAt.isBefore(cutoff)) {
        kept.add(task);
      }
    }
    if (kept.length <= maxTasks) {
      return kept;
    }
    // 上限超過時は新しい予定日から残す。
    kept.sort((a, b) => b.plannedDate.compareTo(a.plannedDate));
    return kept.take(maxTasks).toList();
  }

  List<DailyTodoCompletionLogEntry> _pruneLog(
    List<DailyTodoCompletionLogEntry> log,
    DateTime now,
  ) {
    final cutoffKey = dailyTodoDateKey(
      DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: logRetentionDays)),
    );
    final kept = log
        .where((entry) => entry.dateKey.compareTo(cutoffKey) >= 0)
        .toList()
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    if (kept.length <= maxLogEntries) {
      return kept;
    }
    return kept.sublist(kept.length - maxLogEntries);
  }
}
