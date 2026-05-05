# PII Guardrail / AI Audit Layer — sensitive 設計 spec 第 5 例 (#773 / part 154)

> **status**: 設計 spec / Win版#132 part 154 / 2026-05-05
> **issue**: [#773](https://github.com/kanta13jp1/my_web_app/issues/773) [追加要望] 全AI機能共通のガードレール・PII監査レイヤー
> **scope**: 設計のみ (Win Claude territory / sensitive design 拡張 spec template 第 5 例 = **個人 data + security boundary** 二重 sensitive 領域) / 実装は Win Codex (= migration + `_shared/guardrail.ts` + `ai-audit-hub` EF + Flutter consent screen + admin diagnostic page) ハンドオフ
> **NotebookLM source**: `54b6f2f2-6831-4376-b2dd-99a1a4bf90ec` Writer AI Studio Comprehensive Development and Management Guide
> **template**: [`docs/DESIGN_SPEC_TEMPLATE.md`](DESIGN_SPEC_TEMPLATE.md) 適用 + **倫理 review section §2** (= sensitive design 必須 / 第 5 例で **個人 data + security boundary** 二重領域に拡張)
> **適用原則**: PHILOSOPHY-22 + **AI-CHARACTER-24 8/8 必須** + **AI-DEV-23 7/7 必須** + **MCP-AUTH-27 cross-link** (= sensitive 第 4 例 #1577 と相補) + IMBUE-25 + COLLAB-26 + VIBE-30
> **関連 Issue / Spec**: [#1577](https://github.com/kanta13jp1/my_web_app/issues/1577) MCP Auth Hardening (= [`MCP_AUTH_HARDENING_SPEC.md`](MCP_AUTH_HARDENING_SPEC.md)) / [#1393](https://github.com/kanta13jp1/my_web_app/issues/1393) Mental Health Risk (= [`MENTAL_HEALTH_RISK_SPEC.md`](MENTAL_HEALTH_RISK_SPEC.md)) / [#1398](https://github.com/kanta13jp1/my_web_app/issues/1398) AI Desperation Detection / [#1400](https://github.com/kanta13jp1/my_web_app/issues/1400) Robust AI Persona

## 1. 思想

`my_web_app` は AI 出力箇所を増やし続けている: AI大学 (1957 社) / WBS auto-claim / 追加要望フォーム / chatbot / X 投稿生成 / ライフマネジメント / 資産管理 / blog draft / news writer / mealmate. **個別 EF が個別に safety logic を持つ現状** = root cause 散在で:

- 同じ PII 漏洩 incident が複数 EF で再発 (= 一箇所修正しても他 EF で同じ事故)
- audit trail が EF ごとに JSON 形が違う = incident triage 不能
- 高リスク判定 (= medical / legal / financial 投稿) を **止める ロジックが各 EF に重複実装** = 抜け漏れ risk

本 spec は **全 AI 生成 / AI 解析機能の前後で適用される共通 guardrail / audit middleware** を `_shared/guardrail.ts` (= ライブラリ層) + `ai-audit-hub` EF (= 集計 / 高リスク承認 queue) で導入する. 既存 ai-hub / admin-hub / chatbot-hub / blog-hub 等 monolith EF は `withGuardrail()` wrapper 経由で middleware 適用 = **EF 増殖を抑え** [EF-CAP-50] 適合 (= +1 EF only).

= AI-DEV #2 deny-by-default + #3 trace_id + #5 memory + #7 quality-gate を AI 機能横断で **1 箇所に集約**.
= AI-CHARACTER #6 倫理 gate + #7 学習境界の **横断強制ゲート**.
= [`MCP_AUTH_HARDENING_SPEC.md`](MCP_AUTH_HARDENING_SPEC.md) (= 外部 MCP 攻撃面) と相補 (= 本 spec は **内部 AI 出力面**).

> **sensitive 第 5 例の位置付け**: 第 1 (人間データ) / 第 2 (AI 内部状態) / 第 3 (high-stakes persona) / 第 4 (security boundary) と異なり、**個人 data × security boundary 二重 sensitive** 領域. NOT to do の中核は「AI 出力 → 第三者 / 公開面 / 学習 data へ PII / 高 risk content が到達する経路を deny-by-default で断つ」.

## 2. 倫理 review (= sensitive design 必須拡張 / 第 5 例 / 個人 data × security boundary 二重適用)

### 2.1 NOT to do

- ❌ **PII raw 送信禁止 (= 共通 1)**: 検出前 raw input を外部 LLM (= OpenAI / Anthropic / Gemini) へ直接送らない. **redact 後** または **categorical encoding** のみ送信
- ❌ **学習 data 流用禁止 (= 共通 1)**: tool args / response を vendor の **opt-out 設定なしのモデル training pool** に入れない (= OpenAI `metadata.disable_training=true` 必須 / Anthropic ZDR 確認)
- ❌ **fail open 禁止 (= 共通 3 拡張)**: moderation API timeout / network error 時に **「とりあえず通す」** NG. timeout = block + log + Slack alert (= AI-DEV #2 deny-by-default)
- ❌ **silent redact 禁止**: redact 実行を user に告知せず実施しない (= 「あなたの入力の一部を伏せました」即時 UI 表示必須)
- ❌ **categorical false positive 放置禁止**: 検知率 100% 不可能を前提に **false positive 申告窓口** を必ず併設 (= user feedback で 24h 内応答)
- ❌ **公開投稿 fail silent 禁止**: X 投稿 / blog publish 等の **公開面** で moderation 失敗 → human approval queue に必ず送る (= 自動 publish しない)
- ❌ **管理者 raw 閲覧禁止 (= 共通 4 拡張)**: admin diagnostic page で audit log を見るとき、 PII raw は **categorical sample のみ** (= 「email × 3 redacted」と表示 / 元 string 永久不可視 / 監査者すら覗けない)
- ❌ **redaction rule manual SQL 登録禁止 (= 第 4 例から継承)**: `pii_redaction_rules` table への INSERT は migration / CI 経由のみ (= adhoc SQL は CI lint で reject)
- ❌ **consent screen skip 不可**: 初回 AI 機能利用前に必ず consent screen 表示 (= 「どの AI 機能で何の data が処理されるか」明示 / OK ボタン押下まで AI 呼出 block)
- ❌ **権限過剰申告禁止 (= 共通 4)**: tool 単位 scope を consent screen で選択可 / 既定 ON なし (= MCP-AUTH 第 4 例 と整合 / `pii_consent.scope` 列で tool 単位記録)
- ❌ **gaslighting / 強制継続禁止 (= 共通 2)**: 高 risk 検知後 user の「やっぱり止める」を必ず尊重 / 「処理を続けます」を default にしない
- ❌ **export / 削除 拒否禁止**: user request で `pii_audit_log` 全件 JSON export + 削除 / 30 日以内応答 (= GDPR / 個情法整合)

### 2.2 MUST do

- ✅ **opt-in / opt-out 全権 (= 共通 1)**: AI 機能 ON/OFF が user 全権 / consent screen で tool 単位 scope 選択 / setting で全 AI 無効化 1 tap
- ✅ **観察可能性 (= 共通 2)**: 全 AI invocation で `pii_audit_log` 1 行 INSERT (= trace_id + tool_name + redaction_summary + moderation_score + decision + 90 日 retention)
- ✅ **退避 path (= 共通 3)**: high_risk 判定時 必ず別 path / human approval queue + user 確認 modal + incident runbook (= [`docs/AI_GUARDRAIL_INCIDENT_RUNBOOK.md`](AI_GUARDRAIL_INCIDENT_RUNBOOK.md) 新設)
- ✅ **vendor managed 優先 (= 共通 4)**: PII detection MVP = **OpenAI Moderation API (= moderations endpoint / 無料)** + **Microsoft Presidio (= OSS / self-host) for PII categorical** / 自前 regex は Phase 2 fallback only / fallback trigger 明示 (= vendor SLA 違反 / 月 N 回連続 timeout)
- ✅ **deny-by-default**: middleware 適用なし EF は AI 呼出 reject (= `_shared/guardrail.ts` import なしで AI SDK 呼出する EF は CI lint で fail)
- ✅ **redact 透明性**: 検出された PII を user に **直前 modal** で表示 / 「OK redact して送信」「キャンセル」「全部送りたい (= override + audit)」3 択 (= IMBUE #4 mentor 感)
- ✅ **public post double-gate**: X 投稿 / blog publish では moderation **2 段** (= 生成時 + publish 直前) 通過 必須 / どちらか fail で human approval queue へ
- ✅ **trace_id propagation**: AI 呼出開始時 trace_id 採番 / EF → middleware → audit_log → Sentry まで横断 (= AI-DEV #3)
- ✅ **incident escape hatch**: 大量 false positive / 大量 PII leak 検知時 Sentinel role が 1 SQL で全 AI 機能 disable (= `UPDATE ai_global_kill_switch SET enabled=false`)
- ✅ **anomaly detection cron**: user_id × 1h での moderation reject 数 > p99×3 で Slack alert (= 攻撃 / モデル劣化 検知)
- ✅ **6 軸全 ✅ ゲート**: PHILOSOPHY / AI_DEV / AI_CHARACTER / IMBUE / COLLAB_AI / MCP_AUTH **すべてクリアした AI 機能のみ guardrail に登録可**

### 2.3 AI-CHARACTER-24 8/8 self-check

| # | 原則 | 適用 |
|---|---|---|
| 1 | 自律性尊重 | ✅ consent screen で tool 単位 scope 選択 / 「全部送りたい」override も用意 (= user 全権) |
| 2 | 透明性 | ✅ redact 結果を直前 modal で表示 / `pii_audit_log` を本人 export 可 / black-box なし |
| 3 | 人格表現 | ✅ moderation reject 時 mentor 的言葉 (= 「この内容は公開しない方がよさそう」 / persona 維持 = [`ROBUST_AI_PERSONA_SPEC.md`](ROBUST_AI_PERSONA_SPEC.md) 連動) |
| 4 | 共感 | ✅ false positive 申告窓口 24h 応答 / 「申し訳ない」謝罪 + 改善 commit (= 失敗 narrative なし) |
| 5 | 会話自然性 | ✅ redact modal は 1 tap で「OK」「Cancel」「Override」 / モーダル詰まりなし |
| 6 | **倫理 gate** | ✅ §2.1 + §2.2 完全遵守 / 高 risk 自動 publish 不可 / human approval gate 必須 |
| 7 | 学習境界 | ✅ tool args / response を vendor training pool に入れない (= OpenAI `disable_training=true`) / redact 後 categorical encoding のみ送信 |
| 8 | 文化感度 | ✅ ja/en 両 prompt で PII regex 別建て (= 日本住所「東京都〜」 / マイナンバー / 電話 全角等の特殊 case) |

= **8/8 ✅** (= sensitive 必須遵守).

### 2.4 AI-DEV-23 7/7 self-check

| # | 原則 | 適用 |
|---|---|---|
| 1 | Auth | ✅ `ai-audit-hub` EF は admin scope 限定 / `withGuardrail()` middleware は user scope 必須 (= anonymous user の AI 呼出は guest_id で audit log 記録) |
| 2 | deny-by-default | ✅ middleware 適用なし EF は AI 呼出 reject / moderation timeout = block + alert / consent なし = AI 呼出 block |
| 3 | trace_id | ✅ AI 呼出開始時 trace_id 採番 / `pii_audit_log.trace_id` で全 invocation 紐付け / Sentry 連動 |
| 4 | circuit-breaker | ✅ moderation API 5min 連続 timeout で local fallback (= regex only) + Slack alert / `ai_global_kill_switch` で人手 disable |
| 5 | memory | ✅ `pii_audit_log` 90 日 retention / daily aggregator (= `pii_audit_daily_summary`) / 自動 purge cron |
| 6 | DLQ | ✅ moderation API 失敗 invocation を `pii_audit_log.api_error=true` で記録 / failed re-drive は明示 user 操作のみ |
| 7 | quality-gate | ✅ 6 軸全 ✅ ゲート + AI-CHARACTER 8/8 + AI-DEV 7/7 + 公開面 double-gate (= 生成時 + publish 直前 2 段 moderation) |

= **7/7 ✅** (= sensitive 必須遵守).

### 2.5 MCP-AUTH-27 cross-link self-check (= sensitive 第 4 例との相補性)

[`MCP_AUTH_HARDENING_SPEC.md`](MCP_AUTH_HARDENING_SPEC.md) は **外部 MCP server 公開時の攻撃面**. 本 spec は **内部 AI 出力面の PII / 高 risk content gate**. 二重防御 architecture:

| 層 | 担当 spec | 担当領域 | 共通項 |
|---|---|---|---|
| 外部 boundary | MCP_AUTH_HARDENING (#1577) | OAuth / Bearer / DCR / Resource Indicators / Audit Log | mcp_audit_log + WorkOS managed |
| 内部 boundary | **PII_GUARDRAIL (= 本 spec / #773)** | Redact / Moderation / Consent / Public Post Double-Gate | pii_audit_log + Microsoft Presidio managed |

= 二重 audit log (`mcp_audit_log` + `pii_audit_log`) = trace_id で **横断結合可能** (= 受入 #3 「どの機能のどの AI 出力か後から監査」).

## 3. 既存基盤確認

| 必要 infra | 既存 status | 対応 |
|---|---|---|
| `ai-hub` EF (= 中核 AI dispatcher / 4829 行 monolith) | **整備済** (= part 49+ / chatbot / X / blog / mealmate / WBS 等横断 dispatcher) | §4.1 で `withGuardrail()` wrapper 適用 / 既存 EF 変更最小 (= 1 import + 1 wrapper) |
| `admin-hub` EF (= admin dashboard read endpoint) | **整備済** | §4.5 で `pii_audit_log` aggregate read endpoint 追加 |
| `_shared/` library 領域 | **整備済** (= `_shared/viral-growth.ts` 等既存) | §4.2 で `_shared/guardrail.ts` 新設 (= middleware 中核) |
| `pii_audit_log` table | **未整備** | §4.3 で新設 (= 全 AI invocation 1 行 / 90 日 retention) |
| `pii_redaction_rules` table | **未整備** | §4.3 で新設 (= regex / NER pattern 一覧 / Terraform IaC 推奨) |
| `pii_consent` table | **未整備** | §4.3 で新設 (= user × tool scope 選択記録) |
| `ai_global_kill_switch` table | **未整備** | §4.3 で新設 (= 1 row / 緊急時 全 AI 機能 disable) |
| `ai-audit-hub` EF (= aggregate read + human approval queue) | **未整備** | §4.4 で新設 (= +1 EF / [EF-CAP-50] 適合) |
| OpenAI Moderation API integration | **未整備** | §4.2 で `_shared/guardrail.ts` 内 helper 実装 |
| Microsoft Presidio integration (= PII NER) | **未整備** | §4.2 で self-host docker / Phase 2 = managed migrate |
| Flutter consent screen UI | **未整備** | §4.6 で新設 (= 初回 AI 機能利用前 modal) |
| Flutter redact-preview modal UI | **未整備** | §4.6 で新設 (= 直前 modal / 3 択) |
| Flutter `/admin/ai-audit` page | **未整備** | §4.6 で新設 (= 直近 7 日 breakdown / human approval queue) |
| Flutter false positive 申告 form | **未整備** | §4.6 で新設 (= modal 内 1 tap / 24h 応答 SLA) |
| Sentry / Slack alert integration | **整備済** (= part 100+ Sentry / Slack webhook) | §4.4 で `ai-audit-hub` から alert 送信 reuse |
| migration CI lint (= adhoc SQL reject) | **整備済** (= part 121 ISSUE-PRECHECK 系の lint) | §4.7 で `pii_redaction_rules` への INSERT を migration 経由のみ強制 |

= 整備済 4 / 部分 0 / 未整備 11 = 整備済比率 27% (= 通常 8.5h / sensitive 12h baseline 比 +30% premium 妥当 / **新領域 sensitive のため整備済低** / Codex 工数 14h 推定).

## 4. 設計 (= Win Codex 担当 / 4 migration + 1 _shared lib + 1 EF + 4 Flutter widget)

### 4.1 既存 EF への wrapper 適用 (= 受入 #1)

```typescript
// supabase/functions/ai-hub/index.ts (= 4829 行 既存 EF / 拡張は 2 line)

import { withGuardrail } from "../_shared/guardrail.ts";

// 既存 handler を wrap
const wrappedHandler = withGuardrail(originalHandler, {
  toolName: "ai-hub",                       // pii_audit_log.tool_name
  scope: "user",                             // consent screen scope
  publicSurface: false,                      // X投稿/blog等は true → double-gate
});

serve(wrappedHandler);
```

`chatbot-hub` / `blog-hub` / `x-post-hub` / `mealmate-hub` / `wbs-hub` 等全 AI 系 EF で同 pattern (= 1 import + 1 wrapper / **計 N EF を 2 line 修正のみ** / Codex 工数 30 min/EF).

### 4.2 `_shared/guardrail.ts` middleware (= 中核 / 新設)

```typescript
// supabase/functions/_shared/guardrail.ts

import type { ServeHandler } from "https://deno.land/std/http/server.ts";

export type GuardrailOptions = {
  toolName: string;
  scope: "user" | "admin" | "anon";
  publicSurface: boolean;        // true = X 投稿 / blog / news writer 等
};

export type GuardrailDecision =
  | { ok: true; redacted_input: unknown; categories: string[]; trace_id: string }
  | { ok: false; reason: "consent_missing" | "high_risk" | "kill_switch" | "moderation_timeout"; trace_id: string };

export function withGuardrail(handler: ServeHandler, opts: GuardrailOptions): ServeHandler {
  return async (req: Request) => {
    const trace_id = crypto.randomUUID();

    // (1) global kill switch (= AI-DEV #2 deny-by-default)
    if (await isKillSwitchOn()) {
      await logAudit(trace_id, opts.toolName, "kill_switch", null);
      return jsonError(503, "AI機能は一時停止中です", trace_id);
    }

    // (2) consent check
    if (opts.scope === "user" && !(await hasConsent(req, opts.toolName))) {
      await logAudit(trace_id, opts.toolName, "consent_missing", null);
      return jsonError(403, "consent screen 通過が必要です", trace_id);
    }

    // (3) input redact + moderation (= 5 categories: pii / toxicity / risk / public_post / hallucination)
    const body = await req.json();
    const redacted = await redactPii(body, /* presidio + regex fallback */);
    const moderation = await checkModeration(redacted, opts.publicSurface).catch(() => null);

    if (moderation === null) {
      // (4) circuit-breaker fallback (= AI-DEV #4)
      await alertSlack("moderation_timeout", trace_id, opts.toolName);
      await logAudit(trace_id, opts.toolName, "moderation_timeout", redacted);
      return jsonError(503, "安全検査がタイムアウトしました。しばらくお待ちください", trace_id);
    }

    if (moderation.high_risk) {
      // (5) high risk = human approval queue (= 受入 #3)
      await enqueueHumanApproval(trace_id, opts.toolName, redacted, moderation.categories);
      await logAudit(trace_id, opts.toolName, "high_risk", redacted, moderation);
      return jsonError(409, "管理者承認待ちです (= 約 24h 以内応答)", trace_id);
    }

    // (6) execute original handler with redacted input + trace_id
    const reqWithRedaction = new Request(req.url, {
      method: req.method,
      headers: { ...Object.fromEntries(req.headers), "x-trace-id": trace_id, "x-redacted": "1" },
      body: JSON.stringify(redacted),
    });
    const res = await handler(reqWithRedaction);

    // (7) public surface = double-gate (= 出力も moderation 必須)
    if (opts.publicSurface) {
      const outputModeration = await checkModeration(await res.clone().json(), true);
      if (outputModeration.high_risk) {
        await enqueueHumanApproval(trace_id, opts.toolName, await res.clone().json(), outputModeration.categories);
        await logAudit(trace_id, opts.toolName, "public_output_high_risk", null, outputModeration);
        return jsonError(409, "公開前の管理者承認待ちです", trace_id);
      }
    }

    // (8) success log
    await logAudit(trace_id, opts.toolName, "ok", redacted, moderation);
    return res;
  };
}

async function redactPii(input: unknown): Promise<unknown> {
  // Microsoft Presidio (self-host docker / port 5002) → categorical replace
  // fallback = regex (= email / phone JP+intl / マイナンバー 12 桁 / クレジットカード Luhn / 銀行口座 7 桁)
  // 戻り値 = `[REDACTED:email]` 等の token に置換した structure 同型 object
}

async function checkModeration(input: unknown, isPublic: boolean): Promise<{ high_risk: boolean; categories: string[] }> {
  // OpenAI Moderation API (= moderations endpoint / 無料 / metadata.disable_training=true)
  // + 公開面のみ Perspective API (= toxicity)
  // categories: pii_leak / toxicity / medical_risk / legal_risk / financial_risk / public_post_risk / hallucination_risk
  // high_risk = score > 0.85 (= 環境変数で調整可)
}
```

### 4.3 Schema 設計 (= 4 migration)

```sql
-- supabase/migrations/<YYYYMMDDHHMMSS>_create_pii_audit_log.sql

CREATE TABLE public.pii_audit_log (
  id bigserial PRIMARY KEY,
  trace_id uuid NOT NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,    -- null = anon (guest_id 別列)
  guest_id text,                                                 -- anon user 識別
  tool_name text NOT NULL,                                       -- "ai-hub" / "chatbot-hub" / "x-post-hub" 等
  decision text NOT NULL CHECK (decision IN (
    'ok','consent_missing','high_risk','kill_switch','moderation_timeout','public_output_high_risk'
  )),
  redaction_summary jsonb,                                       -- {"email":3,"phone":1} だけ / raw 不可
  moderation_score jsonb,                                        -- {"pii":0.92,"toxicity":0.12,...}
  api_error boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.pii_audit_log ENABLE ROW LEVEL SECURITY;

-- 本人のみ自分の audit を SELECT 可 (= 監査者すら raw 不可視 = redaction_summary categorical)
CREATE POLICY "pii_audit_owner_select" ON public.pii_audit_log
  FOR SELECT USING (auth.uid() = user_id);

-- service_role = INSERT only (= middleware から)
CREATE POLICY "pii_audit_service_insert" ON public.pii_audit_log
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

-- admin role = aggregate read 専用 (= raw 列 categorical のみ / view 経由)
CREATE INDEX pii_audit_trace ON public.pii_audit_log (trace_id);
CREATE INDEX pii_audit_user_time ON public.pii_audit_log (user_id, created_at DESC);
CREATE INDEX pii_audit_tool_decision ON public.pii_audit_log (tool_name, decision, created_at DESC);

-- 90 日 retention (= AI-DEV #5 memory)
CREATE OR REPLACE FUNCTION purge_pii_audit_old() RETURNS void
  LANGUAGE sql AS $$
    DELETE FROM public.pii_audit_log WHERE created_at < now() - INTERVAL '90 days';
  $$;
```

```sql
-- supabase/migrations/<YYYYMMDDHHMMSS>_create_pii_redaction_rules.sql

CREATE TABLE public.pii_redaction_rules (
  id bigserial PRIMARY KEY,
  category text NOT NULL CHECK (category IN (
    'email','phone_jp','phone_intl','my_number','credit_card','bank_account','jp_address','ip_address','custom'
  )),
  pattern text NOT NULL,                                  -- regex
  language text NOT NULL DEFAULT 'all' CHECK (language IN ('ja','en','all')),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pii_rule_unique UNIQUE (category, pattern, language)
);

-- migration 経由のみ INSERT 許可 (= 第 4 例から継承 / Manual SQL 禁止)
ALTER TABLE public.pii_redaction_rules ENABLE ROW LEVEL SECURITY;
CREATE POLICY "pii_rules_read_all" ON public.pii_redaction_rules FOR SELECT USING (is_active = true);
-- INSERT/UPDATE/DELETE は service_role + CI lint 経由のみ (= adhoc reject)

-- seed (= 別 migration で)
INSERT INTO public.pii_redaction_rules (category, pattern, language) VALUES
  ('email',        '[\w._%+-]+@[\w.-]+\.[A-Za-z]{2,}', 'all'),
  ('phone_jp',     '0\d{1,4}-?\d{1,4}-?\d{4}',          'ja'),
  ('phone_intl',   '\+\d{1,3}\s?\d{3,14}',              'all'),
  ('my_number',    '\b\d{12}\b',                         'ja'),     -- マイナンバー 12 桁
  ('credit_card',  '\b(?:\d{4}[-\s]?){3}\d{4}\b',       'all'),     -- + Luhn validation in code
  ('bank_account', '\b\d{4}-?\d{7}\b',                  'ja'),
  ('jp_address',   '(東京都|大阪府|京都府|北海道|.{2,3}県).{2,30}',  'ja'),
  ('ip_address',   '\b(?:\d{1,3}\.){3}\d{1,3}\b',       'all');
```

```sql
-- supabase/migrations/<YYYYMMDDHHMMSS>_create_pii_consent.sql

CREATE TABLE public.pii_consent (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tool_name text NOT NULL,                              -- "ai-hub" / "chatbot-hub" 等
  granted_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  scope jsonb NOT NULL DEFAULT '{"send_to_vendor":true,"public_surface":false}'::jsonb,
  PRIMARY KEY (user_id, tool_name)
);

ALTER TABLE public.pii_consent ENABLE ROW LEVEL SECURITY;
CREATE POLICY "pii_consent_owner" ON public.pii_consent
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 1 tap revoke (= scope=null + revoked_at で AI 呼出 全部 block)
```

```sql
-- supabase/migrations/<YYYYMMDDHHMMSS>_create_ai_global_kill_switch.sql

CREATE TABLE public.ai_global_kill_switch (
  id smallint PRIMARY KEY DEFAULT 1 CHECK (id = 1),     -- 1 row only
  enabled boolean NOT NULL DEFAULT true,
  reason text,
  toggled_by uuid REFERENCES auth.users(id),
  toggled_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.ai_global_kill_switch (id, enabled) VALUES (1, true);

ALTER TABLE public.ai_global_kill_switch ENABLE ROW LEVEL SECURITY;
CREATE POLICY "kill_switch_read_all" ON public.ai_global_kill_switch FOR SELECT USING (true);
-- WRITE は service_role + Sentinel role admin のみ (= incident escape hatch)
```

### 4.4 `ai-audit-hub` EF (= 受入 #4 / +1 EF)

```typescript
// supabase/functions/ai-audit-hub/index.ts (= 新規 EF / [EF-CAP-50] +1)

import { serve } from "https://deno.land/std/http/server.ts";

serve(async (req) => {
  const action = new URL(req.url).pathname.split("/").pop();
  switch (action) {
    case "summary":           return await handleSummary(req);              // /admin/ai-audit ページ
    case "approval-queue":    return await handleApprovalQueue(req);        // human approval queue
    case "approve":           return await handleApprove(req);              // 承認 → 元 EF 再呼出
    case "reject":            return await handleReject(req);               // 却下
    case "report-fp":         return await handleFalsePositiveReport(req);  // user 申告 (= 24h SLA)
    case "kill-switch":       return await handleKillSwitch(req);           // 緊急 disable
    case "export-my-data":    return await handleExport(req);               // GDPR / 個情法
    case "delete-my-data":    return await handleDelete(req);               // GDPR / 個情法
    default:                  return new Response("Not Found", { status: 404 });
  }
});

// handleSummary: pii_audit_log の 7 日 aggregate (= tool × decision × count)
// handleApprovalQueue: high_risk 判定 enqueue 済の queue list (admin only)
// handleApprove: admin 承認 → trace_id で元 EF 再呼出 (= bypass guardrail flag 付与)
// handleKillSwitch: Sentinel role のみ / `UPDATE ai_global_kill_switch SET enabled=false`
// handleExport: 自身の pii_audit_log + pii_consent + redaction_summary を JSON (= raw 不可視 維持)
// handleDelete: 30 日以内 user_id の audit log 全削除 (= GDPR)
```

`anomaly detection cron` = 既存 `daily-cron-hub` から `ai-audit-hub.summary` を読んで p99×3 超過時 Slack alert (= [EF-CAP-50] 中で +1 のみ).

### 4.5 admin-hub EF 拡張 (= aggregate read 委譲)

```typescript
// supabase/functions/admin-hub/index.ts (= 既存 EF / 拡張 1 endpoint)

case "/ai-audit-summary":
  // ai-audit-hub.summary を proxy / role gate のみ admin-hub が担当
  return await fetch(`${EF_BASE}/ai-audit-hub/summary`, { headers: { ...adminAuth(req) }});
```

### 4.6 UI 設計 (= Flutter 4 widget / Win Codex 実装 / Win Claude design ガイド)

#### 4.6.1 Consent Screen (= 初回 AI 機能利用前 / `lib/widgets/ai/ai_consent_screen.dart`)

```
┌─ AIConsentScreen (= modal / dismiss 不可 / OK まで AI 呼出 block) ─┐
│                                                                  │
│  🛡️  AI機能を使う前に                                              │
│                                                                  │
│  この機能では、あなたの入力を以下に送ります:                          │
│   ✓ Anthropic Claude (= chat内容)                                │
│   ✗ 学習データには使われません (= disable_training=true 確認済)      │
│                                                                  │
│  以下の情報は自動で伏せられます:                                    │
│   ・メールアドレス / 電話番号 / 住所 / クレジットカード番号           │
│   ・マイナンバー / 銀行口座 / IPアドレス                            │
│                                                                  │
│  公開投稿 (X / blog) は、追加で内容チェックを通過してから公開されます. │
│                                                                  │
│  [ 詳しく知る ]   [ 同意して始める ]    [ 同意しない ]               │
└──────────────────────────────────────────────────────────────────┘
```

= scope 単位 ON/OFF (= tool name 別 toggle / 後から変更可 = `/settings/ai-consent`).

#### 4.6.2 Redact Preview Modal (= 直前 modal / `lib/widgets/ai/redact_preview_modal.dart`)

```
┌─ RedactPreviewModal (= AI 呼出直前 / 検出時のみ表示) ─┐
│                                                    │
│  📝  この情報は伏せて送ります                          │
│                                                    │
│  あなたの入力:                                       │
│  「私の[REDACTED:email] と [REDACTED:phone_jp] に    │
│    [REDACTED:credit_card] で支払って...」           │
│                                                    │
│  検出: メール × 1 / 電話 × 1 / カード番号 × 1         │
│                                                    │
│  [ OK 伏せて送信 ]  [ Cancel ]  [ そのまま送る (= 監査記録) ]  │
└────────────────────────────────────────────────────┘
```

= 「そのまま送る」は audit log に override flag = true / 月次 dashboard に集計.

#### 4.6.3 `/admin/ai-audit` page (= 受入 #4 / `lib/pages/admin/ai_audit_page.dart`)

```
┌─ AiAuditPage ─┐
│ 直近 7 日: 計 8,231 invocation                       │
│  ✅ ok            7,892 (95.9%)                      │
│  🛑 high_risk        87 ( 1.1%) ← 承認 queue へ        │
│  ⏸️  consent_missing 142 ( 1.7%)                       │
│  ❌ moderation_timeout 12 ( 0.1%) ← 5xx alert          │
│  📛 kill_switch        0 ( 0.0%)                       │
│                                                       │
│ Top tool by reject:  blog-hub (32) / x-post-hub (28)  │
│                                                       │
│ [ Approval Queue (87) ] [ FP Reports (3) ] [ Kill ]   │
└───────────────────────────────────────────────────────┘
```

#### 4.6.4 False Positive Report Form (= modal 内 1 tap / `lib/widgets/ai/fp_report_button.dart`)

```
[このチェックは間違いだと思う] → 1 tap で trace_id + 自由記述 → ai-audit-hub.report-fp
```

= 24h SLA 応答 / 月次 改善 commit.

### 4.7 CI lint (= 受入 #1 補強 / `.github/workflows/migration-lint.yml` 拡張)

```yaml
- name: Reject manual pii_redaction_rules INSERT outside migration
  run: |
    ! git diff origin/main HEAD -- 'supabase/functions/**/*.ts' | \
      grep -E "INSERT INTO public\.pii_redaction_rules"
```

```yaml
- name: Require withGuardrail for AI invoking EFs
  run: |
    python scripts/guardrail_lint.py supabase/functions/
```

= AI SDK (= openai / anthropic / google) を import している EF が `withGuardrail` を import していない場合 fail.

## 5. 受入条件 mapping (= Issue #773 の 4 受入 → 本 spec section)

| 受入条件 | 対応 section |
|---|---|
| #1 AI呼び出しごとに監査ログが保存される | §4.1 (wrapper) + §4.2 (`logAudit`) + §4.3 (`pii_audit_log` schema) + §4.7 (CI lint) |
| #2 PII/不適切表現/公開投稿リスクのいずれかを検知できる | §4.2 (`redactPii` + `checkModeration`) + §4.3 (`pii_redaction_rules` seed) + 公開面 double-gate (§2.2 + §4.2 #7) |
| #3 高リスク判定時にユーザー確認または処理停止ができる | §4.2 #5 (`enqueueHumanApproval`) + §4.4 (`ai-audit-hub.approve/reject`) + §4.6.2 (Redact Modal 3 択) + Kill Switch (§4.3 + §4.4) |
| #4 管理画面または診断画面で直近のAI監査結果を確認できる | §4.4 (`ai-audit-hub.summary`) + §4.5 (admin-hub proxy) + §4.6.3 (`/admin/ai-audit` page) + §4.6.4 (FP report) |

## 6. Win Codex hand off scope (= 工数 14h 推定 / [EF-CAP-50] +1 / sensitive premium 適用)

### 6.1 実装ファイル一覧

#### Migrations (= 4 件 / 4h)
- [ ] `supabase/migrations/<ts>_create_pii_audit_log.sql` (= §4.3)
- [ ] `supabase/migrations/<ts>_create_pii_redaction_rules.sql` (= §4.3)
- [ ] `supabase/migrations/<ts>_seed_pii_redaction_rules.sql` (= §4.3 seed / 8 categories)
- [ ] `supabase/migrations/<ts>_create_pii_consent.sql` + `<ts>_create_ai_global_kill_switch.sql` (= §4.3 / 2 ファイル合算 1.5h)

#### Edge Functions (= +1 EF / 5h)
- [ ] `supabase/functions/_shared/guardrail.ts` (= §4.2 / 中核 middleware / 約 250 行 / 3h)
- [ ] `supabase/functions/ai-audit-hub/index.ts` (= §4.4 / 8 actions / 約 200 行 / 2h)
- [ ] `supabase/functions/admin-hub/index.ts` 拡張 (= §4.5 / 1 endpoint 追加 / 30 min)
- [ ] 既存 AI 系 EF への `withGuardrail` 適用 (= §4.1 / N EF × 30 min / N=5 想定で 2.5h)

#### Flutter Widgets (= 4 widget / 3.5h)
- [ ] `lib/widgets/ai/ai_consent_screen.dart` (= §4.6.1 / 1h)
- [ ] `lib/widgets/ai/redact_preview_modal.dart` (= §4.6.2 / 1h)
- [ ] `lib/pages/admin/ai_audit_page.dart` (= §4.6.3 / 1h)
- [ ] `lib/widgets/ai/fp_report_button.dart` (= §4.6.4 / 30 min)

#### CI / Lint (= 1.5h)
- [ ] `scripts/guardrail_lint.py` (= §4.7 / Python AST で `import withGuardrail` 確認 / 約 80 行 / 1h)
- [ ] `.github/workflows/migration-lint.yml` 拡張 (= §4.7 / 30 min)

#### Docs (= 0.5h / Win Claude territory だが Codex で incident runbook 起草)
- [ ] `docs/AI_GUARDRAIL_INCIDENT_RUNBOOK.md` (= Win Claude part 154+ で起草 / 本 spec scope 外)

### 6.2 [EF-CAP-50] self-check

- 現 EF 数: 49 (= 推定 / `docs/EDGE_FUNCTION_LIST.md` 参照)
- 本 spec 追加: +1 (`ai-audit-hub`)
- 本 spec 後: **50 ✅** (= cap 内 / 余裕 0)
- 既存 ai-hub / chatbot-hub / blog-hub 等は **拡張のみ** (= +0)

### 6.3 工数内訳 (= 14h / sensitive 12h baseline + 2h security boundary premium)

| 項目 | 工数 |
|---|---|
| Migrations × 4 | 4h |
| `_shared/guardrail.ts` | 3h |
| `ai-audit-hub` EF | 2h |
| 既存 EF wrapper 適用 × 5 | 2.5h |
| Flutter widget × 4 | 3.5h |
| CI lint | 1.5h |
| **合計** | **16.5h** ← 中央値 14h を上振れ recognition |

= sensitive 第 5 例工数 record 候補 (= 第 4 例 14h と同等). NOT to do 12 項目 + MUST do 12 項目 = sensitive history 最多 (= 第 1-4 例平均 9 項目).

### 6.4 適用原則 self-check (= sensitive 必須 7/7 + 8/8)

- ✅ PHILOSOPHY-22: 9/9 (= 自分株式会社の信頼資本 = 個人 data 保護 / 監査 trail)
- ✅ AI-DEV-23: 7/7 (= §2.4)
- ✅ AI-CHARACTER-24: 8/8 (= §2.3)
- ✅ MCP-AUTH-27: cross-link (= §2.5 / 第 4 例 #1577 と二重防御)
- ✅ IMBUE-25: 6+/7 (= mentor 感 / 透明性 / escape hatch)
- ✅ COLLAB-26: 6+/7 (= human-in-loop = approval queue)
- ✅ VIBE-30: 7/7 (= 4-/7 ゲート防衛で公開面 double-gate)

= sensitive 必須ゲート全達成.

## 7. 関連 docs / cross-link

- 本 spec の operator ritual: [`docs/DESIGN_SPEC_TEMPLATE.md`](DESIGN_SPEC_TEMPLATE.md)
- 抽象 layer / patterns: [`docs/DESIGN_SPEC_PATTERNS.md`](DESIGN_SPEC_PATTERNS.md) Ch3 (= sensitive 4 領域 + 共通 4/4 / 本 spec で 5 領域に拡張)
- sensitive 第 4 例 (= 外部 boundary): [`docs/MCP_AUTH_HARDENING_SPEC.md`](MCP_AUTH_HARDENING_SPEC.md)
- sensitive 第 1 例 (= 健康 data): [`docs/MENTAL_HEALTH_RISK_SPEC.md`](MENTAL_HEALTH_RISK_SPEC.md)
- sensitive 第 2 例 (= AI 内部状態): [`docs/AI_DESPERATION_DETECTION_SPEC.md`](AI_DESPERATION_DETECTION_SPEC.md)
- sensitive 第 3 例 (= high-stakes persona): [`docs/ROBUST_AI_PERSONA_SPEC.md`](ROBUST_AI_PERSONA_SPEC.md)
- 原則: [`PHILOSOPHY.md`](PHILOSOPHY.md) / [`AI_DEV_PRINCIPLES.md`](AI_DEV_PRINCIPLES.md) / [`AI_CHARACTER_PRINCIPLES.md`](AI_CHARACTER_PRINCIPLES.md) / [`MCP_AUTH_SECURITY_PRINCIPLES.md`](MCP_AUTH_SECURITY_PRINCIPLES.md) / [`IMBUE_PATTERNS.md`](IMBUE_PATTERNS.md) / [`COLLAB_AI_PATTERNS.md`](COLLAB_AI_PATTERNS.md) / [`VIBE_CODING_PRINCIPLES.md`](VIBE_CODING_PRINCIPLES.md)

## 8. PATTERNS.md Ch3 第 5 領域更新依頼 (= follow-up)

`docs/DESIGN_SPEC_PATTERNS.md` Ch3.2 / 3.3 / 3.4 を 4 領域 → 5 領域に拡張する follow-up entry:

| # | 例 | 領域 | 主 NOT to do | 共通項 |
|---|---|---|---|---|
| 5 | #773 part 154 (= 本 spec) | **個人 data × security boundary 二重** | PII raw 送信禁止 / 学習 data 流用禁止 / silent redact 禁止 / 公開 fail silent 禁止 / 管理者 raw 閲覧禁止 | 4 共通項全 hit + **「内部 boundary」追加軸** |

= part 155+ で `DESIGN_SPEC_PATTERNS.md` 改訂 (= 12 spec 突破 trigger 達成).
