---
title: "Flutter ローカルストレージ完全ガイド — SharedPreferences・Hive・SQLite 使い分け"
tags: flutter,dart,個人開発,AI
published: true
---

# Flutter ローカルストレージ完全ガイド — SharedPreferences・Hive・SQLite 使い分け

Flutter アプリでデータをローカルに保存する方法は複数あります。用途に応じて最適なライブラリを選ぶことがパフォーマンスとコードのシンプルさに直結します。

## SharedPreferences — 設定値の保存

小さなキー・バリュー形式のデータに最適です。ユーザー設定・テーマ・ログイン状態などに使います。

```yaml
dependencies:
  shared_preferences: ^2.3.0
```

```dart
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _themeKey = 'theme_mode';
  static const _langKey = 'language';

  Future<void> saveTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme);
  }

  Future<String> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'system';
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
```

## Hive — 高速な NoSQL ストレージ

構造化データをオフラインで大量に扱う場合は Hive が最適です。TypeAdapter でタイプセーフに使えます。

```yaml
dependencies:
  hive: ^2.2.3
  hive_flutter: ^1.1.0
dev_dependencies:
  hive_generator: ^2.0.1
  build_runner: ^2.4.0
```

```dart
// モデル定義
@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late bool isDone;

  @HiveField(3)
  late DateTime createdAt;
}
```

```dart
// アダプター生成: dart run build_runner build

// 初期化
await Hive.initFlutter();
Hive.registerAdapter(TaskAdapter());
final box = await Hive.openBox<Task>('tasks');

// 操作
await box.put(task.id, task);
final allTasks = box.values.toList();
await box.delete(task.id);
```

### ValueListenableBuilder で UI 自動更新

```dart
ValueListenableBuilder<Box<Task>>(
  valueListenable: Hive.box<Task>('tasks').listenable(),
  builder: (context, box, _) {
    final tasks = box.values.toList();
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (_, i) => TaskTile(task: tasks[i]),
    );
  },
)
```

## SQLite (sqflite) — リレーショナルデータ

複雑なクエリや JOIN が必要な場合は sqflite を使います。

```yaml
dependencies:
  sqflite: ^2.3.3+1
  path: ^1.9.0
```

```dart
class DatabaseHelper {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'app.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            is_done INTEGER DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  static Future<void> insertTask(Map<String, dynamic> task) async {
    final db = await database;
    await db.insert('tasks', task, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getTasks() async {
    final db = await database;
    return db.query('tasks', orderBy: 'created_at DESC');
  }
}
```

## 選択基準まとめ

| ユースケース | 推奨 |
|---|---|
| アプリ設定・フラグ | SharedPreferences |
| オフラインキャッシュ・大量データ | Hive |
| 複雑なリレーション・フィルター | sqflite |
| 暗号化が必要 | Hive + hive_flutter AES / sqflite + sqlcipher |

## 自分株式会社での活用

自分株式会社アプリでは Hive を使ってオフライン日次ジャーナルを保存し、Supabase への同期タイミングを Riverpod で管理しています。ローカルファースト設計により、機内モードでも全機能が使えます。

---

個人開発で Flutter アプリを作っている方、どのストレージを使っていますか？ぜひコメントで教えてください。
