---
title: "AI がタスクを自動仕分け — 自分株式会社の WBS × AI アシスタント設計"
tags: productivity,AI,saas,個人開発
published: false
---

# AI がタスクを自動仕分け — 自分株式会社の WBS × AI アシスタント設計

## 「タスク管理ツールが増えすぎて管理できない」問題

Notion、Trello、Asana、Linear、Jira —— タスク管理ツールは腐るほどある。なのに「どれを使っても管理できない」という声は絶えない。

問題はツールではなく **「タスクの整理作業そのものがタスクになっている」** こと。入力・分類・優先度付け・進捗更新——これだけで1日 30分消える。

自分株式会社の WBS システムはこの問題を AI で解決する設計になっている。

---

## 自分株式会社 WBS の設計思想

### 6部署バランス優先

自分株式会社の経営は「6部署」で構成される:

| 部署 | カテゴリ | 例 |
|------|---------|-----|
| 人事 | business-hr | 採用・労務・自己研鑽 |
| 財務 | business-finance | P/L管理・投資家対応 |
| 法務 | business-legal | 登記・契約・コンプラ |
| マーケ | business-marketing | SEO・SNS・PR |
| 製品 | business-product | 機能開発・UX改善 |
| 営業 | business-sales | B2B商談・LTV改善 |

WBS タスクはこの6カテゴリに紐付けられ、**バランスが取れているかを可視化**できる。

### インスタンス別タスク分担

10インスタンス (VSCode版/Win版/PS版#1〜#6/WEB版/スマホ版) それぞれに担当タスクが割り当てられている。

```
instance: ps2
  → SEO記事50本計画 (business-marketing)
  → T-1 dispatch ルーティン

instance: ps4
  → 競合190社モニタリング
  → jp_strength スコアリング
```

AI が各インスタンスの実行コンテキストを把握し、「今何をすべきか」を5件リストアップする仕組み。

---

## AI アシスタントの役割

### 1. 優先タスク自動抽出

```
wbs.priority_for_instance(instance="ps2")
→ [
    { title: "商号・本店所在地の確定", priority: "high", deadline: "2026-06-15" },
    { title: "SEO記事作成 Phase2 #20", priority: "high", deadline: "2026-09-05" },
    ...
  ]
```

**rescue_score** というスコアで優先度を計算:

```
rescue_score = 
  (期限超過日数 × 40) + 
  (更新停滞日数 × 20) + 
  (priority_rank × 25) + 
  (進捗率 × 15)
```

放置されているタスク・期限が近いタスクが自動的に浮上する。

### 2. 進捗の自動記録

セッション開始時・終了時に `wbs.update_progress` を自動呼び出し。

```json
{
  "action": "wbs.update_progress",
  "id": "task-uuid",
  "progress": 75,
  "status": "in_progress",
  "session": "PS#2 S46: SEO Phase2 #18+#19 completed / commit abc123"
}
```

コミットハッシュ・何%完了・どのインスタンスが担当したかが全て記録される。

### 3. クロスインスタンス PR 自動生成

あるインスタンスが別インスタンスの担当タスクを引き受けるとき、自動で引継ぎドキュメントを生成。

---

## 実装: Supabase DB スキーマ

```sql
CREATE TABLE wbs_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  category TEXT NOT NULL,          -- business-hr, business-finance, etc.
  status TEXT DEFAULT 'pending',    -- pending, in_progress, completed, blocked
  progress INTEGER DEFAULT 0,       -- 0-100
  priority TEXT DEFAULT 'medium',   -- low, medium, high, critical
  instance TEXT,                    -- 担当インスタンス
  owner_instance TEXT,              -- オーナー (原則担当と同じ)
  end_date DATE,                    -- 期限
  recovery_plan TEXT DEFAULT '',    -- blocked 時の復旧計画
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE wbs_milestones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  target_date DATE,
  category TEXT,
  tasks UUID[]                      -- 関連タスク ID 配列
);
```

### RLS (Row Level Security)

一般ユーザーは自分のタスクのみ閲覧可。管理者 (service_role) は全件操作可。

```sql
-- ユーザーは自分のタスクのみ参照
CREATE POLICY "users can view own tasks"
  ON wbs_tasks FOR SELECT
  USING (auth.uid() = owner_id);

-- Service role は全件操作
CREATE POLICY "service role all access"
  ON wbs_tasks FOR ALL
  USING (auth.role() = 'service_role');
```

---

## AI アシスタントの実際の使い方

### セッション開始フロー

```
1. WBS で今日のトップ5タスクを取得
2. rescue_score 最上位のタスクを選択
3. status を in_progress に更新
4. 作業実施
5. 完了後に progress/status を更新 + session ログ記録
```

### 「詰まった」ときの AI サポート

タスクが blocked になったとき:

```
User: "登記の準備が詰まっている"
AI: → wbs.list_tasks(category="business-legal", status="blocked")
    → 司法書士との契約タスクが recovery_plan 空欄で stop
    → "recovery_plan に '司法書士紹介サービス経由で依頼' を記録しましょうか？"
```

AI が DB を直接参照して、**コンテキストを持った提案**ができる。

---

## Notion・Asana との違い

| 機能 | Notion | Asana | 自分株式会社 WBS |
|------|--------|-------|----------------|
| カスタマイズ性 | ◎ | ○ | △ (設計固定) |
| AI 優先度計算 | △ (AI blocks) | △ | ◎ (rescue_score) |
| 複数インスタンス分担 | ✗ | ✗ | ◎ |
| DB 直結 | ○ (限定) | ✗ | ◎ (Supabase) |
| 月額コスト | $16〜 | $10〜 | $0 (自作) |

Notion は柔軟だが AI との統合が弱い。自分株式会社 WBS は「ソロファウンダーが AI と協働する」という特定用途に最適化されている。

---

## まとめ

- AI タスク管理の核心は「入力・分類・優先度付けの自動化」
- rescue_score により、放置・期限超過タスクが自動浮上
- インスタンス別分担で、複数の AI エージェントが並行作業できる
- Supabase DB と直結することで、AI がリアルタイムにコンテキストを把握できる

タスク管理ツールを使いこなせないのは意志の問題ではなく、**ツールが AI との協働前提で設計されていない**から。自分株式会社の WBS はその前提から設計し直している。

---

## 関連記事

- [マルチAIワークフローの実際のコスト](./2026-07-25-multi-ai-workflow-real-costs.md)
- [Supabase Edge Functions × AI コスト内訳](./2026-08-22-supabase-edge-functions-ai-cost.md)
- [AI大学 230社ガイド](./2026-08-15-ai-university-200-providers-guide.md)

---

*自分株式会社 — 21社競合のベストを1つに統合するライフマネジメントアプリ*  
*本番: https://my-web-app-b67f4.web.app/*
