---
title: "Flutter × Supabase で目標管理 + ブックマーク同期を1日で実装した話"
tags: Flutter,Supabase,個人開発,buildinpublic,Dart
published: true
---

# ブログ下書き 2026-04-04 — 2026-04-04-goal-tracker-bookmark-sync

## タイトル案
1. Flutter × Supabase で目標管理＋ブックマーク同期アプリを1日で実装した話
2. Notion/Pocket競合機能をゼロから作る — EdgeFunction Firstアーキテクチャの実践
3. async/awaitとBuildContextの罠を踏み抜いた日: Flutter 3.33対応記録

## 投稿先候補
- [x] Zenn
- [ ] Qiita
- [ ] note
- [ ] はてなブログ

## 本文下書き

### はじめに

「自分株式会社」というサービスを開発している。コンセプトはシンプルで、
NotionやPocketやMoneyForwardなど21の競合SaaSの機能を一つのFlutter Webアプリに統合すること。

今日実装したのは以下の2機能:

1. **目標管理ページ** (Notion / Liven競合) — 短期・中期・長期の目標をマイルストーン付きで管理
2. **ブックマーク同期ページ** (Pocket / Instapaper競合) — URL保存・タグ管理・既読管理

### 実装方法

#### アーキテクチャ: Edge Function First

複雑なロジックはすべてSupabase Edge Function (Deno) 側に置き、
Flutterはシンプルなデータ表示・操作UIに徹する。

```dart
// Flutter側はこれだけ
final res = await _supabase.functions.invoke(
  'goal-tracker',
  body: {'action': 'create', 'title': title, ...},
);
```

Edge Function側でDBアクセス・バリデーション・RLS制御を行う。
フロント→バックのインターフェースは `action` フィールドで振り分けるシンプルなAPIデザイン。

#### DBスキーマ (bookmarks テーブル)

```sql
CREATE TABLE bookmarks (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  url text NOT NULL,
  title text NOT NULL DEFAULT '',
  tags text[] DEFAULT '{}',
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);
-- GINインデックスでタグ検索を高速化
CREATE INDEX idx_bookmarks_tags ON bookmarks USING GIN (tags);
```

### 詰まったポイント

#### 1. Flutter 3.33の `use_build_context_synchronously` が激しくなった

以前は `if (!context.mounted) return;` の後で `context` を使えばOKだったが、
Flutter 3.33から "guarded by an unrelated 'mounted' check" として弾かれるようになった。

**Before (エラー)**:
```dart
await _supabase.functions.invoke(...);
if (!context.mounted) return;
Navigator.of(context).pop();  // NG
```

**After (正解)**: async前にcontextの参照を取得しておく

```dart
final navigator = Navigator.of(context);   // ← awaitの前に取得
final messenger = ScaffoldMessenger.of(context);
await _supabase.functions.invoke(...);
if (!mounted) return;
navigator.pop();   // ← contextを使わない
messenger.showSnackBar(...);
```

#### 2. `dart:math` に `tanh` がない

音声マスタリング処理でソフトクリッピングに `math.tanh` を使おうとしたら
Dartの `dart:math` にはそもそも `tanh` が存在しない。

数学定義 `tanh(x) = (e^2x - 1) / (e^2x + 1)` を使って手動実装:

```dart
final e2 = math.exp(2 * arg);
final limited = (e2 - 1) / (e2 + 1);
```

#### 3. Edge Functionのbody重複宣言バグ

```typescript
// バグ: 同スコープで const body を2回宣言
const body = req.method === "POST" ? await req.json().catch(...) : {};
// ...
const body = await req.json().catch(...);  // ← Deno lintエラー
```

POSTのbodyは1度しかパースできない (ストリームは消費される) ので、
最初の宣言でまとめて処理するのが正解。

### まとめ

Flutter × SupabaseのEdge Function Firstアーキテクチャは、
バックエンドとフロントエンドの責務を明確に分けられて非常に開発体験が良い。

特にDeno Edge Functionは型安全なTypeScriptで書けて、
RLSとの組み合わせでセキュリティも担保しやすい。

今回作った目標管理・ブックマーク機能も含め、
現在21競合の機能を統合中。無料で使えるので試してみてください:

https://my-web-app-b67f4.web.app/

#FlutterWeb #Supabase #buildinpublic #Dart #EdgeFunctions
