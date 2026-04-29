---
title: "Flutter Local Storage Guide — SharedPreferences vs Hive vs SQLite"
tags: flutter,dart,webdev,indiedev
published: true
---

# Flutter Local Storage Guide — SharedPreferences vs Hive vs SQLite

Choosing the right local storage solution in Flutter directly impacts performance and code simplicity. Here's a practical breakdown of the three main options.

## SharedPreferences — Key-Value Settings

Best for small primitives: user settings, theme, login state.

```yaml
dependencies:
  shared_preferences: ^2.3.0
```

```dart
class SettingsService {
  static const _themeKey = 'theme_mode';

  Future<void> saveTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme);
  }

  Future<String> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'system';
  }
}
```

## Hive — Fast NoSQL Storage

Perfect for structured data, offline caching, and large datasets. TypeAdapters keep it type-safe.

```yaml
dependencies:
  hive: ^2.2.3
  hive_flutter: ^1.1.0
dev_dependencies:
  hive_generator: ^2.0.1
  build_runner: ^2.4.0
```

```dart
@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0) late String id;
  @HiveField(1) late String title;
  @HiveField(2) late bool isDone;
  @HiveField(3) late DateTime createdAt;
}
```

```dart
// Generate adapter: dart run build_runner build

await Hive.initFlutter();
Hive.registerAdapter(TaskAdapter());
final box = await Hive.openBox<Task>('tasks');

// CRUD
await box.put(task.id, task);
final all = box.values.toList();
await box.delete(task.id);
```

### Reactive UI with ValueListenableBuilder

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

## SQLite (sqflite) — Relational Data

Use when you need complex queries, JOINs, or aggregations.

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
      onCreate: (db, _) async {
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

  static Future<void> insert(Map<String, dynamic> task) async {
    final db = await database;
    await db.insert('tasks', task, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getAll() async {
    final db = await database;
    return db.query('tasks', orderBy: 'created_at DESC');
  }
}
```

## Decision Matrix

| Use case | Best choice |
|---|---|
| App settings / flags | SharedPreferences |
| Offline cache / large datasets | Hive |
| Complex relations / filtering | sqflite |
| Encryption required | Hive AES / sqlcipher |

## How I Use This in My App

In my life management app (自分株式会社), I use Hive for offline journal storage and manage Supabase sync timing with Riverpod. Local-first design means the app is fully functional even on airplane mode.

---

Building something offline-capable in Flutter? Drop a comment — curious what storage stack you're using.
