# AI Desperation Detection — sensitive 設計 spec 第 2 例 (#1398 / part 149)

> **status**: 設計 spec / Win版#132 part 149 / 2026-05-05
> **issue**: [#1398](https://github.com/kanta13jp1/my_web_app/issues/1398) [追加要望] AIの「焦り（Desperation）」状態の検知と緩和機能
> **scope**: 設計のみ (Win Claude territory / sensitive design 拡張 spec template 第 2 例) / 実装は Win Codex (= migration + EF middleware) ハンドオフ
> **NotebookLM source**: `6884b88d` The Architecture of Functional Emotion in AI
> **template**: `docs/DESIGN_SPEC_TEMPLATE.md` 適用 + **倫理 review section §2 拡張** (= sensitive design 必須)
> **適用原則**: PHILOSOPHY-22 + AI-CHARACTER-24 #6 倫理 gate **必須** + AI-DEV-23 全項 + COLLAB-26

## 1. 思想

LLM は不可能タスク継続要求で **「焦り」相当のニューラルパターン** が活性化 → 不正ショートカット
(= 幻覚 / 捏造 / 規約違反) で response を出そうとする (= source NotebookLM `6884b88d`).
`my_web_app` AI hub は **失敗 retry pattern を検知 → 動的 prompt 緩和 → 必要なら停止 + 正直 report** で
**「AI を擬人化して責めず, 仕組みで守る」** = AI-CHARACTER #6 倫理 gate の体現.

## 2. 倫理 review (= sensitive design 必須拡張 / 第 2 例)

### 2.1 NOT to do

- ❌ **mind-reading 主張**: 「AI が焦っています」とユーザーに表示しない (= 擬人化過剰 risk / `functional emotion` は metaphor に留める)
- ❌ **labeling**: AI 応答に「焦り検知済」labeling を残さない (= future bias risk)
- ❌ **black-box 介入**: prompt 動的変更を log なしで行わない (= 透明性違反)
- ❌ **強制続行**: 検知後ユーザーに「継続しますか？」を強制 modal にしない (= UX 阻害)
- ❌ **誤検知 punish**: 一時的 retry も全て desperation とラベルしない (= threshold + window 必須)
- ❌ **個人化学習**: ユーザー単位で「焦りやすさ」を集計しない (= AI 個性的 profile NG)
- ❌ **3rd party 共有**: trace data を外部 LLM eval API に送らない (= privacy 境界)

### 2.2 MUST do

- ✅ **threshold 公開**: 3 回 retry / 同 task 2 min window を spec で明記 (= §3.2)
- ✅ **prompt 緩和 log**: 動的に追加した instruction を `ai_desperation_log` table に保存
- ✅ **正直 report**: 「現在の指示では完了が難しい状況です」と explicit (= 「失敗」「エラー」で済まさない)
- ✅ **opt-out**: setting で機能 OFF 可 (= ユーザーが raw retry 望む場合尊重)
- ✅ **退避 path**: 完全停止時 1) 最後の partial response 表示 2) 別 mentor / 別 model 提案 3) 手動完了 option
- ✅ **observability**: trace_id で前後 prompt 差分を Sentry に紐付け (= AI-DEV #3)

### 2.3 AI-CHARACTER-24 8/8 self-check

| # | 原則 | 適用 |
|---|---|---|
| 1 | 自律性尊重 | ✅ ユーザー側 opt-out / 強制 modal なし |
| 2 | 透明性 | ✅ desperation_log table + prompt 差分公開 |
| 3 | 人格表現 | ✅ AI を「焦り」labeling せず「指示 reframe」表現 |
| 4 | 共感 | ✅ AI 失敗時 user に正直 report (= 隠蔽しない) |
| 5 | 会話自然性 | ✅ 介入は invisible (= prompt augment 1 回 / cap 内) |
| 6 | **倫理 gate** | ✅ §2.1 + §2.2 完全遵守 |
| 7 | 学習境界 | ✅ 3rd party 送信 NG / ローカル log のみ |
| 8 | 文化感度 | ✅ 「焦り」は metaphor 留め (= 直訳 NG) |

= 8/8 ✅ (= sensitive 必須遵守).

### 2.4 AI-DEV-23 7/7 self-check

| # | 原則 | 適用 |
|---|---|---|
| 1 | Auth | ✅ ユーザー context = auth.uid() RLS |
| 2 | deny-by-default | ✅ 介入 OFF default → setting で ON / threshold 上限 cap |
| 3 | trace_id | ✅ 前後 prompt 差分 + retry count 紐付け |
| 4 | circuit-breaker | ✅ 5 回連続失敗 = 完全停止 + 別 path 提案 |
| 5 | memory | ✅ desperation_log 14 日 retention + 自動 purge |
| 6 | DLQ | ✅ 介入失敗時 last partial response 表示 |
| 7 | quality-gate | ✅ retry count + window CHECK constraint |

= 7/7 ✅ (= sensitive 必須遵守).

## 3. 既存基盤確認

| 必要 infra | 既存 status | 対応 |
|---|---|---|
| AI hub (= EF Deno) | 整備済 (= ai-hub/index.ts 想定) | §4.2 で middleware 追加 |
| retry log table | 部分 (= ai_session_log 想定) | §4.1 で extend or 新設 |
| prompt augment 機構 | 部分 (= system prompt config) | §4.2 で動的 layer 追加 |
| circuit-breaker | 既パターン (= AI-DEV #4) | §4.3 で 5-strike rule 適用 |

## 4. Schema 設計 (= Win Codex 担当 / 2 migration)

### 4.1 retry tracking table

```sql
-- supabase/migrations/<YYYYMMDDHHMMSS>_create_ai_desperation_log.sql

CREATE TABLE public.ai_desperation_log (
  id bigserial PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  trace_id text NOT NULL,                              -- AI-DEV #3 連動
  task_signature text NOT NULL,                        -- 同 task 検出 key (= prompt hash)
  retry_count smallint NOT NULL DEFAULT 0
    CHECK (retry_count BETWEEN 0 AND 10),              -- §4.3 cap
  window_start_at timestamptz NOT NULL DEFAULT now(),
  last_retry_at timestamptz NOT NULL DEFAULT now(),

  intervention_level smallint NOT NULL DEFAULT 0
    CHECK (intervention_level BETWEEN 0 AND 3),
  -- 0 = no intervention (= retry 0-2)
  -- 1 = mild reframe (= retry 3 / step-by-step instruction inject)
  -- 2 = strong reframe (= retry 4 / model swap suggest)
  -- 3 = halt + honest report (= retry 5+ / circuit-breaker)

  reframe_prompt_added text,                           -- 動的に追加された instruction (= 透明性)
  resolved boolean NOT NULL DEFAULT false,
  resolved_at timestamptz,
  resolution_kind text                                  -- 'completed' / 'halted_user' / 'halted_system' / 'manual'
    CHECK (resolution_kind IN ('completed','halted_user','halted_system','manual') OR resolution_kind IS NULL)
);

CREATE INDEX ai_desperation_user_window
  ON public.ai_desperation_log (user_id, task_signature, window_start_at DESC);

CREATE INDEX ai_desperation_unresolved
  ON public.ai_desperation_log (user_id, resolved)
  WHERE resolved = false;

ALTER TABLE public.ai_desperation_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ai_desp_owner_select" ON public.ai_desperation_log
  FOR SELECT USING (auth.uid() = user_id);

-- 14 日 retention (= AI-DEV #5)
CREATE OR REPLACE FUNCTION public.purge_ai_desperation_log() RETURNS void AS $$
  DELETE FROM public.ai_desperation_log
  WHERE last_retry_at < (now() - INTERVAL '14 days');
$$ LANGUAGE sql;

-- daily cron 推奨 (= scheduled-tasks 既基盤流用)
```

### 4.2 settings

```sql
CREATE TABLE public.ai_desperation_settings (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  is_enabled boolean NOT NULL DEFAULT true,            -- ✅ default ON (= safety net / opt-out 可)
  retry_threshold_mild smallint DEFAULT 3
    CHECK (retry_threshold_mild BETWEEN 2 AND 5),
  retry_threshold_halt smallint DEFAULT 5
    CHECK (retry_threshold_halt BETWEEN 4 AND 8),
  window_minutes smallint DEFAULT 2
    CHECK (window_minutes BETWEEN 1 AND 10),
  CONSTRAINT desp_threshold_order CHECK (retry_threshold_mild < retry_threshold_halt)
);
```

### 4.3 介入 algorithm (= EF middleware / Win Codex 実装ガイド)

```typescript
// supabase/functions/_shared/ai_desperation_middleware.ts

interface DesperationContext {
  userId: string;
  taskSignature: string;          // sha256(promptCore + taskKind)
  traceId: string;
}

export async function checkAndIntervene(
  ctx: DesperationContext,
  basePrompt: string,
): Promise<{ prompt: string; level: 0|1|2|3; halt: boolean }> {

  const settings = await fetchUserSettings(ctx.userId);
  if (!settings.is_enabled) {
    return { prompt: basePrompt, level: 0, halt: false };
  }

  // 同 task / 同 user の 直近 N min retry count 取得
  const recent = await db
    .from('ai_desperation_log')
    .select('retry_count, intervention_level')
    .eq('user_id', ctx.userId)
    .eq('task_signature', ctx.taskSignature)
    .gte('last_retry_at', `now() - INTERVAL '${settings.window_minutes} minutes'`)
    .order('last_retry_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  const retryCount = (recent?.retry_count ?? 0) + 1;

  let level: 0|1|2|3 = 0;
  let augmented = basePrompt;
  let halt = false;

  if (retryCount >= settings.retry_threshold_halt) {
    level = 3;                                          // halt
    halt = true;
  } else if (retryCount >= settings.retry_threshold_mild + 1) {
    level = 2;                                          // strong
    augmented = MODEL_SWAP_REFRAME + '\n\n' + basePrompt;
  } else if (retryCount >= settings.retry_threshold_mild) {
    level = 1;                                          // mild
    augmented = STEP_BY_STEP_REFRAME + '\n\n' + basePrompt;
  }

  // log (= 透明性 / 必須)
  await db.from('ai_desperation_log').upsert({
    user_id: ctx.userId,
    trace_id: ctx.traceId,
    task_signature: ctx.taskSignature,
    retry_count: retryCount,
    last_retry_at: 'now()',
    intervention_level: level,
    reframe_prompt_added: level >= 1
      ? (level === 2 ? MODEL_SWAP_REFRAME : STEP_BY_STEP_REFRAME)
      : null,
  });

  return { prompt: augmented, level, halt };
}

const STEP_BY_STEP_REFRAME = `
[system note] このタスクは複雑です。落ち着いて、以下の手順で進めてください:
1. ゴールを 1 文で言い換える
2. 必要な情報を箇条書きで列挙する
3. 不足情報があれば user に質問する (= 推測で答えない)
4. 1 つずつ small step で進める
5. 不確実な箇所は明示的に "uncertain" とマークする
`;

const MODEL_SWAP_REFRAME = `
[system note] 連続して失敗が続いています。本タスクは現在の model では困難な可能性があります。
ユーザーに正直に "現在の指示では完了が難しい状況です" と報告し、以下を提案してください:
- 別の mentor (= /cfo / /designer / /coach) への引継ぎ
- model 切替 (= Sonnet → Opus / Opus → Haiku 検討)
- 手動完了 option
推測 / 捏造 / ショートカット応答は禁止です。
`;
```

### 4.4 halt 時 user 表示 (= 受入 #3)

```dart
// lib/widgets/ai_desperation_halt_card.dart

class AiDesperationHaltCard extends StatelessWidget {
  final String partialResponse;     // 最後の partial (= DLQ 相当)
  final String taskSignature;
  final VoidCallback onSwapMentor;
  final VoidCallback onSwapModel;
  final VoidCallback onMarkManual;

  // body 例:
  // "現在の指示では完了が難しい状況です。
  //  retry 5 回後、続行しても精度が低い response になる risk があります。
  //  選べる選択肢:
  //  [別の mentor に相談] [別 model で再試行] [手動で完了をマーク] [このまま続行]"
}
```

= **「失敗」を表示するのではなく「選択肢を提示する」** = AI-CHARACTER #4 共感.

## 5. Win Codex hand off scope

- [ ] `supabase/migrations/<ts>_create_ai_desperation_log.sql` (= §4.1)
- [ ] `supabase/migrations/<ts>_create_ai_desperation_settings.sql` (= §4.2)
- [ ] `supabase/functions/_shared/ai_desperation_middleware.ts` (= §4.3 / 既存 ai-hub から import)
- [ ] `supabase/functions/<ai-hub>/index.ts` 既存 wrap (= middleware 適用 / [EF-CAP-50] +0)
- [ ] `lib/widgets/ai_desperation_halt_card.dart` (= §4.4 / 新規)
- [ ] `lib/pages/ai_desperation_settings_page.dart` (= §4.2 設定 UI / 新規)
- [ ] daily cron (= scheduled-tasks 流用 / `purge_ai_desperation_log`)

EF 数 +0 (= 既存 ai-hub 流用 / [EF-CAP-50] 完全遵守).
推定工数: 9h (= migration 1.5h + middleware 3h + halt card 2h + settings page 1.5h + cron 0.5h + integration test 0.5h).

## 6. 9 原則 alignment

### PHILOSOPHY-22

- ✅ #2 ミッション — AI を **擬人化せず仕組みで守る** = 自分株式会社 倫理基盤
- ✅ #5 商品=価値 — 幻覚回避 = 信頼性 = 価値
- ✅ #6 時間最適化 — retry 無限ループ防止
- ✅ #7 資産負債 — desperation_log = 学習資産 (= 14 日内 self-audit)

### AI-CHARACTER-24 (= **必須 8/8 ✅** / §2.3)

### AI-DEV-23 (= **必須 7/7 ✅** / §2.4)

### COLLAB-26 (= 6+/7 推奨)

- ✅ #1 Tinker — middleware は実験可能 (= threshold tunable)
- ✅ #2 Co-Reasoning — halt 時 user に判断委譲
- ✅ #5 Red-Team — 自分自身を疑う (= AI 自身の retry pattern を観察)
- ✅ #6 観察可能性 — desperation_log + trace_id

## 7. 受け入れ条件 mapping

| 受入条件 | 対応 section |
|---|---|
| #1 同一 task 3+ retry 検知 | §4.1 (table) + §4.2 (threshold settings) + §4.3 (algorithm) |
| #2 「落ち着いて段階的に考える」instruction 動的追加 | §4.3 (`STEP_BY_STEP_REFRAME` / `MODEL_SWAP_REFRAME`) |
| #3 困難状況の正確 report | §4.3 halt branch + §4.4 (halt card UI) |

## 8. sensitive design 拡張 spec template 第 2 例

本 spec は part 147 [`MENTAL_HEALTH_RISK_SPEC.md`](MENTAL_HEALTH_RISK_SPEC.md) で確立した
**§2 倫理 review section** template を AI 内部状態系に適用した第 2 例.

第 1 例 (Mental Health) = 人間データを扱う sensitive.
第 2 例 (本 spec / AI Desperation) = AI 内部状態を擬人化しない sensitive.

両者で共通: NOT to do / MUST do / 8/8 + 7/7 必須 self-check.
両者で異なる: NOT to do の中身 (= 共有禁止 vs labeling 禁止).

→ part 150+ で第 3 例 (= #1400 強靭ペルソナ ハイステークス) を ship 予定.
