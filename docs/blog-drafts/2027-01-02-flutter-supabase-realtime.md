---
title: "Flutter Web + Supabase リアルタイム — チャンネル購読から楽観的更新まで"
tags: supabase,AI,個人開発,postgresql
published: true
---

# Flutter Web + Supabase リアルタイム — チャンネル購読から楽観的更新まで

Supabase のリアルタイム機能は「簡単に始められるが、本番でハマりやすい」実装の代表格です。Flutter Web で使ってきた中で学んだ設計パターンをまとめます。

## 基本: チャンネル購読

```dart
// lib/services/realtime_service.dart
class RealtimeService {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;

  void subscribeMemos(String userId, void Function(List<Memo>) onUpdate) {
    _channel = _supabase
      .channel('memos:$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'memos',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          // payload.newRecord / payload.oldRecord
          onUpdate(_buildMemoList(payload));
        },
      )
      .subscribe();
  }

  void dispose() {
    _channel?.unsubscribe();
    _supabase.removeAllChannels();
  }
}
```

**重要**: `dispose()` を忘れると WebSocket 接続がリークする。`StatefulWidget` の `dispose()` で必ず呼ぶ。

## 楽観的更新パターン

リアルタイム受信を待たずにUIを即時更新し、失敗時にロールバックする:

```dart
Future<void> toggleReaction(String memoId, String reactionType) async {
  // 1. 楽観的更新 (即時)
  setState(() {
    _reactions[memoId] = [...?_reactions[memoId], reactionType];
  });

  try {
    // 2. サーバー送信
    await _supabase.functions.invoke('core-hub', body: {
      'action': 'memo.react.toggle',
      'params': {'memo_id': memoId, 'reaction_type': reactionType},
    });
    // 3. リアルタイムで確定値が届く → setState 再度
  } catch (e) {
    // 4. 失敗時ロールバック
    setState(() {
      _reactions[memoId]?.remove(reactionType);
    });
  }
}
```

## 接続状態の監視

```dart
_channel = _supabase.channel('memos:$userId')
  ..onPostgresChanges(/* ... */)
  ..onSubscribe((status, error) {
    if (status == RealtimeSubscribeStatus.subscribed) {
      debugPrint('realtime: connected');
    } else if (status == RealtimeSubscribeStatus.timedOut) {
      // Flutter Web では 60s timeout が起きやすい
      _reconnect();
    }
  })
  ..subscribe();
```

Flutter Web の場合、タブがバックグラウンドに移ると WebSocket が切断されやすい。`onSubscribe` で timeout を検知して再接続する。

## Row Level Security (RLS) との連携

```sql
-- memos テーブルの RLS ポリシー
CREATE POLICY "users can see own memos"
ON memos FOR SELECT
USING (auth.uid() = user_id);
```

RLS ポリシーがあれば、リアルタイムも同じポリシーが適用される。他ユーザーのメモはチャンネルに届かない。

## パフォーマンス: バッファリング

高頻度更新 (typing indicator など) ではバッファリングが重要:

```dart
Timer? _debounce;

void onTyping(String text) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 300), () async {
    await _supabase.from('typing_status').upsert({
      'user_id': userId,
      'is_typing': text.isNotEmpty,
    });
  });
}
```

300ms debounce で DB 書き込みを間引く。

## よくある落とし穴

| 問題 | 原因 | 対策 |
|---|---|---|
| チャンネルが重複購読される | `subscribe()` を複数回呼んだ | `dispose()` 後に再 subscribe |
| RLS で届かない | anon key + RLS ミス | auth state 確認 + policy 確認 |
| Flutter Web で切断 | タブ非アクティブ | timeout callback で再接続 |
| memo_reactions 404 | EF が stale | core-hub に統合済みか確認 |

## まとめ

Flutter + Supabase のリアルタイムは接続管理が鍵です。チャンネルの購読/解除を `StatefulWidget` のライフサイクルに合わせる、楽観的更新でUXを滑らかにする、RLSでセキュリティを確保する — この3つを押さえれば本番でも安定して動きます。
