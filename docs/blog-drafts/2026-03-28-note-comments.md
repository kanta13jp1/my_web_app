---
title: "FlutterとSupabaseでNotion風ノートコメント機能を実装した話"
date: 2026-03-28
tags: [Flutter, Supabase, Dart, EdgeFunctions]
platforms: [Zenn, Qiita, dev.to]
published: false
---

# FlutterとSupabaseでNotion風ノートコメント機能を実装した話

## はじめに

自分株式会社（[https://my-web-app-b67f4.web.app/](https://my-web-app-b67f4.web.app/)）はFlutter Web + Supabaseで構築したAI統合ライフマネジメントアプリです。Notionの機能ギャップを埋めるべく、今回「コメント機能」を実装しました。

Notionではページに対してコメントを残す機能が標準搭載されています。自分のノートに「後で確認」「ここ重要」「アイデアメモ」といった付箋代わりのコメントを追加できるあの機能です。

## 実装内容

### 1. DBスキーマ（マイグレーション）

```sql
CREATE TABLE IF NOT EXISTS note_comments (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id    bigint NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content    text NOT NULL CHECK (length(trim(content)) > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE note_comments ENABLE ROW LEVEL SECURITY;

-- RLS: ユーザーは自分のコメントのみ操作可能
CREATE POLICY "Users can view own note comments"
  ON note_comments FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own note comments"
  ON note_comments FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own note comments"
  ON note_comments FOR UPDATE
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own note comments"
  ON note_comments FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS note_comments_note_id_created_at_idx
  ON note_comments (note_id, created_at ASC);
```

ポイントは **RLS（Row Level Security）**。SupabaseのRLSを使うと、SQLレイヤーで「自分のデータしか見えない」を強制できます。フロントエンドでのフィルタリングに頼らず、DBレベルで保護されるのが安心です。

### 2. Supabase Edge Function (Deno)

```typescript
// note-comments/index.ts
serve(async (req) => {
  const userId = getUserIdFromJwt(req);
  if (!userId) return json({ error: "unauthorized" }, 401);

  if (req.method === "GET") {
    // note_id でコメント一覧取得（ノート所有確認付き）
    const { data } = await client
      .from("note_comments")
      .select("id, content, created_at, updated_at")
      .eq("note_id", noteId)
      .eq("user_id", userId)
      .order("created_at", { ascending: true });
    return json({ comments: data ?? [] });
  }

  if (req.method === "POST") {
    // コメント追加（内容2000字制限）
    const { data } = await client
      .from("note_comments")
      .insert({ note_id: noteId, user_id: userId, content })
      .select("id, content, created_at, updated_at")
      .single();
    return json({ ok: true, comment: data });
  }

  if (req.method === "DELETE") {
    // コメント削除（自分のコメントのみ）
    await client.from("note_comments")
      .delete()
      .eq("id", commentId)
      .eq("user_id", userId);
    return json({ ok: true });
  }
});
```

Edge Functionではサービスロールキーを使いつつ、JWTからuser_idを取り出してすべての操作に `.eq("user_id", userId)` を付与しています。二重の安全策です。

### 3. Flutter UI

```dart
// NoteEditorPage の AppBar に追加
if (_currentNoteId != null)
  Stack(
    alignment: Alignment.topRight,
    children: [
      IconButton(
        icon: const Icon(Icons.comment_outlined),
        onPressed: _showComments,
        tooltip: 'コメント',
      ),
      if (_commentCount > 0)
        Positioned(
          top: 6, right: 6,
          child: Container(
            // バッジ表示
            child: Text('$_commentCount', ...),
          ),
        ),
    ],
  ),
```

コメント数をバッジ表示することで、ノートにコメントがあることを一目で把握できます。

BottomSheetでコメント一覧と入力フィールドを表示し、DraggableScrollableSheetで高さ調整可能にしています。

## 詰まったポイント

### `withOpacity` → `withValues` への移行

Flutter 3.x では `withOpacity` が deprecated になっており、`withValues(alpha: x)` を使う必要があります。flutter analyze で検出して修正しました。

```dart
// ❌ deprecated
color: Colors.indigo.withOpacity(0.05),

// ✅ 正しい
color: Colors.indigo.withValues(alpha: 0.05),
```

### unawaited の活用

バックグラウンドでコメント数をロードする際、`unawaited()` を使って非同期処理を明示的に「待たない」ことを示します。

```dart
// dart:async の unawaited で fire-and-forget
unawaited(_loadCommentCount());
```

## まとめ

- PostgreSQL RLS + Supabase で安全なマルチテナントデータ管理
- Edge Function でノート所有権チェックを二重実装
- Flutter の `DraggableScrollableSheet` でスムーズなBottomSheet UI
- `flutter analyze 0件` を維持しながら実装完了

次は **チームワークスペース**（リアルタイム共同編集）の基盤整備に取り組みます。

URL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #Dart
