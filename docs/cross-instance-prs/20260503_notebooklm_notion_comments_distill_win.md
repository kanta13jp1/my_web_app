# Cross-Instance PR: NotebookLM「Building Notion-Style Comments with Flutter and Supabase」蒸留

**作成**: VSCode版 S25 / 2026-05-03
**FROM**: VSCode版 (notebooklm list → 未適用 notebook 検出)
**TO**: Win版 (docs + 設計 doc + migration schema 担当)
**優先度**: MEDIUM
**期限**: 2026-05-17 (2 週間)
**親軸**: NotebookLM 蒸留 routine (SECOND_BRAIN 軸) + Flutter コメント機能

---

## 1. 背景

`notebooklm list` 実行結果 (2026-05-03):
- **「Building Notion-Style Comments with Flutter and Supabase」** notebook 存在
- Notebook ID: `9b2e686f-1189-4187-a5bf-...`
- Owner: Shared
- VSCode版で未適用確認

本 notebook は **Flutter Web + Supabase を使ったコメント機能の実装パターン** を扱っており、
自分株式会社の「ユーザー間コラボレーション」「日記・ノート・タスクへのコメント」機能に直接適用可能。

## 2. Win版への依頼内容

### 2.1 Notebook 内容の蒸留

```bash
notebooklm use <notebook-id>
notebooklm ask "Notion スタイルコメントの主要実装パターンを要約して"
notebooklm ask "Supabase Realtime を使ったコメント同期の最適実装は"
notebooklm ask "Flutter Widget 構成 (CommentThread / CommentBubble) の推奨設計"
```

### 2.2 設計 doc 作成

`docs/COMMENT_SYSTEM_DESIGN.md` 新規:
- コメントスレッド / リプライ tree 構造
- Supabase テーブル設計 (`comments` テーブル / `comment_reactions` / RLS)
- Flutter Widget 構成案
- Realtime subscription パターン

### 2.3 Migration スキーマ

`supabase/migrations/YYYYMMDD_create_comments.sql` 作成:
```sql
CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  target_type TEXT NOT NULL, -- 'note' | 'task' | 'diary' | 'goal'
  target_id UUID NOT NULL,
  parent_id UUID REFERENCES comments(id), -- NULL = top-level
  content TEXT NOT NULL CHECK (length(content) <= 2000),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
-- RLS: INSERT/SELECT 自分のみ or target の閲覧権限者
```

### 2.4 VSCode向け cross-instance-pr 起票

設計 doc + Migration 完成後、VSCode向けに:
- `CommentThread` widget
- `CommentInput` widget
- Notes/Task 画面への統合
のための cross-instance-pr を起票

## 3. 受入基準

- [ ] `docs/COMMENT_SYSTEM_DESIGN.md` 新規 (Notion-style comment 設計)
- [ ] `supabase/migrations/YYYYMMDD_create_comments.sql` 新規 (RLS 付き)
- [ ] VSCode向け cross-instance-pr 起票 (Widget 実装依頼)
- [ ] cross-instance-pr 完了時 `done/` 移動

## 4. 連携

- NotebookLM notebook: `9b2e686f-1189-4187-a5bf-...` (Building Notion-Style Comments)
- 関連 Issue: Notion 競合機能 (コメント/コラボレーション)
- 後 phase: VSCode版でのコメント Widget 実装

---

*VSCode版 S25 / 2026-05-03 起票 / NotebookLM 蒸留 → Win 設計 doc / VSCode → Win lane*
