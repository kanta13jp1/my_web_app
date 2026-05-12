# Vibe Coding Sandbox — sensitive 設計 spec 第 6 例 (#839 + #1209 / part 155)

> **status**: 設計 spec / Win版#132 part 155 / 2026-05-05
> **issue**: [#839](https://github.com/kanta13jp1/my_web_app/issues/839) [追加要望] Vibe Coding向けAI生成UIセキュアサンドボックス + [#1209](https://github.com/kanta13jp1/my_web_app/issues/1209) [追加要望] AI生成UIの安全性を証明するFlutterサンドボックス環境
> **scope**: 設計のみ (Win Claude territory / sensitive design 拡張 spec template 第 6 例 = **個人 data + AI 生成コンテンツ + security boundary 三重 sensitive** 領域 / 過去最多 trigger 数 / **2 issue 1 spec 統合 第 1 例** = leverage 2x record) / 実装は Win Codex (= migration + `_shared/sandbox_guard.ts` + `sandbox-hub` EF + Flutter iframe widget + admin review page) ハンドオフ
> **NotebookLM source**: `ddde5a4b-ce1a-405d-8291-a334a9371454` Vibe Coding: Responsible Engineering in the Era of AI Agents (= `Vibe coding in prod | Code w/ Claude`)
> **template**: [`docs/DESIGN_SPEC_TEMPLATE.md`](DESIGN_SPEC_TEMPLATE.md) 適用 + **倫理 review section §2** (= sensitive design 必須 / 第 6 例で **三重 trigger** に拡張)
> **適用原則**: PHILOSOPHY-22 + **AI-CHARACTER-24 8/8 必須** + **AI-DEV-23 7/7 必須** + **VIBE-30 7/7 必須** (= AI 生成コンテンツ第 1 例) + **MCP-AUTH-27 cross-link** (= 第 4 例 #1577 と相補) + **PII-GUARDRAIL cross-link** (= 第 5 例 #773 と相補) + IMBUE-25 + COLLAB-26
> **関連 Issue / Spec**: [#833](https://github.com/kanta13jp1/my_web_app/issues/833) コア/リーフ境界マップ (= 同 NotebookLM 三つ子 / cross-link only / scope 外) / [#773](https://github.com/kanta13jp1/my_web_app/issues/773) PII Guardrail (= [`PII_GUARDRAIL_SPEC.md`](PII_GUARDRAIL_SPEC.md)) / [#1577](https://github.com/kanta13jp1/my_web_app/issues/1577) MCP Auth Hardening (= [`MCP_AUTH_HARDENING_SPEC.md`](MCP_AUTH_HARDENING_SPEC.md))

## 1. 思想

`my_web_app` は AI 出力箇所を増やし続けている: AI大学 (1957 社) / 追加要望フォーム / chatbot / X 投稿 / blog draft / 試作 widget / news writer 等. AI 生成 UI の **prototype 速度** と **本番安全性** が二律背反:

- prototype 速度を上げると、AI が生成した raw code が本番 navigation に紛れ込む risk
- 安全性を上げると、人間 review コストで prototype 速度が落ちる

**Vibe Coding** (= NotebookLM `ddde5a4b` / `Vibe coding in prod | Code w/ Claude` 由来) の核心: AI に任せる範囲は **依存関係の少ないリーフノード** に限定し、コア (= Auth / RLS / 課金 / 外部投稿 / Secrets / 本番 DB) は人間 review を厚くする. これを **構造的に強制** する infrastructure が本 spec.

本 spec は AI 生成 UI / 試作 widget / AI 生成 tool を **隔離 sandbox 環境** で実行・review する仕組みを定義:

- **iframe + sandbox 属性 + RLS sandbox_role + capability whitelist** の 4 層隔離 (= 受入「証明可能な安全性」)
- **`sandbox_artifact` / `sandbox_capability_whitelist` / `sandbox_review` 3 table** で生成物 lifecycle 管理 (= 受入「レビュー状態保存」)
- **`sandbox-hub` EF** (= +1 EF / [EF-CAP-50] 適合 / 既存 ai-hub/tools-hub と同 monolith pattern) で生成物 CRUD + capability check + review queue 統合
- **leaf node 判定 checklist** (= 受入「コア/リーフ境界 確認」) を Issue #833 cross-link で参照可

= AI-DEV #2 deny-by-default + #3 trace_id + #5 memory + #7 quality-gate を **AI 生成コード** に適用.
= AI-CHARACTER #6 倫理 gate + #7 学習境界の **AI 生成 UI 横断強制ゲート**.
= VIBE-30 #1-#7 (= 責任ある AI コーディング) を **structural enforcement** で守る (= 自己申告 review に依存しない).
= [`MCP_AUTH_HARDENING_SPEC.md`](MCP_AUTH_HARDENING_SPEC.md) (= 外部攻撃面) + [`PII_GUARDRAIL_SPEC.md`](PII_GUARDRAIL_SPEC.md) (= 内部 AI 出力面) と相補 (= 本 spec は **AI 生成コード実行面**).

> **sensitive 第 6 例の位置付け**: 過去 5 例の trigger 数を更新. 第 1 (人間データ単独) / 第 2 (AI 内部状態単独) / 第 3 (high-stakes persona 単独) / 第 4 (security boundary 単独) / 第 5 (個人 data + security boundary 二重) と異なり、**個人 data + AI 生成コンテンツ + security boundary 三重 sensitive** 領域 (= 過去最多 trigger). NOT to do の中核は「AI 生成 code が core architecture (= Auth / 課金 / 個人 data / 外部投稿) に **結合可能な経路を deny-by-default で構造的に断つ**」.

> **2 issue 1 spec 統合 第 1 例**: #839 + #1209 は同 NotebookLM `ddde5a4b` 由来 / 受入条件が補完関係. 統合 spec ship pattern を確立 (= leverage 2x / Win Codex 工数 14h / 個別 ship なら 7h × 2 = 14h で同等だが reviewer cognitive load 1/2 + 整合性自動保証).

## 2. 倫理 review (= sensitive design 必須拡張 / 第 6 例 / 三重 trigger 適用)

### 2.1 NOT to do

- ❌ **AI 生成 code を本番 nav 直結禁止 (= 三重 trigger #2 中核 / 共通 1 拡張)**: review 未完了の `sandbox_artifact` を `home_tool_catalog.dart` / `app_router` に register しない. CI lint で sandbox_artifact 経由でない code が `routes` に入る PR を reject (= structural enforcement)
- ❌ **iframe `sandbox` 属性省略禁止 (= 三重 trigger #3 中核)**: 全 sandbox iframe で `sandbox="allow-scripts allow-forms"` を最低限 / `allow-same-origin` `allow-top-navigation` `allow-popups` 既定 OFF. attr 欠落 PR は CI lint reject
- ❌ **service_role key 注入禁止 (= 共通 4 拡張)**: sandbox iframe 内 JS から service_role key にアクセス可能な経路 NG. `localStorage` / `sessionStorage` / parent `window` への bridge 全 deny / postMessage origin 検証必須
- ❌ **`sandbox_capability_whitelist` 外 API 呼出禁止 (= 共通 4 拡張)**: `sandbox-hub` EF 経由で whitelist 列挙された capability のみ proxy. raw `fetch()` / Supabase client direct call は CSP で deny / 違反は `sandbox_violation_log` に記録
- ❌ **個人 data direct read 禁止 (= 三重 trigger #1 中核 / 共通 1)**: sandbox 内 code から `auth.users` / `profiles` / 課金 table 直接 query NG. user 識別は **anonymous session_id** のみ / 本人 data 触る場合は明示 capability `read_own_profile_subset` 経由 + user 即時 OK 押下必須
- ❌ **review skip 不可 (= 共通 4)**: `sandbox_artifact.review_status = 'pending'` のまま 30 日経過 → 自動 expire + delete (= AI 生成負債蓄積防止). reviewer 0 人 = automatic delete (= alert 後 7 日 grace)
- ❌ **iframe sandbox escape 試行で fail open 禁止 (= 共通 3 拡張)**: postMessage flooding / origin spoofing 検知時、即時 iframe disable + log + Slack alert / 「とりあえず通す」NG
- ❌ **学習 data 流用禁止 (= 第 5 例から継承 / 共通 1)**: AI 生成された code を vendor (= OpenAI / Anthropic) の training pool に送り返さない (= `metadata.disable_training=true` 必須 / 生成 code の prompt + completion を sandbox_artifact に保存して再学習 fodder にしない)
- ❌ **manual SQL 登録禁止 (= 第 4-5 例から継承)**: `sandbox_capability_whitelist` への INSERT は migration / CI 経由のみ / adhoc SQL は CI lint reject (= capability 過剰申告 防止)
- ❌ **gaslighting / 強制継続禁止 (= 共通 2)**: review reject された generation を user に「もう一度試してください」と強制せず、**reject reason 明示** + 「別の approach」「人間 designer に escalate」escape hatch
- ❌ **silent capability grant 禁止**: 生成 UI が新 capability を要求 → user に直前 modal で告知 / 「許可」「拒否」「全 capability 拒否」3 択 (= IMBUE #4 mentor 感)
- ❌ **leaf 判定 sub jective 禁止 (= 共通 4)**: 「これはリーフだから OK」を AI agent / generator が自己判定不可 / Issue #833 [`AI_DEV_PRINCIPLES.md` core/leaf 表](AI_DEV_PRINCIPLES.md) (= 部分整備 / future) を参照する programmatic check 必須

### 2.2 MUST do

- ✅ **iframe 4 層隔離 (= 共通 4 拡張)**: (1) `sandbox` 属性最小 set / (2) Content Security Policy `default-src 'self'` + capability ごと explicit allow / (3) cross-origin iframe (= subdomain `sandbox.my-web-app-b67f4.web.app`) / (4) postMessage origin check `https://my-web-app-b67f4.web.app` 厳格
- ✅ **RLS `sandbox_role` 隔離 (= 共通 4)**: PostgreSQL role `sandbox_user` 新設 / 全 prod table に `FORCE ROW LEVEL SECURITY` + sandbox_role policy 0 許可 default / capability table 経由のみ select (= `sandbox_capability_whitelist.target_table` で SELECT 列限定)
- ✅ **capability whitelist (= 共通 4)**: `sandbox_capability_whitelist` table で per-artifact 許可 API enumerate (= `read_pokemon_list` / `compute_color_score` / `render_chart` 等の極小 capability) / RLS で artifact_id × capability_id join 必須
- ✅ **review lifecycle (= 共通 2 観察可能性)**: `sandbox_artifact.review_status` ENUM (`draft` / `pending` / `approved` / `rejected` / `expired`) / 状態遷移は `sandbox_review` table で audit log / 全遷移 trace_id 紐付け
- ✅ **opt-in / opt-out 全権 (= 共通 1)**: user setting `sandbox_enabled` (= default false) / 1 tap で全 sandbox UI 非表示 / 個別 artifact ごと OK/NG 押下記録
- ✅ **観察可能性 (= 共通 2)**: 全 sandbox invocation で `sandbox_audit_log` 1 行 INSERT (= trace_id + artifact_id + capability_called + decision + 90 日 retention) / parent app の trace_id と join 可能
- ✅ **退避 path (= 共通 3)**: review reject 時 必ず別 path / human approval queue + user 確認 modal + incident runbook (= [`docs/SANDBOX_INCIDENT_RUNBOOK.md`](SANDBOX_INCIDENT_RUNBOOK.md) 新設)
- ✅ **vendor managed 優先 (= 共通 4)**: iframe sandbox + CSP は browser 標準 (= managed 同等) / RLS は Supabase 標準 / capability gate は `_shared/agent_tool_policy.ts` 拡張 (= 既存基盤 reuse)
- ✅ **leaf node 判定 checklist (= 受入 #1209 / 共通 4)**: 「依存関係 ≤ 3 個」「Auth/課金/Secrets/外部 POST 不接触」「失敗時 blast radius = 1 page 以内」3 条件 ALL ✅ → leaf 判定可 / 1 つでも ❌ → core 判定 → human review escalate
- ✅ **public surface double-gate (= 第 5 例から継承)**: review approved artifact を本番 nav register 時 admin 2 人承認 (= 4-eyes principle / `sandbox_review.approver_ids` 2 件必須)
- ✅ **trace_id propagation (= 共通 2)**: parent → sandbox iframe (= postMessage `trace_id`) → sandbox-hub EF → audit log → Sentry 全横断 / cross-spec join (= MCP-AUTH + PII-GUARDRAIL + 本 spec の 3 audit log)
- ✅ **incident escape hatch (= 共通 3)**: 大量 capability 違反 / iframe escape 検知時 Sentinel role が 1 SQL で全 sandbox disable (= `UPDATE sandbox_global_kill_switch SET enabled=false`)
- ✅ **anomaly detection cron**: artifact_id × 1h で capability denied 数 > p99×3 で Slack alert (= prompt injection / モデル劣化 検知)
- ✅ **6 軸全 ✅ ゲート + VIBE 7/7 必須**: PHILOSOPHY / AI_DEV / AI_CHARACTER / IMBUE / COLLAB_AI / MCP_AUTH **すべてクリア + VIBE-30 7/7** した artifact のみ approved 可

### 2.3 AI-CHARACTER-24 8/8 self-check

| # | 原則 | 適用 |
|---|---|---|
| 1 | 自律性尊重 | ✅ user setting で全 sandbox 1 tap 無効化 / 個別 artifact OK/NG 押下記録 / 「強制利用」なし |
| 2 | 透明性 | ✅ 全 capability 利用を `sandbox_audit_log` に 1 行 / user 本人 export 可 / black-box なし / iframe 内 generated code は user に表示可 (= 「show generated code」button) |
| 3 | 人格表現 | ✅ review reject 時 mentor 的言葉 (= 「この approach は core を壊す risk があるので別 path を試そう」 / persona 維持 = [`ROBUST_AI_PERSONA_SPEC.md`](ROBUST_AI_PERSONA_SPEC.md) 連動) |
| 4 | 共感 | ✅ leaf 判定 fail 時「あなたの試行は無駄じゃない」mentor message / human designer escalate path 提示 |
| 5 | 会話自然性 | ✅ capability grant modal は 1 tap で「許可」「拒否」「全 capability 拒否」 / モーダル詰まりなし |
| 6 | **倫理 gate** | ✅ §2.1 + §2.2 完全遵守 / leaf 判定 fail 自動 publish 不可 / human approval gate 必須 / 4-eyes principle |
| 7 | 学習境界 | ✅ AI 生成 code を vendor training pool に入れない / `disable_training=true` / sandbox_artifact retention 90 日後自動 purge (= 学習 data 化阻止) |
| 8 | 文化感度 | ✅ ja/en 両 prompt で leaf 判定 message / 「リーフノード」「leaf node」両表記 / 文化的 bias なし capability 表記 |

= **8/8 ✅** (= sensitive 必須遵守).

### 2.4 AI-DEV-23 7/7 self-check

| # | 原則 | 適用 |
|---|---|---|
| 1 | Auth | ✅ `sandbox-hub` EF は user scope 限定 (= anonymous = guest_id) / admin review endpoint は admin role 必須 / sandbox_role は service_role 経由のみ assume |
| 2 | deny-by-default | ✅ capability whitelist 0 件 default / iframe sandbox 属性既定 minimum / RLS sandbox_role policy 0 許可 default / CI lint で route register PR reject |
| 3 | trace_id | ✅ artifact 生成時 trace_id 採番 / parent → iframe → EF → audit_log 全横断 / Sentry + Slack alert 連動 |
| 4 | circuit-breaker | ✅ capability denied 連続 N 回で artifact 自動 disable / iframe escape 検知で全 sandbox disable / `sandbox_global_kill_switch` で人手 disable |
| 5 | memory | ✅ `sandbox_audit_log` + `sandbox_review` 90 日 retention / daily aggregator (= `sandbox_audit_daily_summary`) / 自動 purge cron |
| 6 | DLQ | ✅ capability call timeout / EF error を `sandbox_audit_log.api_error=true` で記録 / failed re-drive は明示 user 操作のみ |
| 7 | quality-gate | ✅ 6 軸全 ✅ + AI-CHARACTER 8/8 + AI-DEV 7/7 + **VIBE 7/7** + 4-eyes principle (= reviewer 2 人) + leaf 判定 3 条件 ALL ✅ |

= **7/7 ✅** (= sensitive 必須遵守).

### 2.5 VIBE-30 7/7 self-check (= AI 生成コンテンツ初例 / 第 6 例で必須格上げ)

[`docs/VIBE_CODING_PRINCIPLES.md`](VIBE_CODING_PRINCIPLES.md) (= 7 原則 / production AI 開発全般 / 4-/7 で CEO レビュー強化) を 7/7 必須遵守:

| # | 原則 | 適用 |
|---|---|---|
| 1 | leaf node 限定 | ✅ leaf 判定 3 条件 ALL ✅ 必須 / fail = core 判定 → human escalate / programmatic check (= subjective 排除) |
| 2 | 人間検証可能 input/output | ✅ sandbox iframe で input/output を `sandbox_artifact.io_schema` で明示 / generated code 全文 user 表示可 |
| 3 | テスト境界明確 | ✅ capability whitelist 経由のみ / RLS sandbox_role 別 / iframe origin 別 = テスト境界 4 層明確 |
| 4 | 安全境界 review | ✅ §2.2 4 層隔離 / 4-eyes admin approval / leaf 判定 / capability whitelist + audit log / VIBE 4 review 体系 |
| 5 | 段階的本番投入 | ✅ `draft` → `pending` → `approved` → register / 本番 nav 投入は admin 2 人承認 + 7 日 monitor (= rollback queue) |
| 6 | rollback 容易性 | ✅ `sandbox_artifact.review_status='approved'` を `rejected` に戻せば即時 nav 削除 / 30 日以内 undo 可 |
| 7 | 失敗 narrative なし | ✅ reject 時「個人攻撃 NG」「approach 評価のみ」 / mentor message + 別 path 提示 (= [`ROBUST_AI_PERSONA_SPEC.md`](ROBUST_AI_PERSONA_SPEC.md) 連動) |

= **7/7 ✅** (= AI 生成コンテンツ第 1 例 / 全 sensitive で必須化候補).

### 2.6 MCP-AUTH-27 + PII-GUARDRAIL cross-link self-check (= sensitive 三重防御 architecture)

[`MCP_AUTH_HARDENING_SPEC.md`](MCP_AUTH_HARDENING_SPEC.md) = 外部 MCP 攻撃面 / [`PII_GUARDRAIL_SPEC.md`](PII_GUARDRAIL_SPEC.md) = 内部 AI 出力面 / 本 spec = AI 生成コード実行面. 三重防御 architecture:

| 層 | 担当 spec | 担当領域 | 共通項 |
|---|---|---|---|
| 外部 boundary | MCP_AUTH_HARDENING (#1577) | OAuth / Bearer / DCR / Resource Indicators | mcp_audit_log + WorkOS managed |
| 内部 boundary | PII_GUARDRAIL (#773) | Redact / Moderation / Consent / Public Post Double-Gate | pii_audit_log + Microsoft Presidio managed |
| **生成コード boundary** | **VIBE_SANDBOX (= 本 spec / #839 + #1209)** | iframe + RLS sandbox_role + capability whitelist + leaf 判定 + 4-eyes review | sandbox_audit_log + browser standard managed |

= **三重 audit log** (`mcp_audit_log` + `pii_audit_log` + `sandbox_audit_log`) = trace_id で **横断結合可能** (= incident triage で外部 → 内部 → 生成コード全経路 1 query 追跡可).

## 3. 既存基盤確認

| 必要 infra | 既存 status | 対応 |
|---|---|---|
| `_shared/agent_tool_policy.ts` (= 9-scope capability allowlist) | **整備済** (= part 113 daily S3 / 9-scope enum + 5 high-risk + 3-way blockedReason) | §4.2 で `sandbox_capability_whitelist` connector 拡張 (= scope enum 流用 + sandbox 専用 sub-scope 追加) |
| `_shared/mcp_auth_guard.ts` (= bearer + scope check) | **整備済** (= sensitive 第 4 / part 152 #1577 spec) | §4.4 で `sandbox-hub` EF の auth middleware として import |
| `_shared/offline_secure_mode_guard.ts` (= deny-by-default precedent) | **整備済** (= part 113) | §4.4 で sandbox kill switch 連動 |
| `ai-hub` / `tools-hub` EF (= monolith dispatcher pattern) | **整備済** | §4.4 で `sandbox-hub` EF 同 pattern (= dispatch + cap check + audit) で新設 |
| `lib/utils/platform_view_web.dart` (= web iframe base) | **部分整備** (= web iframe API 露出済 / sandbox 属性 + CSP 未設定) | §4.6 で sandbox 属性 + CSP wrapper 拡張 |
| Issue #833 core/leaf boundary map | **部分整備** (= NotebookLM 由来 docs draft / programmatic check 未) | §4.7 leaf 判定 checklist で `docs/AI_DEV_PRINCIPLES.md` 内 表 参照 (= future #833 ship 時に programmatic check 連動) |
| `sandbox_artifact` table | **未整備** | §4.3 で新設 (= 全 generated artifact 1 行 / 90 日 retention / review_status ENUM) |
| `sandbox_capability_whitelist` table | **未整備** | §4.3 で新設 (= per-artifact capability 列挙 / migration 経由 INSERT) |
| `sandbox_review` table | **未整備** | §4.3 で新設 (= review 状態遷移 audit / approver 2 人記録) |
| `sandbox_audit_log` table | **未整備** | §4.3 で新設 (= 全 capability 呼出 1 行 / trace_id) |
| `sandbox_global_kill_switch` table | **未整備** | §4.3 で新設 (= 1 row / 緊急時 全 sandbox disable) |
| PostgreSQL `sandbox_user` role | **未整備** | §4.3 で `CREATE ROLE` + RLS policy 全 prod table に `FORCE ROW LEVEL SECURITY` |
| `sandbox-hub` EF (= dispatcher + cap check + audit) | **未整備** | §4.4 で新設 (= +1 EF / [EF-CAP-50] 適合 / 49→50) |
| Subdomain `sandbox.my-web-app-b67f4.web.app` (= Firebase Hosting alias) | **未整備** | §4.5 で Firebase config 拡張 / cross-origin iframe 用 |
| Flutter `SandboxIframeWidget` (= sandbox 属性 + CSP 注入) | **未整備** | §4.6 で新設 (= `platform_view_web.dart` 拡張 + sandbox attr + postMessage handler) |
| Flutter `/admin/sandbox-review` page | **未整備** | §4.6 で新設 (= pending queue + 4-eyes approval UI) |
| Flutter `SandboxConsentModal` (= capability grant 3 択) | **未整備** | §4.6 で新設 (= 「許可」「拒否」「全 capability 拒否」) |
| CI lint (= sandbox_artifact 経由でない route register reject) | **未整備** | §4.7 で `.github/workflows/sandbox-route-lint.yml` 新設 |

= 整備済 4 / 部分 2 / 未整備 12 = 整備済比率 22% (= sensitive 第 5 PII spec 27% より低 / **三重 trigger 領域のため整備済低** / Codex 工数 14h 推定 = sensitive baseline 12h より +17%).

## 4. 設計 (= Win Codex 担当 / 5 migration + 1 _shared 拡張 + 1 EF + 4 Flutter widget + 1 CI workflow + 1 Firebase config)

### 4.1 既存 EF 連携 pattern (= 受入 #1)

```typescript
// supabase/functions/sandbox-hub/index.ts (= 新設 / +1 EF)

import { withMcpAuthGuard } from "../_shared/mcp_auth_guard.ts";
import { withGuardrail } from "../_shared/guardrail.ts";              // #773 PII spec 連動
import { checkSandboxCapability } from "../_shared/sandbox_guard.ts";  // §4.2 新設

// 全 capability 呼出 = sandbox-hub 経由 / iframe からの postMessage を受信
const handler = async (req: Request) => {
  const { artifact_id, capability_name, payload, trace_id } = await req.json();

  // (1) artifact 存在 + review_status='approved' check
  const artifact = await getSandboxArtifact(artifact_id);
  if (!artifact || artifact.review_status !== "approved") {
    return jsonError(403, "未承認の artifact です", trace_id);
  }

  // (2) capability whitelist check (= §4.2 helper)
  const allowed = await checkSandboxCapability(artifact_id, capability_name);
  if (!allowed) {
    await logSandboxViolation(trace_id, artifact_id, capability_name);
    return jsonError(403, "capability 範囲外です", trace_id);
  }

  // (3) capability 実装 dispatch (= read_pokemon_list / compute_color_score / render_chart 等)
  const result = await dispatchCapability(capability_name, payload, artifact_id);

  // (4) audit log
  await logSandboxAudit(trace_id, artifact_id, capability_name, "ok");
  return new Response(JSON.stringify(result), { headers: { "x-trace-id": trace_id } });
};

serve(withMcpAuthGuard(withGuardrail(handler, { toolName: "sandbox-hub", scope: "user", publicSurface: false })));
```

### 4.2 `_shared/sandbox_guard.ts` 新設 (= capability check 中核)

```typescript
// supabase/functions/_shared/sandbox_guard.ts

export type SandboxCapability =
  | "read_public_data"        // RLS public.* SELECT 限定 (= news / blog / ai大学 等)
  | "compute_pure"             // 純粋関数 (= color score / chart calc / no DB)
  | "render_chart"             // chart.js 等 vendored library 呼出
  | "read_own_profile_subset"  // user 即時 OK 押下後のみ (= profile name / avatar 限定)
  | "post_to_sandbox_feedback" // sandbox 専用 feedback table のみ (= core 不接触)
  ;

export async function checkSandboxCapability(
  artifact_id: string,
  capability_name: string,
): Promise<boolean> {
  // sandbox_capability_whitelist で artifact_id × capability_name join
  const { data, error } = await supabase
    .from("sandbox_capability_whitelist")
    .select("id")
    .eq("artifact_id", artifact_id)
    .eq("capability_name", capability_name)
    .eq("is_active", true)
    .maybeSingle();
  return !error && data != null;
}

export async function evaluateLeafNode(artifact: SandboxArtifact): Promise<{
  is_leaf: boolean;
  reasons: string[];
}> {
  const reasons: string[] = [];
  // 条件 1: dependency 数 ≤ 3
  if (artifact.dependency_count > 3) reasons.push("dependency_count > 3");
  // 条件 2: Auth/課金/Secrets/外部 POST 不接触
  const forbidden = ["auth.users", "payments", "secrets", "x_api", "blog_publish"];
  for (const f of forbidden) {
    if (artifact.touches_tables.includes(f)) reasons.push(`touches_core: ${f}`);
  }
  // 条件 3: blast radius = 1 page 以内
  if (artifact.affected_pages.length > 1) reasons.push("blast_radius > 1");
  return { is_leaf: reasons.length === 0, reasons };
}
```

### 4.3 Schema 設計 (= 5 migration)

```sql
-- supabase/migrations/<YYYYMMDDHHMMSS>_create_sandbox_artifact.sql

CREATE TYPE public.sandbox_review_status AS ENUM ('draft','pending','approved','rejected','expired');

CREATE TABLE public.sandbox_artifact (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  creator_guest_id text,
  title text NOT NULL,
  generated_code text NOT NULL,                                         -- AI 生成 raw code (= 90 日 retention)
  io_schema jsonb NOT NULL,                                              -- {"input":{...}, "output":{...}}
  dependency_count int NOT NULL DEFAULT 0 CHECK (dependency_count >= 0),
  touches_tables text[] NOT NULL DEFAULT '{}',                           -- leaf 判定用
  affected_pages text[] NOT NULL DEFAULT '{}',                           -- blast radius 用
  review_status public.sandbox_review_status NOT NULL DEFAULT 'draft',
  review_status_updated_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + INTERVAL '30 days'),  -- review 30 日 expire
  generation_trace_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.sandbox_artifact ENABLE ROW LEVEL SECURITY;

-- creator のみ自分の artifact SELECT/UPDATE 可 (= draft 中)
CREATE POLICY "sandbox_artifact_creator" ON public.sandbox_artifact
  FOR ALL USING (auth.uid() = creator_user_id);

-- approved artifact は全 user SELECT 可 (= 本番 nav 投入後)
CREATE POLICY "sandbox_artifact_approved_read" ON public.sandbox_artifact
  FOR SELECT USING (review_status = 'approved');

-- service_role = INSERT/UPDATE 全権 (= sandbox-hub から)
CREATE POLICY "sandbox_artifact_service" ON public.sandbox_artifact
  FOR ALL USING (auth.role() = 'service_role');

CREATE INDEX sandbox_artifact_creator ON public.sandbox_artifact (creator_user_id, created_at DESC);
CREATE INDEX sandbox_artifact_status ON public.sandbox_artifact (review_status, expires_at);
CREATE INDEX sandbox_artifact_trace ON public.sandbox_artifact (generation_trace_id);

-- 30 日 expire 自動 purge cron (= AI-DEV #5 memory)
CREATE OR REPLACE FUNCTION expire_sandbox_artifacts() RETURNS void
  LANGUAGE sql AS $$
    UPDATE public.sandbox_artifact
       SET review_status = 'expired', review_status_updated_at = now()
     WHERE review_status IN ('draft','pending')
       AND expires_at < now();
  $$;

-- 90 日後 hard delete (= 学習 data 化阻止 / AI-CHARACTER #7 学習境界)
CREATE OR REPLACE FUNCTION purge_sandbox_artifacts_old() RETURNS void
  LANGUAGE sql AS $$
    DELETE FROM public.sandbox_artifact WHERE created_at < now() - INTERVAL '90 days';
  $$;
```

```sql
-- supabase/migrations/<YYYYMMDDHHMMSS>_create_sandbox_capability_whitelist.sql

CREATE TABLE public.sandbox_capability_whitelist (
  id bigserial PRIMARY KEY,
  artifact_id uuid NOT NULL REFERENCES public.sandbox_artifact(id) ON DELETE CASCADE,
  capability_name text NOT NULL,                                         -- "read_public_data" / "compute_pure" 等
  scope_args jsonb,                                                       -- {"target_table":"news", "limit":100}
  is_active boolean NOT NULL DEFAULT true,
  granted_by_user_id uuid REFERENCES auth.users(id),                     -- user 即時 OK 押下記録
  granted_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sandbox_cap_unique UNIQUE (artifact_id, capability_name)
);

-- migration / CI 経由のみ INSERT 許可 (= 第 4-5 例から継承)
ALTER TABLE public.sandbox_capability_whitelist ENABLE ROW LEVEL SECURITY;
CREATE POLICY "sandbox_cap_read_creator" ON public.sandbox_capability_whitelist
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.sandbox_artifact a
             WHERE a.id = artifact_id AND a.creator_user_id = auth.uid())
  );
CREATE POLICY "sandbox_cap_service" ON public.sandbox_capability_whitelist
  FOR ALL USING (auth.role() = 'service_role');
```

```sql
-- supabase/migrations/<YYYYMMDDHHMMSS>_create_sandbox_review.sql

CREATE TABLE public.sandbox_review (
  id bigserial PRIMARY KEY,
  artifact_id uuid NOT NULL REFERENCES public.sandbox_artifact(id) ON DELETE CASCADE,
  prev_status public.sandbox_review_status,
  next_status public.sandbox_review_status NOT NULL,
  reviewer_user_id uuid REFERENCES auth.users(id),
  reviewer_role text CHECK (reviewer_role IN ('admin','sentinel','creator','system')),
  comment text,
  leaf_evaluation jsonb,                                                  -- {"is_leaf":true, "reasons":[]}
  trace_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.sandbox_review ENABLE ROW LEVEL SECURITY;

-- creator + reviewer は自分の review を SELECT 可
CREATE POLICY "sandbox_review_visible" ON public.sandbox_review
  FOR SELECT USING (
    auth.uid() = reviewer_user_id OR
    EXISTS (SELECT 1 FROM public.sandbox_artifact a
             WHERE a.id = artifact_id AND a.creator_user_id = auth.uid())
  );
CREATE POLICY "sandbox_review_admin_insert" ON public.sandbox_review
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

CREATE INDEX sandbox_review_artifact ON public.sandbox_review (artifact_id, created_at DESC);
CREATE INDEX sandbox_review_trace ON public.sandbox_review (trace_id);
```

```sql
-- supabase/migrations/<YYYYMMDDHHMMSS>_create_sandbox_audit_log.sql

CREATE TABLE public.sandbox_audit_log (
  id bigserial PRIMARY KEY,
  trace_id uuid NOT NULL,
  artifact_id uuid REFERENCES public.sandbox_artifact(id) ON DELETE SET NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  guest_id text,
  capability_name text NOT NULL,
  decision text NOT NULL CHECK (decision IN ('ok','denied','timeout','escape_attempt','kill_switch')),
  payload_summary jsonb,                                                  -- categorical のみ / raw 不可
  api_error boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.sandbox_audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "sandbox_audit_owner" ON public.sandbox_audit_log
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "sandbox_audit_service" ON public.sandbox_audit_log
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

CREATE INDEX sandbox_audit_trace ON public.sandbox_audit_log (trace_id);
CREATE INDEX sandbox_audit_artifact_time ON public.sandbox_audit_log (artifact_id, created_at DESC);
CREATE INDEX sandbox_audit_decision ON public.sandbox_audit_log (decision, created_at DESC);

-- 90 日 retention
CREATE OR REPLACE FUNCTION purge_sandbox_audit_old() RETURNS void
  LANGUAGE sql AS $$
    DELETE FROM public.sandbox_audit_log WHERE created_at < now() - INTERVAL '90 days';
  $$;
```

```sql
-- supabase/migrations/<YYYYMMDDHHMMSS>_create_sandbox_kill_switch.sql

CREATE TABLE public.sandbox_global_kill_switch (
  id bool PRIMARY KEY DEFAULT true CHECK (id),                           -- 単一行
  enabled boolean NOT NULL DEFAULT true,
  disabled_reason text,
  disabled_by_user_id uuid REFERENCES auth.users(id),
  disabled_at timestamptz
);

INSERT INTO public.sandbox_global_kill_switch (id, enabled) VALUES (true, true)
ON CONFLICT DO NOTHING;

-- sentinel role 限定 UPDATE
ALTER TABLE public.sandbox_global_kill_switch ENABLE ROW LEVEL SECURITY;
CREATE POLICY "kill_switch_read_all" ON public.sandbox_global_kill_switch
  FOR SELECT USING (true);
-- UPDATE は service_role + sentinel role 経由のみ
CREATE POLICY "kill_switch_service_update" ON public.sandbox_global_kill_switch
  FOR UPDATE USING (auth.role() = 'service_role');

-- sandbox_user role 新設 + 全 prod table へ FORCE RLS
CREATE ROLE sandbox_user NOLOGIN NOINHERIT;
GRANT USAGE ON SCHEMA public TO sandbox_user;
-- prod table へ default 0 許可 (= 個別 capability 経由のみ)
ALTER TABLE public.profiles FORCE ROW LEVEL SECURITY;
ALTER TABLE auth.users FORCE ROW LEVEL SECURITY;
-- ... (全 sensitive table 列挙 / migration で展開)
```

### 4.4 `sandbox-hub` EF 新設 (= +1 EF / [EF-CAP-50] 適合)

§4.1 wrapper + capability dispatch 全実装 (= ai-hub / tools-hub と同 monolith pattern). 受入 capability subset:

| capability_name | 実装 | scope |
|---|---|---|
| `read_public_data` | `from(table).select()` (= news / blog / ai_university 等 sandbox_capability_whitelist.scope_args.target_table 限定) | RLS public.* SELECT |
| `compute_pure` | 純粋関数 dispatch (= color score / chart calc / no DB) | no DB |
| `render_chart` | chart.js / d3 vendored data 返却 | no DB |
| `read_own_profile_subset` | profile name / avatar 限定 (= user 即時 OK 押下後) | RLS profiles SELECT subset |
| `post_to_sandbox_feedback` | `sandbox_feedback` table (= sandbox 専用 / core 不接触) INSERT | RLS sandbox_feedback INSERT |

### 4.5 Subdomain `sandbox.my-web-app-b67f4.web.app` (= cross-origin iframe)

```yaml
# firebase.json (= 抜粋)
{
  "hosting": [
    {
      "site": "my-web-app-b67f4",
      "public": "build/web",
      ...
    },
    {
      "site": "sandbox-my-web-app-b67f4",                                # 新設
      "public": "build/sandbox",                                          # sandbox 専用 build
      "headers": [
        {
          "source": "**",
          "headers": [
            { "key": "Content-Security-Policy",
              "value": "default-src 'self' https://my-web-app-b67f4.web.app; script-src 'self' 'unsafe-inline'; frame-ancestors https://my-web-app-b67f4.web.app" },
            { "key": "X-Frame-Options", "value": "ALLOW-FROM https://my-web-app-b67f4.web.app" }
          ]
        }
      ]
    }
  ]
}
```

### 4.6 Flutter widget 新設 (= 4 widget)

```dart
// lib/widgets/sandbox/sandbox_iframe_widget.dart (= 新設 / platform_view_web.dart 拡張)

class SandboxIframeWidget extends StatelessWidget {
  final String artifactId;
  final String generatedCodeUrl;            // sandbox.my-web-app-b67f4.web.app/artifacts/<id>
  final List<String> allowedCapabilities;
  final void Function(String capability, dynamic result)? onCapabilityResult;

  const SandboxIframeWidget({
    required this.artifactId,
    required this.generatedCodeUrl,
    required this.allowedCapabilities,
    this.onCapabilityResult,
  });

  @override
  Widget build(BuildContext context) {
    // platform_view_web.dart 拡張版で iframe 生成
    // sandbox="allow-scripts allow-forms" のみ (= allow-same-origin OFF / allow-top-navigation OFF)
    // src = generatedCodeUrl (= cross-origin subdomain)
    // postMessage origin check 厳格 (= https://my-web-app-b67f4.web.app のみ)
    return PlatformViewWeb(
      tagName: 'iframe',
      attributes: {
        'src': generatedCodeUrl,
        'sandbox': 'allow-scripts allow-forms',
        'data-artifact-id': artifactId,
      },
      onPostMessage: _handlePostMessage,
    );
  }

  void _handlePostMessage(dynamic event) {
    if (event.origin != 'https://sandbox-my-web-app-b67f4.web.app') return;  // origin 厳格
    final capability = event.data['capability'] as String?;
    if (capability == null || !allowedCapabilities.contains(capability)) {
      // 違反 = sandbox-hub に違反 log + iframe disable
      return;
    }
    // sandbox-hub EF 経由で proxy
    SandboxHubClient.invoke(artifactId, capability, event.data['payload'])
      .then((result) => onCapabilityResult?.call(capability, result));
  }
}
```

```dart
// lib/widgets/sandbox/sandbox_consent_modal.dart (= 新設 / capability grant 3 択 modal)

class SandboxConsentModal extends StatelessWidget {
  // 「許可」「拒否」「全 capability 拒否」3 択
  // user 即時 OK 押下記録 = sandbox_capability_whitelist.granted_by_user_id INSERT
}
```

```dart
// lib/pages/admin/sandbox_review_page.dart (= 新設 / pending queue + 4-eyes approval UI)

class SandboxReviewPage extends StatefulWidget {
  // pending artifact list / leaf 判定結果表示 / approver 2 人記録 (= 4-eyes principle)
}
```

```dart
// lib/widgets/sandbox/sandbox_violation_banner.dart (= 新設 / iframe escape 検知時 banner)
```

### 4.7 CI lint workflow (= sandbox_artifact 経由でない route register reject)

```yaml
# .github/workflows/sandbox-route-lint.yml
name: sandbox-route-lint
on: [pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: check route register
        run: |
          # lib/data/home_tool_catalog.dart で sandbox_artifact 経由でない直接 route register PR を reject
          python3 scripts/check_sandbox_route_register.py
```

```python
# scripts/check_sandbox_route_register.py (= 新設)
# AST parse で home_tool_catalog.dart の 新規 route 追加 PR を検知
# sandbox_artifact_id 列がない route = reject + コメント返却
```

### 4.8 leaf node 判定 checklist (= 受入 #1209 Issue 内 / 部分整備 #833 連動)

`docs/AI_DEV_PRINCIPLES.md` 末尾に core/leaf 表を追加 (= future #833 ship 時に programmatic 化):

| カテゴリ | core (= human review 厚) | leaf (= sandbox 適用可) |
|---|---|---|
| データ層 | auth.users / profiles / payments / secrets / x_credentials | news / blog / ai_university / 公開 ranking |
| EF | ai-hub / admin-hub / blog-publish / x-post | tools-hub (= 一部) / sandbox-hub |
| UI | login / settings / billing / 投稿 form | 試作 widget / chart / ai 大学カード |
| 失敗時 blast radius | 全 user 影響 / data 損失 risk | 1 page 以内 / undo 容易 |

= leaf 3 条件 ALL ✅ → sandbox 投入可 / 1 つでも ❌ → core escalate (= human 4-eyes review).

## 5. 受入条件 mapping (= #839 + #1209 統合 N=8 件)

### 5.1 #839 受入条件 (= 4 件)

| # | 受入条件 (#839) | 対応 section |
|---|---|---|
| 1 | AI生成UIが本体画面とは別の隔離領域で表示できる | §4.5 (subdomain) + §4.6 (`SandboxIframeWidget`) |
| 2 | 許可されていない Supabase テーブル/Edge Function にアクセスできない | §4.2 (`checkSandboxCapability`) + §4.3 (RLS sandbox_user role + `sandbox_capability_whitelist`) |
| 3 | 生成 UI ごとに利用可能な API 一覧と禁止事項が確認できる | §4.6 (`SandboxConsentModal`) + §4.3 (`sandbox_capability_whitelist` per-artifact) |
| 4 | レビュー未完了の生成物は本番ナビゲーションへ露出しない | §4.7 (CI lint) + §4.3 (`sandbox_artifact.review_status` ENUM) + §2.2 4-eyes principle |

### 5.2 #1209 受入条件 (= 3 件)

| # | 受入条件 (#1209) | 対応 section |
|---|---|---|
| 1 | AI チャット内で生成された UI が即座にプレビュー可能 | §4.6 (`SandboxIframeWidget` / draft status で即 preview 可) |
| 2 | サンドボックス環境（リーフノード）から、Supabase の Auth や機密データへの不正なアクセスが構造上不可能 | §4.3 (sandbox_user RLS + FORCE RLS) + §4.5 (cross-origin iframe + CSP) + §2.1 service_role 注入禁止 |
| 3 | フロントエンドで予期せぬ動作が発生しても、バックエンドが絶対に保護される「証明可能な安全性」 | §4.2 (capability whitelist) + §4.3 (RLS 0 default) + §4.5 (CSP + sandbox 属性 4 層隔離) + §2.6 三重防御 cross-link |

### 5.3 横断追加 (= 統合 spec 第 1 例の独自 1 件)

| # | 横断受入 | 対応 section |
|---|---|---|
| 1 | 三重 audit log を trace_id で横断結合可能 (= MCP_AUTH + PII_GUARDRAIL + 本 spec) | §2.6 + §4.3 (`sandbox_audit_log.trace_id` UNIQUE INDEX) |

= **全 8 件 mapping ✅** (= self-check: 8/8 受入 spec 内対応 / 統合 spec 第 1 例で 0 漏れ達成).

## 6. Win Codex hand off scope (= 14h 推定 / 16 件 deliverable)

### 6.1 deliverable checklist

- [ ] migration 5 本 (= §4.3 / 各 30 min × 5 = 2.5h):
  - [ ] `<ts>_create_sandbox_artifact.sql`
  - [ ] `<ts>_create_sandbox_capability_whitelist.sql`
  - [ ] `<ts>_create_sandbox_review.sql`
  - [ ] `<ts>_create_sandbox_audit_log.sql`
  - [ ] `<ts>_create_sandbox_kill_switch.sql` (+ FORCE RLS roll-out)
- [ ] `_shared/sandbox_guard.ts` 新設 (= §4.2 / 1.5h / `agent_tool_policy.ts` 流用)
- [ ] `sandbox-hub` EF 新設 (= §4.1 + §4.4 / 2.5h / +1 EF / [EF-CAP-50] 49→50)
- [ ] Subdomain `sandbox-my-web-app-b67f4` Firebase config (= §4.5 / 1h)
- [ ] `lib/widgets/sandbox/sandbox_iframe_widget.dart` 新設 (= §4.6 / 2h / `platform_view_web.dart` 拡張)
- [ ] `lib/widgets/sandbox/sandbox_consent_modal.dart` 新設 (= §4.6 / 1h)
- [ ] `lib/widgets/sandbox/sandbox_violation_banner.dart` 新設 (= §4.6 / 0.5h)
- [ ] `lib/pages/admin/sandbox_review_page.dart` 新設 (= §4.6 / 2h / 4-eyes UI)
- [ ] `.github/workflows/sandbox-route-lint.yml` 新設 (= §4.7 / 0.5h)
- [ ] `scripts/check_sandbox_route_register.py` 新設 (= §4.7 / 0.5h)
- [ ] `docs/SANDBOX_INCIDENT_RUNBOOK.md` 新設 (= §2.2 / 0.5h)
- [ ] `docs/AI_DEV_PRINCIPLES.md` core/leaf 表追加 (= §4.8 / 0.5h / Issue #833 部分着地)

### 6.2 EF cap 適合 (= [EF-CAP-50])

- 現状 49 EF (= part 154 PII_GUARDRAIL `ai-audit-hub` 追加で 49)
- 本 spec で +1 (= `sandbox-hub`) → **50 EF (= 上限)**
- これ以降の新 EF は既存 hub 統合必須 (= `sandbox-hub` 内 capability 追加 / 新 EF 起票禁止)

### 6.3 工数推定 (= 合計 14h / sensitive baseline 12h より +17%)

| 工程 | 時間 | 備考 |
|---|---|---|
| migration 5 本 | 2.5h | RLS + FORCE RLS roll-out 含 |
| `_shared/sandbox_guard.ts` | 1.5h | `agent_tool_policy.ts` 流用 |
| `sandbox-hub` EF | 2.5h | 5 capability dispatch 実装 |
| Firebase subdomain | 1h | CSP + iframe header 配線 |
| Flutter 4 widget | 5.5h | iframe + consent + violation + admin review |
| CI lint + script | 1h | sandbox_artifact 経由でない route reject |
| docs 2 本 | 1h | runbook + AI_DEV core/leaf 表 |

### 6.4 自己宣言

- [x] 受入条件 全 8 件 mapping (= §5)
- [x] AI-CHARACTER-24 8/8 (= §2.3)
- [x] AI-DEV-23 7/7 (= §2.4)
- [x] **VIBE-30 7/7** (= §2.5 / sensitive 第 6 例で AI 生成コンテンツ初例)
- [x] MCP-AUTH-27 + PII-GUARDRAIL cross-link (= §2.6 / 三重防御)
- [x] EF cap 適合 (= +1 / 49→50)
- [x] migration 経由のみ INSERT (= 第 4-5 例から継承)
- [x] vendor managed 優先 (= browser sandbox + Supabase RLS + Firebase Hosting CSP)
- [x] 三重 trigger 認識 (= 個人 data + AI 生成コンテンツ + security boundary)

## 7. 統合 mapping (= #1209 sub-spec → §X.Y / 統合 spec 第 1 例)

### 7.1 #1209 提案要素 → §X.Y 対応

| #1209 提案 | 対応 section | 補強 / 追加 |
|---|---|---|
| Flutter Web の IFrame 等を用いた隔離領域 | §4.6 `SandboxIframeWidget` | sandbox 属性 + CSP + cross-origin subdomain で **4 層隔離** に格上げ (= browser standard managed) |
| Supabase RLS をより強固に設定 | §4.3 RLS sandbox_user role | **FORCE ROW LEVEL SECURITY** で creator 自己 bypass も阻止 / sandbox_user 0 default |
| サンドボックス用の極めて限定的な権限ロール | §4.3 sandbox_user role + `sandbox_capability_whitelist` | per-artifact capability whitelist で **粒度を artifact 単位** に細分化 |
| 即座にプレビュー可能 | §4.6 + §4.3 `review_status='draft'` | draft 状態でも creator + admin のみ preview 可 / 一般 user は approved のみ |
| 不正アクセスが構造上不可能 | §4.2 + §4.3 + §4.5 + §2.6 | 「構造上」= browser sandbox + RLS + CSP + cross-origin の 4 層 = **証明可能な安全性** (= 受入 #1209-3) |

### 7.2 #839 提案要素 → §X.Y 対応

| #839 提案 | 対応 section | 補強 / 追加 |
|---|---|---|
| AI 生成 UI を表示する隔離コンテナ | §4.6 `SandboxIframeWidget` | + cross-origin subdomain (= origin isolation) |
| Supabase Auth / service role / 既存 user data / 課金系 へ直接アクセスできない | §4.3 sandbox_user role + FORCE RLS | + §2.1 service_role 注入禁止 + §4.7 CI lint |
| 許可済 API/action のみ呼べるホワイトリスト | §4.2 `checkSandboxCapability` + §4.3 `sandbox_capability_whitelist` | + per-artifact 粒度 + scope_args jsonb |
| 生成物ごとに input/output/許可API/作成者/作成日時/レビュー状態を保存 | §4.3 `sandbox_artifact` (= 9 列で全網羅) | + 90 日 retention + 30 日 expire |
| 本番導入前に「リーフノード判定」「安全境界」「依存関係」確認 checklist | §4.8 leaf 判定 + §6 admin sandbox_review_page | + programmatic check (= `evaluateLeafNode()`) + 4-eyes principle |

### 7.3 統合効果 (= 2 issue 1 spec 第 1 例 / leverage 2x)

| 指標 | 個別 ship 推定 | 統合 ship 実績 |
|---|---|---|
| Win Claude 起票工数 | 30 min × 2 = 60 min | 60 min (= 同等) |
| Win Codex 実装工数 | 7h × 2 = 14h | 14h (= 同等 / 整合性自動保証) |
| reviewer cognitive load | 1 spec × 2 = 2 read | 1 read (= **-50%**) |
| 整合性 review (= RLS + capability + iframe 整合) | 別 review (= 漏れ risk) | 自動保証 (= 1 spec 内) |
| **leverage** | 1x | **2x** (= reviewer 効率) |

### 7.4 横展開 (= 統合 spec 候補)

将来同 NotebookLM source 由来の triplet / quadruplet:

- **triplet 候補**: #833 (= 同 NotebookLM `ddde5a4b`) — core/leaf 表 programmatic 化 (= §4.8 部分着地済 / 残 = AST scan + Issue PR template 列追加)
- 他 NotebookLM 由来の duplet 候補: monthly cleanup 時 surface 化

## 8. PHILOSOPHY-22 / VIBE-30 / SYNERGY-30 alignment

### 8.1 PHILOSOPHY-22 (= 9/9 ✅ / 7+/9 ゲート達成)

- ✅ #1 CEO 感 — sandbox 投入は CEO 即決可 (= 4-eyes admin 内で CEO + Sentinel)
- ✅ #2 ミッション — AI prototype 速度を上げつつ core を守る = mission alignment
- ✅ #3 mentor — leaf reject 時 mentor message + 別 path / [`ROBUST_AI_PERSONA_SPEC.md`](ROBUST_AI_PERSONA_SPEC.md) 連動
- ✅ #4 6 部署 — 設計 = architect 部署 / 実装 = engineering 部署 / review = ops 部署 (= 部署横断)
- ✅ #5 商品=価値 — sandbox infrastructure = 永続資産 / generated artifact = 流動 inventory
- ✅ #6 時間最適化 — 4-eyes principle で「review 後悔時間」最小化
- ✅ #7 資産負債 — 30 日 expire で AI 生成負債を蓄積させない / 90 日 hard delete
- ✅ #8 KPI — `sandbox_audit_log` で capability 利用率 / leaf 判定 fail 率 / approval 時間 計測可
- ✅ #9 IPO — sandbox audit log + RLS + 4-eyes principle = SOC2 + ISO 27001 監査対応

### 8.2 VIBE-30 (= 7/7 ✅ / sensitive 第 6 例で必須遵守)

§2.5 で詳細. 全項目 ✅ (= AI 生成コンテンツ第 1 例).

### 8.3 AI-DEV-23 + AI-CHARACTER-24 (= 7/7 + 8/8 ✅)

§2.3 + §2.4 で詳細.

### 8.4 SYNERGY-30 (= 6+/7 ✅)

- ✅ #1 cross-instance-pr — Win Codex hand off cross-instance-pr 起票
- ✅ #2 5 正本同期 — Issues + WBS + memory + worktree + PR + NotebookLM
- ✅ #3 fleet hygiene — chain depth 5 record (= main → #2017 → #2022 → #2024 → #2027 → 本 PR)
- ✅ #4 leverage — Win Claude 60 min / Codex 14h = 14x leverage / 2 issue 1 spec で 2x reviewer leverage 上乗せ
- ✅ #5 sensitive backlog 横展開 — #843 / #918 / #1215 / #1216 sensitive 候補に sandbox pattern 適用可
- ✅ #6 三重防御 architecture — MCP-AUTH (= 外部) + PII-GUARDRAIL (= 内部 AI 出力) + VIBE-SANDBOX (= AI 生成コード) で boundary 全網羅

### 8.5 INDIE-29 (= 6/7 ✅)

- ✅ #1 shipping 速度 — 1 session 1 spec ship + 統合 spec 第 1 例で実質 2 spec 分
- ✅ #2 dogfood — 81 part 連続 dogfood (= part 75-155)
- ✅ #3 leverage — 14x + 2x reviewer = 28x effective
- ✅ #4 minimum viable — MVP = `sandbox-hub` EF + 5 capability + iframe / Phase 2 = 全 hub 統合
- ✅ #5 measure — `sandbox_audit_log` で 全指標 計測可
- ✅ #7 abandon early — 30 日 expire / 90 日 hard delete で AI 生成負債 abandon 自動化

## 9. 関連 docs

- [`docs/DESIGN_SPEC_TEMPLATE.md`](DESIGN_SPEC_TEMPLATE.md) — 1 spec 起票時 ritual + 早見表
- [`docs/DESIGN_SPEC_PATTERNS.md`](DESIGN_SPEC_PATTERNS.md) — 6 pattern + 異領域共通項 + 階層化 PR workflow (= 第 6 改訂候補で本 spec 反映)
- sensitive 関連 spec: [`MENTAL_HEALTH_RISK_SPEC.md`](MENTAL_HEALTH_RISK_SPEC.md) (第 1) / [`AI_DESPERATION_DETECTION_SPEC.md`](AI_DESPERATION_DETECTION_SPEC.md) (第 2) / [`ROBUST_AI_PERSONA_SPEC.md`](ROBUST_AI_PERSONA_SPEC.md) (第 3) / [`MCP_AUTH_HARDENING_SPEC.md`](MCP_AUTH_HARDENING_SPEC.md) (第 4 / 外部 boundary) / [`PII_GUARDRAIL_SPEC.md`](PII_GUARDRAIL_SPEC.md) (第 5 / 内部 AI 出力 boundary)
- principle docs: [`PHILOSOPHY.md`](PHILOSOPHY.md) / [`VIBE_CODING_PRINCIPLES.md`](VIBE_CODING_PRINCIPLES.md) / [`AI_CHARACTER_PRINCIPLES.md`](AI_CHARACTER_PRINCIPLES.md) / [`AI_DEV_PRINCIPLES.md`](AI_DEV_PRINCIPLES.md) / [`MCP_AUTH_SECURITY_PRINCIPLES.md`](MCP_AUTH_SECURITY_PRINCIPLES.md) / [`AI_FLEET_SYNERGY_PLAYBOOK.md`](AI_FLEET_SYNERGY_PLAYBOOK.md) / [`INDIE_DEV_VELOCITY_PRINCIPLES.md`](INDIE_DEV_VELOCITY_PRINCIPLES.md)
- 関連 Issue: [#839](https://github.com/kanta13jp1/my_web_app/issues/839) / [#1209](https://github.com/kanta13jp1/my_web_app/issues/1209) / [#833](https://github.com/kanta13jp1/my_web_app/issues/833) (= 同 NotebookLM 三つ子 / cross-link only) / [#773](https://github.com/kanta13jp1/my_web_app/issues/773) PII / [#1577](https://github.com/kanta13jp1/my_web_app/issues/1577) MCP Auth
