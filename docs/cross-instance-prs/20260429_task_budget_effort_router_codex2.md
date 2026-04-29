# Cross-Instance PR: task_budget + effort_router (Cost Control & Effort Tuning)

**作成**: Win版#132 part 74 / 2026-04-29
**FROM**: Win版 (PLATFORM_EVOLUTION 軸起案者 / FLEET_SCALING_ROADMAP 起案者)
**TO**: Codex#2 (EF / Deno / GHA 補助 territory)
**優先度**: HIGH (Phase 1 ブロッカー 2 件 / fleet 拡大の前提条件)
**期限**: 2026-05-13 (2 週間)
**親軸**: docs/PLATFORM_EVOLUTION_PRINCIPLES.md 原則 #6 + #7
**依存**: docs/FLEET_SCALING_ROADMAP.md (= Phase 1 = 12→18 fleet の前提)

---

## 背景

Win版#132 part 73 で `docs/FLEET_SCALING_ROADMAP.md` を確立 → 4 Phase milestone (12→18→24→50→100). Phase 1 (= 6 ヶ月以内 / 12→18 fleet) のブロッカー 5 件中 **2 件は同 territory (Codex#2 / EF)** で **1 PR 同時実装が効率的**:

- **PLATFORM #6** = `task_budget` 実装
- **PLATFORM #7** = `effort_router` 実装

両者は **cost 制御 ペア** (= budget で上限 / effort で配分). 1 PR にまとめることで:
- 設計判断の一貫性確保 (= 同じ EF アーキテクチャに統合)
- review 時間短縮 (= 関連変更を 1 度に把握)
- 実装の重複回避 (= shared util 共通化)

## Win版 routing 判断 (5 質問 + WORKDIR-ISOLATION)

| Q | 答え | 補足 |
| --- | --- | --- |
| Q1 設計判断 / trade-off? | YES | budget 設定単位 (= EF / GHA / instance / 月単位) / effort 自動選択基準 |
| Q2 cross-instance 調整? | △ | quota-monitor.yml と統合方法調整 |
| Q3 軸 docs 更新? | YES | 完了時 PLATFORM_EVOLUTION_PRINCIPLES.md 実装履歴更新 |
| Q4 docs に残す判断? | YES | budget 単位設計 / effort 配分の根拠は記録価値あり |
| Q5 NotebookLM 連携? | NO |

→ Q1+Q3+Q4 YES + WORKDIR-ISOLATION (`supabase/functions/_shared/` = Codex#2 territory) = **Codex#2 territory 確定**.

## 期待する実装 (= 2 件パッケージ)

### Part A: `supabase/functions/_shared/task_budget.ts` (PLATFORM #6)

#### 仕様

```typescript
// _shared/task_budget.ts
export interface TaskBudget {
  scope: 'ef' | 'gha' | 'instance' | 'month';
  scope_id: string;        // EF 名 / GHA workflow 名 / instance 名 / 'YYYY-MM'
  limit_usd: number;       // 上限 USD
  spent_usd: number;       // 累積支出
  reset_at: string;        // 次リセット ISO timestamp
}

export async function checkBudget(scope: TaskBudget['scope'], scope_id: string): Promise<{ ok: boolean; remaining_usd: number }>
export async function recordSpend(scope: TaskBudget['scope'], scope_id: string, amount_usd: number): Promise<void>
export async function resetBudget(scope: TaskBudget['scope'], scope_id: string): Promise<void>
export function calculateApiCost(model: string, input_tokens: number, output_tokens: number): number
```

#### 動作フロー

```
[EF / GHA action 実行前]
    ↓
[checkBudget(scope, scope_id)] → { ok: false } なら 429 Too Many Requests + Slack alert
    ↓ ok なら実行
[API 呼出 (= Anthropic / OpenAI / etc)]
    ↓ 完了後
[calculateApiCost(model, in, out) → recordSpend(...)]
    ↓
[月次レポートで scope 別コスト集計 (= quota-monitor.yml 統合)]
```

#### スコープ階層

```
month (= 全体上限 / 例: $5000/月)
  └─ instance (= Win/PS#1-6/VSCode/Codex#1-2 / 例: $400/instance/月)
       └─ ef (= ai-hub / schedule-hub / etc / 例: $50/EF/月)
            └─ gha (= cs-check.yml / etc / 例: $20/run)
```

= 上位スコープ超過なら下位も自動停止. 例: month 上限到達 → 全 EF / GHA 一時停止.

#### Migration

```sql
-- supabase/migrations/20260429110000_create_task_budget.sql
CREATE TABLE IF NOT EXISTS task_budget (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scope text NOT NULL CHECK (scope IN ('ef', 'gha', 'instance', 'month')),
  scope_id text NOT NULL,
  limit_usd numeric(10,2) NOT NULL,
  spent_usd numeric(10,2) NOT NULL DEFAULT 0,
  reset_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(scope, scope_id)
);

ALTER TABLE task_budget ENABLE ROW LEVEL SECURITY;
CREATE POLICY task_budget_service_role ON task_budget FOR ALL USING (auth.role() = 'service_role');

-- Initial budgets
INSERT INTO task_budget (scope, scope_id, limit_usd, reset_at) VALUES
  ('month', '2026-04', 5000.00, '2026-05-01T00:00:00Z'),
  ('instance', 'win', 400.00, '2026-05-01T00:00:00Z'),
  ('instance', 'codex2', 400.00, '2026-05-01T00:00:00Z')
  -- ... (他 instance も列挙)
ON CONFLICT (scope, scope_id) DO NOTHING;
```

### Part B: `supabase/functions/_shared/effort_router.ts` (PLATFORM #7)

#### 仕様

```typescript
// _shared/effort_router.ts
export type Effort = 'low' | 'medium' | 'high' | 'xhigh';

export interface EffortConfig {
  action: string;          // EF action 名 (e.g. 'ai.daily.judgment')
  default_effort: Effort;
  rationale: string;       // なぜこの effort か (= docs に記録される)
  model_override?: string; // 特定 model 強制 (e.g. 'haiku-4-5')
}

export async function selectEffort(action: string, request_meta?: Record<string, unknown>): Promise<{ effort: Effort; model: string }>
export function annotateRequest(action: string, payload: Record<string, unknown>): Record<string, unknown>
```

#### Effort 配分マトリクス (初期値)

| Action 種別 | Effort | 根拠 |
| --- | --- | --- |
| 日常対話 (`ai.assistant.*`) | `low` | 高速 + 低コスト / ユーザー待機時間最小化 |
| AI 大学 quiz 採点 | `low` | 定型処理 / 正解判定のみ |
| 競合分析 / monitoring | `medium` | 短文要約 |
| 動画字幕生成 | `medium` | 構造化テキスト |
| daily-judgment / weekly-digest | `high` | 複数情報統合 |
| アーキテクチャ判断 / cross-instance-pr | `high` | 複数選択肢 trade-off |
| 競馬予想 (= 18+ 因子) | `xhigh` | 複雑判断 |
| 軸蒸留 (NotebookLM ask) | `xhigh` | 7 原則抽出 + 既存軸との関係明示 |

#### Migration

```sql
-- supabase/migrations/20260429120000_create_effort_config.sql
CREATE TABLE IF NOT EXISTS effort_config (
  action text PRIMARY KEY,
  default_effort text NOT NULL CHECK (default_effort IN ('low', 'medium', 'high', 'xhigh')),
  rationale text NOT NULL,
  model_override text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE effort_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY effort_config_service_role ON effort_config FOR ALL USING (auth.role() = 'service_role');

-- Initial configs (= 上記マトリクス)
INSERT INTO effort_config (action, default_effort, rationale) VALUES
  ('ai.assistant.chat', 'low', '日常対話 / 高速 + 低コスト / ユーザー待機時間最小化'),
  ('ai.university.quiz_grade', 'low', '定型処理 / 正解判定のみ'),
  ('ai.competitor.monitor', 'medium', '短文要約'),
  ('ai.daily.judgment', 'high', '複数情報統合'),
  ('ai.cross_instance.routing', 'high', '複数選択肢 trade-off'),
  ('ai.horse_racing.predict', 'xhigh', '18+ 因子複雑判断'),
  ('ai.notebooklm.distill', 'xhigh', '7 原則抽出 + 既存軸関係明示')
ON CONFLICT (action) DO UPDATE SET
  default_effort = EXCLUDED.default_effort,
  rationale = EXCLUDED.rationale,
  updated_at = now();
```

### Part A + B 統合 (= 1 EF action から呼出)

```typescript
// 例: ai-hub action 内
import { checkBudget, recordSpend, calculateApiCost } from '../_shared/task_budget.ts';
import { selectEffort } from '../_shared/effort_router.ts';

export async function handleAiHub(req: Request) {
  const { action, payload } = await req.json();

  // 1. effort 決定 (PLATFORM #7)
  const { effort, model } = await selectEffort(action);

  // 2. budget check (PLATFORM #6)
  const { ok, remaining_usd } = await checkBudget('ef', 'ai-hub');
  if (!ok) return new Response('Budget exceeded', { status: 429 });

  // 3. API call with effort
  const apiResp = await callAnthropic({ model, effort, ...payload });

  // 4. spend record
  const cost = calculateApiCost(model, apiResp.usage.input_tokens, apiResp.usage.output_tokens);
  await recordSpend('ef', 'ai-hub', cost);

  return new Response(JSON.stringify(apiResp.body), { headers: { 'Content-Type': 'application/json' } });
}
```

= **3 行で 2 軸 dogfood 完了**. 全 EF に展開すれば fleet 全体で cost 制御 + effort 最適化.

### GHA 統合

```yaml
# .github/workflows/<any>.yml
env:
  TASK_BUDGET_USD: ${{ secrets.TASK_BUDGET_GHA_DEFAULT }}  # 例: 20
  TASK_BUDGET_SCOPE: 'gha'
  TASK_BUDGET_SCOPE_ID: ${{ github.workflow }}

steps:
  - name: Pre-flight budget check
    run: |
      python scripts/check_budget.py --scope gha --scope-id "${{ github.workflow }}" --limit "$TASK_BUDGET_USD" || { echo "::error::Budget exceeded"; exit 1; }
```

## ファイル設計

```
supabase/functions/_shared/
  ├── task_budget.ts          # PLATFORM #6
  └── effort_router.ts         # PLATFORM #7

supabase/migrations/
  ├── 20260429110000_create_task_budget.sql    # task_budget table
  └── 20260429120000_create_effort_config.sql  # effort_config table

scripts/
  └── check_budget.py          # GHA 用 pre-flight チェック

docs/
  └── cost_control_architecture.md   # 設計判断記録 (= 統合 docs)

# 既存 EF 1-2 件 (= ai-hub) で actual usage 統合 (= 残りは段階展開)
```

## 受け入れ基準

- [ ] `_shared/task_budget.ts` 実装 (`checkBudget` / `recordSpend` / `resetBudget` / `calculateApiCost`)
- [ ] `_shared/effort_router.ts` 実装 (`selectEffort` / `annotateRequest`)
- [ ] migration `20260429110000_create_task_budget.sql` (table + RLS + 初期値)
- [ ] migration `20260429120000_create_effort_config.sql` (table + RLS + 初期マトリクス)
- [ ] `scripts/check_budget.py` (GHA pre-flight)
- [ ] `ai-hub` EF で actual usage 統合 (= reference implementation)
- [ ] `docs/cost_control_architecture.md` 設計判断記録 (= スコープ階層 / effort マトリクス根拠)
- [ ] deno lint / migration apply 0 エラー
- [ ] git commit + push origin HEAD:main
- [ ] `docs/PLATFORM_EVOLUTION_PRINCIPLES.md` 実装履歴更新 (#6 + #7 完成 / 2.0 → **4.0/7**)
- [ ] `docs/FLEET_SCALING_ROADMAP.md` Phase 1 ブロッカー 5→3 (= -2)
- [ ] 本 cross-instance-pr を `done/` 移動

## 連携先

### memory-search-hub (= part 70 既起票) との連携

`memory-search-hub` の Stage 3 (= Haiku 4.5 LLM 再ランク) は effort 設定対象. `effort_config` table に entry 追加:
```sql
INSERT INTO effort_config (action, default_effort, rationale) VALUES
  ('memory.rank', 'low', 'top_k=5 候補から再ランク / 速度優先 / 1 query <500ms target')
```

→ part 70 と本 PR は **連動実装** (= Codex#2 が 2 PR 同時着手で効率最大).

### quota-monitor.yml との統合

既存 `quota-monitor.yml` は Anthropic API 月額のみ tracking. 本 PR で **scope 別 budget** に拡張. 既存 yml は廃止せず、本 PR の `task_budget` table を読む形に変更.

### consolidate-memory --lint (= part 69 既起票) との連携

`memory.lint` action にも effort 設定:
```sql
INSERT INTO effort_config (action, default_effort, rationale) VALUES
  ('memory.lint', 'medium', '矛盾検出は LLM 判定 / N=K 候補ペアの精度 vs 速度バランス')
```

## OPS-28 charter §6 Win → Codex#2 lane (本日 2 件目)

| part | from | to | 内容 |
| --- | --- | --- | --- |
| 70 | Win → Codex#2 | Codex#2 | memory-search-hub EF (BRAIN #7) |
| **74 (本)** | **Win → Codex#2** | **Codex#2** | **task_budget + effort_router (PLATFORM #6+#7)** |

= Win → Codex#2 lane が **本日 2 PR 連発**. Codex#2 territory に **fleet 拡大の基盤実装** が集中.

## 構造的観察 — 1 PR で 2 原則同時委譲

これまで cross-instance-pr は通常 1 件 = 1 原則だった. 本 PR で初の **1 PR 2 原則同時委譲**:

| 軸 | 原則 | 連携理由 |
| --- | --- | --- |
| PLATFORM #6 | task_budget | cost 上限 |
| PLATFORM #7 | effort_router | cost 配分 |

= **概念的ペア** (= budget = 上限 / effort = 配分). 同 territory + 同 file 系統 + 同 review 文脈 → 1 PR が効率最大.

= co-implementation pattern 第 4 例 (= 1 PR 2 原則同時委譲 / pattern 進化).

---

*Win版#132 part 74 / 2026-04-29 起票 / PLATFORM_EVOLUTION #6 + #7 同時 Codex#2 委譲 / Phase 1 ブロッカー 2 件解消 / 1 PR 2 原則 第 1 例 / co-implementation 第 4 例 / Win → Codex#2 lane 本日 2 PR 連発*
