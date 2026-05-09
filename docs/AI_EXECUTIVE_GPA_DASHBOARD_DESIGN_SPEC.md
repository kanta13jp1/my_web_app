# AI 役員 GPA 評価ダッシュボード — 設計 spec

> **Win版#132 part 189 (2026-05-09)**: Issue [#1124](https://github.com/kanta13jp1/my_web_app/issues/1124) (10d stale / WBS P1) の architect / docs / UI design portion を Win Claude が ship.
> 実装 (= EF Deno + Flutter widget + migration) は Codex hand-off (期限 2026-05-23).

NotebookLM `27730002-fe8c-40ff-b2c3-431ab8f40a9a` の "What Is Your Agent's GPA?" 観点を踏まえ、AI 役員 / 自律タスク / Edge Function 経由 AI 呼び出しの実行結果を **Goal / Plan / Action / Consistency** の 4 軸で評価する dashboard を新設する。

## 1. 目的 (= why)

- **失敗原因の局所化**: 「最終回答だけでなく Goal / Plan / Action / Consistency の過程を評価」することで、AI 役員の失敗 root cause を 4 軸の 1 つに紐付ける
- **再実行の判断材料**: 低スコア軸に対する再実行案 / プロンプト修正案 / 承認待ち化案を表示
- **CEO 感維持**: AI 役員の出力を CEO (= user) が単純承認/却下するのではなく、4 軸スコアを見て改善方向を指示できる ([PHILOSOPHY-22] #1 #3)

## 2. スコープ (= what)

### 2.1 評価対象 (= 初期 3 経路)

| 経路 | 既存 EF/page | 評価データ source |
|------|-------------|------------------|
| AI 役員 chat | `app-hub` `executive.chat` | `executive_chat_logs` table |
| 緊急役員会議 | `app-hub` `executive.emergency_meeting` | `executive_meetings` table |
| AI Secretary | `app-hub` `secretary.run` | `secretary_actions` table |

### 2.2 評価軸 (= GPA 4 軸)

| 軸 | 定義 | スコア range | 失敗例 |
|----|------|------------|--------|
| **Goal** | 依頼の目的を満たしたか | 0.0-4.0 | user 質問と無関係な回答 |
| **Plan** | 計画が実行可能で過不足なし | 0.0-4.0 | step 飛ばし / 並列必要箇所が直列 |
| **Action** | tool / DB / Issue/WBS 操作が適切 | 0.0-4.0 | wrong tool / parameter ミス |
| **Consistency** | 論理破綻 / 事実矛盾 / 制約違反なし | 0.0-4.0 | 自己矛盾 / [REAL-DATA] 違反 |

**GPA**: 4 軸平均 (= 0.0-4.0 / 米国大学 GPA 形式)

### 2.3 改善案 type

低スコア (= < 2.5) 軸に対して 1+ 改善案を表示:

- **再実行**: 同 prompt を別 model / 別 EF で再実行
- **プロンプト修正**: system prompt の特定 section を edit (= diff highlight)
- **承認待ち化**: 自律実行を停止し、user 承認 step 挿入
- **scope 縮小**: 大きな Goal を atomic sub-task に分割 (= EPIC 化)

## 3. データモデル

### 3.1 新規 table: `agent_gpa_evaluations`

```sql
CREATE TABLE agent_gpa_evaluations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  source_type TEXT NOT NULL CHECK (source_type IN (
    'executive_chat', 'executive_meeting', 'secretary_action'
  )),
  source_id UUID NOT NULL, -- 元 log の id
  goal_score NUMERIC(3,1) NOT NULL CHECK (goal_score BETWEEN 0 AND 4),
  plan_score NUMERIC(3,1) NOT NULL CHECK (plan_score BETWEEN 0 AND 4),
  action_score NUMERIC(3,1) NOT NULL CHECK (action_score BETWEEN 0 AND 4),
  consistency_score NUMERIC(3,1) NOT NULL CHECK (consistency_score BETWEEN 0 AND 4),
  gpa NUMERIC(3,2) GENERATED ALWAYS AS (
    (goal_score + plan_score + action_score + consistency_score) / 4
  ) STORED,
  judge_model TEXT NOT NULL DEFAULT 'claude-sonnet-4-6',
  rationale_short TEXT, -- 1-2 sentence summary
  improvement_suggestions JSONB, -- [{type, axis, suggestion}, ...]
  evaluated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_agent_gpa_evaluations_user_created
  ON agent_gpa_evaluations(user_id, created_at DESC);
ALTER TABLE agent_gpa_evaluations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users read own gpa" ON agent_gpa_evaluations
  FOR SELECT USING (auth.uid() = user_id);
```

### 3.2 PII 取扱い ([AI-DEV-23] #5 / [VIBE-30])

- `rationale_short` は **GPA 評価理由 のみ** (= user prompt 本文 / 個人情報を直接保存しない)
- 元 prompt / response は既存 log table に存在 → `source_id` 参照のみ
- 30 日経過で `agent_gpa_evaluations` row TTL prune (= GHA cron)

## 4. EF action (= [EF-FIRST] / [EF-CAP-50] 維持)

新規 EF 作成せず、既存 `app-hub` に 2 action 追加:

### 4.1 `agent.evaluate_gpa`

```ts
// supabase/functions/app-hub/actions/agent/evaluate_gpa.ts
{
  action: "agent.evaluate_gpa",
  params: {
    source_type: "executive_chat" | "executive_meeting" | "secretary_action",
    source_id: string, // UUID
    judge_model?: string // default "claude-sonnet-4-6"
  }
}
// returns: { evaluation_id, gpa, scores, rationale_short, improvement_suggestions }
```

実装:
1. `source_id` から元 log 取得
2. Judge model に 4 軸評価プロンプト送信 (= rubric 明示 + few-shot 3 例)
3. 結果を `agent_gpa_evaluations` に insert
4. 改善案を rule-based 補助で生成 (= score < 2.5 の軸に対し template)

### 4.2 `agent.list_gpa_recent`

```ts
{
  action: "agent.list_gpa_recent",
  params: {
    limit?: number, // default 50, max 200
    source_type?: string, // filter
    min_gpa?: number, max_gpa?: number // filter range
  }
}
// returns: { evaluations: [...], total_count }
```

## 5. UI (= Flutter widget / [DESIGN.md] tokens)

### 5.1 新規 page: `AgentGpaDashboardPage`

```
lib/pages/agent_gpa_dashboard_page.dart
```

#### Layout (= mobile-first)

```
┌─ AppBar: AI 役員 GPA Dashboard ─────────────┐
│                                              │
│ ┌─ Filter chips ────────────────────────┐   │
│ │ [chat] [meeting] [secretary] [low GPA]│   │
│ └────────────────────────────────────────┘   │
│                                              │
│ ┌─ Evaluation list (ListView) ──────────┐   │
│ │ ┌─ Card ────────────────────────────┐ │   │
│ │ │ GPA: 3.4  [executive_chat]        │ │   │
│ │ │ Goal:3.5 Plan:3.0 Act:4.0 Cons:3.0│ │   │
│ │ │ "User の今月予算 sub-question を   │ │   │
│ │ │  Plan で漏らした"                  │ │   │
│ │ │ [再実行] [prompt修正] [詳細]      │ │   │
│ │ └────────────────────────────────────┘ │   │
│ │ ...                                     │   │
│ └────────────────────────────────────────┘   │
└──────────────────────────────────────────────┘
```

#### 4 軸 visualization

- 各軸を **Orange (high) → Indigo (low)** color gradient で表示 (= [DESIGN.md] dark theme)
- GPA < 2.5 の軸は **red highlight** + 改善案 button visible
- GPA 履歴は line chart (= 過去 30 日 / `fl_chart` package 利用)

### 5.2 既存 page integration

- `ExecutiveChatPage` 各メッセージ右下に **小さな GPA badge** (= clickable → 評価詳細 modal)
- `EmergencyMeetingPage` も同様
- `SecretaryActionPage` action card に GPA badge

## 6. 改善案 button 動作

| Button | 動作 |
|--------|------|
| **再実行** | `executive.chat` を同 prompt + 別 model で再実行 → 新 evaluation 生成 |
| **prompt修正** | system prompt diff editor modal → user 承認 → 保存 → 再実行 |
| **承認待ち化** | 該当 source の auto-execution flag を false → user 承認 step 挿入 |
| **詳細** | 評価 rationale + judge model raw output + 元 log link 表示 |

## 7. 受け入れ条件 (= Issue #1124 transcribe)

- [x] 直近の AI 役員実行を一覧で確認できる → §5.1
- [x] 各実行に Goal/Plan/Action/Consistency の評価と短い根拠が表示される → §3.1 + §5.1
- [x] 低スコア項目に対して、再実行・プロンプト修正・承認待ち化などの改善案が出る → §6
- [x] ユーザーの個人情報や秘匿データを評価ログへ過剰保存しない → §3.2
- [x] `flutter analyze` が通る → CI gate

## 8. Phase 分割 (= Codex hand-off scope)

| Phase | 対象 | 期限 | 担当 |
|-------|------|------|------|
| **Phase 1** | migration + RLS + EF action 2 個 | 2026-05-16 | Codex |
| **Phase 2** | `AgentGpaDashboardPage` (= 一覧 + filter + GPA card) | 2026-05-19 | Codex |
| **Phase 3** | 既存 page integration (= GPA badge × 3 page) | 2026-05-21 | Codex |
| **Phase 4** | 改善案 button 動作 + 履歴 line chart | 2026-05-23 | Codex |

各 Phase で独立 PR ship (= 4 PR / 各 1-2 commit)

## 9. PHILOSOPHY-22 alignment (= 7+/9 ✅)

- 主要実装: AI 役員失敗の局所化 + CEO 感維持 + 改善 loop 確立
- 該当原則:
  - #1 (CEO 感) — 改善案を user が選択する
  - #2 (mission/value) — AI ペルソナの value 維持
  - #3 (mentor) — 失敗を非難でなく改善案で支援
  - #5 (商品 = 価値) — AI 役員の価値増大
  - #6 (時間 = 資本) — 4 軸 × 3 経路で root cause 即特定 → debug 時間最小化
  - #7 (資産負債) — 評価 log 自体が改善 asset
  - #8 (KPI = 昨日の自分) — GPA 履歴で自己進捗測定
  - #9 (IPO) — AI 役員品質保証
- 整合性スコア: 8/9 ✅ ([PHILOSOPHY-22] gate 通過)

## 10. 関連

- 親 Issue: [#1124](https://github.com/kanta13jp1/my_web_app/issues/1124)
- 重複回避: #832 (品質ゲート全般) / #840 (E2E test) / #773 (PII guardrail)
- NotebookLM ref: `27730002-fe8c-40ff-b2c3-431ab8f40a9a` (= "What Is Your Agent's GPA?")

---

> **Spec ship**: Win版#132 part 189 (2026-05-09 JST). Codex hand-off (= Phase 1-4 / 期限 2026-05-23).
