---
title: "Supabase Realtime × Flutter — ポーリングなしでリアルタイム UI を実装する"
tags: supabase,flutter,個人開発,postgresql
published: true
---

# Supabase Realtime × Flutter — ポーリングなしでリアルタイム UI を実装する

Supabase の Realtime 機能を使えば、WebSocket でデータベースの変更を即時受信できます。ポーリング不要。このプロジェクトで実装したパターンを全部公開します。

## ポーリング vs Realtime

```
ポーリング (5秒毎):
  Flutter → GET /api/data → Supabase → レスポンス → 表示
  → 5秒ごとにリクエスト → 無駄な API 消費
  → 変更が最大5秒遅延

Realtime (WebSocket):
  Flutter ←── WebSocket ──← Supabase (変更を即時 push)
  → 変更が 100ms 以内に届く
  → クライアントからのリクエスト不要
```

## 基本実装: テーブル変更をリッスン

```dart
// lib/services/realtime_service.dart
class RealtimeService {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;

  void subscribeToNotes({required void Function(List<Map<String, dynamic>>) onUpdate}) {
    _channel = _supabase
      .channel('public:notes')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,  // INSERT / UPDATE / DELETE
        schema: 'public',
        table: 'notes',
        callback: (payload) {
          // 変更を受信 → UI 更新
          onUpdate(payload.newRecord.isEmpty ? [] : [payload.newRecord]);
        },
      )
      .subscribe();
  }

  void unsubscribe() {
    _channel?.unsubscribe();
  }
}
```

## Flutter Widget との統合

```dart
class NotesRealtimePage extends StatefulWidget {
  @override
  State<NotesRealtimePage> createState() => _NotesRealtimePageState();
}

class _NotesRealtimePageState extends State<NotesRealtimePage> {
  final _service = RealtimeService();
  List<Map<String, dynamic>> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _service.subscribeToNotes(
      onUpdate: (records) {
        if (mounted) {
          setState(() {
            // 差分更新 (全件再取得よりも効率的)
            for (final record in records) {
              final index = _notes.indexWhere((n) => n['id'] == record['id']);
              if (index >= 0) {
                _notes[index] = record;
              } else {
                _notes.insert(0, record);
              }
            }
          });
        }
      },
    );
  }

  Future<void> _loadInitialData() async {
    final data = await Supabase.instance.client
      .from('notes')
      .select()
      .order('created_at', ascending: false)
      .limit(50);
    setState(() => _notes = List<Map<String, dynamic>>.from(data));
  }

  @override
  void dispose() {
    _service.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _notes.length,
      itemBuilder: (ctx, i) => ListTile(title: Text(_notes[i]['title'] ?? '')),
    );
  }
}
```

`initState` で初期データを取得してから Realtime を subscribe。`dispose` で必ず unsubscribe。

## RLS と Realtime の組み合わせ

Realtime はデフォルトで RLS ポリシーを適用します:

```sql
-- この RLS ポリシーがあれば、Realtime も自分のデータしか届かない
CREATE POLICY "users_select_own" ON notes
  FOR SELECT USING (auth.uid() = user_id);
```

```dart
// JWT 認証済みクライアントを使う → RLS が適用される
_supabase.channel('public:notes')
  .onPostgresChanges(/* ... */)
  .subscribe((status, [error]) {
    if (status == RealtimeSubscribeStatus.subscribed) {
      print('Realtime connected');
    }
  });
```

## Broadcast: ユーザー間リアルタイム通信

PostgreSQL テーブル変更だけでなく、クライアント間で任意のメッセージを送れる:

```dart
// 送信側
await _supabase
  .channel('room:${roomId}')
  .sendBroadcastMessage(
    event: 'cursor_move',
    payload: {'x': 0.5, 'y': 0.3, 'userId': userId},
  );

// 受信側
_supabase
  .channel('room:${roomId}')
  .onBroadcast(
    event: 'cursor_move',
    callback: (payload) {
      setState(() => _cursors[payload['userId']] = Offset(
        payload['x'] as double,
        payload['y'] as double,
      ));
    },
  )
  .subscribe();
```

## Presence: オンラインユーザー管理

```dart
// ユーザーが接続していることを通知
final channel = _supabase.channel('online_users');

channel
  .onPresenceSync(callback: (_) {
    final state = channel.presenceState();
    setState(() => _onlineCount = state.length);
  })
  .subscribe((_,__) async {
    await channel.track({'user_id': userId, 'online_at': DateTime.now().toIso8601String()});
  });
```

`track()` で在席情報を共有。`presenceState()` で全員のオンライン状態を取得。

## 本番での注意点

**1. チャンネル名のスコープ**  
`public:notes` のようなグローバルなチャンネルは全ユーザーの変更を受信する。RLS でフィルタするか、`user:${userId}:notes` のようなスコープ付きチャンネル名を使う。

**2. 接続管理**  
WebSocket 接続はアプリ全体で共有。同じチャンネルに複数 subscribe しないよう管理する。`dispose` での unsubscribe を忘れずに。

**3. Realtime の有効化**  
テーブルごとに Supabase ダッシュボードで Realtime を有効にする必要がある:

```sql
-- または migration で有効化
ALTER PUBLICATION supabase_realtime ADD TABLE notes;
```

## まとめ

Supabase Realtime + Flutter の組み合わせ:
1. `onPostgresChanges` でテーブル変更をリッスン
2. RLS が Realtime にも適用 → セキュリティはDB層で完結
3. `Broadcast` でクライアント間メッセージング
4. `Presence` でオンライン状態管理
5. `dispose` での unsubscribe を忘れない

ポーリングは捨てろ。Realtime を使えばコードも UX もシンプルになる。
