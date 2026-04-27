---
title: "WBS × AI: タスク管理をAIアシスタントで自動化する設計パターン"
tags: AI,個人開発,postgresql,buildinpublic
published: true
---

# WBS × AI: タスク管理をAIアシスタントで自動化する設計パターン

12インスタンスのAIフリートを並行運用していると、タスク管理が本当に難しくなります。人間が手動でWBSを更新していたら、すぐにボトルネックになる。そこで**WBSそのものをAIが読み書きする設計**に変えました。

## 問題: 12インスタンス並行開発のタスク追跡

```
Claude Code × 10 (VSCode/Win/PS#1-6/Web/Mobile)
+ Codex CLI × 2
= 12インスタンスが同時に進捗を更新
```

手動更新では:
- インスタンスが完了報告を忘れる
- タスク競合 (2インスタンスが同じタスクを処理)
- 進捗の実態が不明になる

## アーキテクチャ: WBS-as-a-Service

```
各インスタンス
  → tools-hub EF (wbs.priority_for_instance / wbs.update_progress)
  → wbs_tasks テーブル (PostgreSQL)
  → GHA wbs-staleness-audit cron (24h周期)
  → MEMORY.md + NotebookLM Master Brain
```

## PostgreSQL スキーマ設計

```sql
CREATE TABLE wbs_tasks (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,
  instance    TEXT NOT NULL,  -- 'vscode' | 'win' | 'ps1' ... 'ps6' | 'web' | 'mobile'
  status      TEXT NOT NULL DEFAULT 'pending',
  priority    INT  NOT NULL DEFAULT 5,
  depends_on  UUID[] DEFAULT '{}',
  updated_at  TIMESTAMPTZ DEFAULT now()
);

-- インスタンス別 TOP5 タスク
CREATE OR REPLACE FUNCTION wbs_priority_for_instance(p_instance TEXT)
RETURNS SETOF wbs_tasks AS $$
  SELECT * FROM wbs_tasks
  WHERE instance = p_instance
    AND status = 'pending'
  ORDER BY priority DESC, updated_at ASC
  LIMIT 5;
$$ LANGUAGE sql;
```

## Edge Function: tools-hub の WBS アクション

```typescript
// supabase/functions/tools-hub/index.ts
case 'wbs.priority_for_instance': {
  const { instance } = body.params;
  const { data } = await supabase
    .rpc('wbs_priority_for_instance', { p_instance: instance });
  return json({ tasks: data });
}

case 'wbs.update_progress': {
  const { task_id, status, notes } = body.params;
  await supabase
    .from('wbs_tasks')
    .update({ status, updated_at: new Date().toISOString() })
    .eq('id', task_id);
  return json({ ok: true });
}
```

## インスタンスへの強制注入: inject-rules.txt

各インスタンスのセッション開始時、`[WBS-SYNC]` ルールが `UserPromptSubmit` hook 経由で注入されます:

```text
[WBS-SYNC]: セッション開始時に wbs.priority_for_instance を呼び出し、
担当タスクを確認すること。完了タスクは即時 wbs.update_progress で更新。
スキップは GHA wbs-staleness-audit で自動検出される。
```

## GHA staleness-audit: 24時間後に警告

```yaml
# .github/workflows/wbs-staleness-audit.yml
on:
  schedule:
    - cron: '0 */24 * * *'  # 24時間毎

jobs:
  audit:
    steps:
      - name: Check stale in_progress tasks
        run: |
          STALE=$(psql "$DATABASE_URL" -t -c "
            SELECT title, instance, updated_at
            FROM wbs_tasks
            WHERE status = 'in_progress'
              AND updated_at < NOW() - INTERVAL '24 hours'
          ")
          if [ -n "$STALE" ]; then
            gh issue create \
              --title "WBS staleness detected" \
              --body "$STALE"
          fi
```

## 実際の運用成果

導入前: インスタンスが同じ migration ファイルを重複作成 → merge conflict  
導入後: `depends_on` フィールドで依存関係を宣言 → 自動的に直列化

- **タスク重複率**: ~40% → **3%**
- **WBS更新遅延**: 平均4時間 → **即時** (セッション終了時に自動更新)
- **人間の手動管理**: 週2時間 → **週15分** (例外対応のみ)

## 設計上の教訓

**1. AIは「状態を宣言」させる、「状態を推測」させない**  
セッション開始時に必ず `wbs.priority_for_instance` を呼ばせることで、インスタンスが自分のタスクを「知っている」状態を作る。

**2. 監査は人間がやらずGHAにやらせる**  
staleness-audit で放置タスクを自動検出 → GitHub Issue化。人間は例外だけ判断する。

**3. `instance` カラムは柔軟に設計する**  
`UPDATE wbs_tasks SET instance='codex1' WHERE instance='all'` は UNIQUE 制約違反になる。`all` ではなく `null` = 未割当、という設計が堅牢。

## まとめ

WBSをAIが読み書きする仕組みにすると、12インスタンス並行運用でもタスクが混線しなくなります。鍵は「強制注入 (hook)」と「自動監査 (GHA)」の組み合わせ。AIに「自分で確認しろ」と命令するより、「確認しないと怒られる仕組み」を作る方が確実です。
