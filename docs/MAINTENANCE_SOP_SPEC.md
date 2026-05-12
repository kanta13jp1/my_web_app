# Supabase Maintenance SOP — Restart / Pause 標準作業手順 spec (#1292 / part 144)

> **status**: 設計 spec / Win版#132 part 144 / 2026-05-05
> **issue**: [#1292](https://github.com/kanta13jp1/my_web_app/issues/1292) [追加要望] メンテナンス時におけるプロジェクト再起動・一時停止のSOP（標準作業手順）策定
> **scope**: 設計のみ (Win Claude territory / docs+architect) / 実装は Win Codex (= announcement EF + audit table migration) ハンドオフ
> **NotebookLM source**: `d3264dd4` Supabase General Project Settings and Infrastructure Dashboard
> **PHILOSOPHY-22 alignment**: #5 (商品=価値 — 信頼性) + #7 (資産負債 — downtime cost) / **AI-DEV-23** #2 (deny-by-default) + #7 (quality-gate)

## 1. 思想

Supabase Project の **Restart** (= 数分間 unavailable) / **Pause** (= 完全 inaccess) は
production user 影響度 high の操作. 不用意 trigger 防止 + 復旧確認 systematized で
「downtime = 想定内 + 短時間 + 通知済」の 3 条件を担保する.

## 2. 適用範囲

| Action | impact | apply | このSOP対象 |
|---|---|---|---|
| Restart project | 数分 unavailable | 緊急パッチ後 / config 反映 | ✅ |
| Pause project | 完全 inaccess | 長期 idle / cost 削減 | ✅ |
| Restore from pause | 復旧 5-15 min | Pause 後復活 | ✅ |
| DB migration deploy | 数秒 lock | GHA 自動 | ❌ (= 既存 deploy-prod) |
| Edge Function deploy | 0 downtime | GHA 自動 | ❌ |

## 3. SOP — 事前承認フロー (受入 #1)

### 3.1 4 段階 gate

```
[1] Operator 起票
    ↓ GitHub Issue (template: maintenance-window.yml)
[2] Pre-flight check (= 自動 / GHA)
    ↓ ヘルスチェック / 並行 PR 不在 / pending migration 不在
[3] Admin 承認
    ↓ Issue assignee = kanta13jp1 / "approved" label
[4] 実行 + 監視
    ↓ 開始時刻 / 完了時刻 / 異常時 rollback
```

### 3.2 起票必須項目 (= GitHub Issue template `maintenance-window.yml`)

| 項目 | 必須 | 例 |
|---|---|---|
| action | ✅ | restart / pause / restore |
| 計画開始時刻 (JST) | ✅ | 2026-05-08 03:00 |
| 想定 downtime | ✅ | 5 min |
| 理由 | ✅ | "PostgreSQL config 反映 (max_connections 増)" |
| 影響ユーザー範囲 | ✅ | 全ユーザー / β only / 内部 only |
| rollback plan | ✅ | "5 min 経過で異常時 → support escalation" |
| 並行 PR / migration | ✅ | "なし確認済 (gh pr list / git log)" |
| 通知方法 | ✅ | "in-app banner 24h 前 + Slack 1h 前" |

### 3.3 承認権限 matrix

| Action | 承認者 | SLA |
|---|---|---|
| Restart (5 min 以下) | kanta13jp1 単独 | 24h 前 起票 |
| Pause (∞) | kanta13jp1 + 1 sister AI 確認 | 72h 前 起票 |
| Restore (緊急) | kanta13jp1 + 即時 | 即時可 (= incident response) |

## 4. ユーザー告知 template (受入 #2)

### 4.1 告知 channel + timing

| Channel | timing | template ID |
|---|---|---|
| in-app banner (= MaintenanceBanner widget) | 24h 前 〜 完了+1h | `MAINT_BANNER_V1` |
| Slack #status | 24h 前 + 開始時 + 完了時 | `MAINT_SLACK_V1` |
| GitHub issue comment (= status page 代替) | 24h 前 + 完了時 | `MAINT_GH_V1` |
| dev.to status post | Pause 24h+ のみ | `MAINT_DEVTO_V1` |

### 4.2 in-app banner template (`MAINT_BANNER_V1`)

```text
🔧 メンテナンスのお知らせ
{{action_jp}}: {{start_jst}} 〜 {{end_jst}} (= 約 {{duration_min}} 分)
影響: {{impact_jp}}
詳細: {{issue_url}}
```

例:
```text
🔧 メンテナンスのお知らせ
再起動: 2026-05-08 03:00 JST 〜 03:05 JST (= 約 5 分)
影響: 全ユーザー API 一時停止
詳細: https://github.com/kanta13jp1/my_web_app/issues/9999
```

### 4.3 Slack template (`MAINT_SLACK_V1`)

```text
[MAINT-{{action}}] {{start_jst}}
:warning: {{action_jp}} 開始: {{description}}
duration: {{duration_min}}min
impact: {{impact_jp}}
rollback: {{rollback_plan}}
```

### 4.4 持続化 (= EF / 永続層)

```sql
-- supabase/migrations/<YYYYMMDDHHMMSS>_create_maintenance_window_log.sql

CREATE TABLE public.maintenance_window_log (
  id bigserial PRIMARY KEY,
  issue_number int UNIQUE NOT NULL,
  action text NOT NULL CHECK (action IN ('restart','pause','restore')),
  planned_start_at timestamptz NOT NULL,
  planned_end_at timestamptz NOT NULL,
  actual_start_at timestamptz,
  actual_end_at timestamptz,
  reason text NOT NULL,
  impact text NOT NULL,
  rollback_plan text NOT NULL,
  approved_by text,
  approved_at timestamptz,
  status text NOT NULL DEFAULT 'planned'
    CHECK (status IN ('planned','approved','in_progress','completed','cancelled','failed')),
  health_check_result jsonb,                    -- §5 結果
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX maintenance_window_status_time
  ON public.maintenance_window_log (status, planned_start_at DESC);

ALTER TABLE public.maintenance_window_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "admin_only" ON public.maintenance_window_log
  FOR ALL USING (auth.role() = 'service_role');
```

## 5. 復旧後ヘルスチェック (受入 #3)

### 5.1 必須 5 項目

| # | check | tool | pass 条件 |
|---|---|---|---|
| 1 | API endpoint 200 | `curl https://my-web-app-b67f4.web.app/` | HTTP 200 + body length > 1000 |
| 2 | Auth flow | Supabase signInWithPassword (test acct) | session 取得 < 3s |
| 3 | DB read latency | `select count(*) from public.profiles` via REST | < 500ms |
| 4 | Edge Function (= memory-search-hub ping) | `POST /functions/v1/memory-search-hub` | 200 + valid json |
| 5 | Storage bucket list | `storage.from('avatars').list()` | array 返却 |

### 5.2 自動化 (= 既存 infra-health 拡張)

`scripts/maintenance_health_check.sh` (= Win Codex 実装) — 既存 `.github/workflows/infra-health-check.yml` を pattern 化:
- 5 項目を直列実行
- 各 step 結果を `maintenance_window_log.health_check_result` jsonb に追記
- 全 pass で status='completed' / 1 つでも fail で status='failed' + Slack alert

### 5.3 ロールバック判断 matrix

| 経過時間 | 状態 | action |
|---|---|---|
| 0-5 min | unavailable 想定内 | wait |
| 5-10 min | 想定超過 | Slack alert + 観察継続 |
| 10-30 min | 異常 | Supabase Dashboard restore + escalation |
| 30 min+ | critical | snapshot restore + post-mortem 起票 |

## 6. 既存 infra との関係

| 既存 | このSOPとの関係 |
|---|---|
| `.github/workflows/infra-health-check.yml` | §5.2 で 5-項目版 拡張 |
| `docs/AI_FALLBACK_RUNBOOK.md` | maintenance 中は Codex CLI fallback 自動切替 (= section 追記 1 行) |
| `docs/OPERATIONS_CHARTER.md` | 5 正本に "maintenance_window_log" 追加 |
| `MaintenanceBanner` Flutter widget | §4.2 で **新規** (= Win Codex / lib/widgets/maintenance_banner.dart 案) |

## 7. Win Codex hand off scope

- [ ] `supabase/migrations/<ts>_create_maintenance_window_log.sql` (= §4.4)
- [ ] `.github/ISSUE_TEMPLATE/maintenance-window.yml` (= §3.2)
- [ ] `scripts/maintenance_health_check.sh` (= §5.2)
- [ ] `lib/widgets/maintenance_banner.dart` (= §4.2 / status='in_progress' で表示)
- [ ] `docs/AI_FALLBACK_RUNBOOK.md` 1 行追記 (= maintenance fallback)
- [ ] `docs/OPERATIONS_CHARTER.md` 5 正本に追加

EF 数 +0 (= 既存 hub 流用 / [EF-CAP-50] 完全遵守 / 50 上限維持).
推定工数: 6h (= migration 1h + template 0.5h + script 2h + widget 1.5h + docs 1h).

## 8. PHILOSOPHY-22 / AI-DEV-23 alignment

### PHILOSOPHY-22

- ✅ #1 CEO 感 — operator 自身が gate を通る規律
- ✅ #2 ミッション — downtime も計画運用の一部
- ✅ #5 商品=価値 — 信頼性が価値の中核
- ✅ #6 時間最適化 — 24h 前通知でユーザー予定保護
- ✅ #7 資産負債 — log table = 監査資産
- ✅ #8 KPI — health_check 5 項目 = 復旧 KPI
- ✅ #9 IPO — 監査ログ提示可能

### AI-DEV-23

- ✅ #1 Auth — admin gate (RLS service_role)
- ✅ #2 deny-by-default — 起票なし = 実行不可
- ✅ #5 memory — log table 永続化
- ✅ #7 quality-gate — 5 health check pass 必須

## 9. 受け入れ条件 mapping

| 受入条件 | 対応 section |
|---|---|
| #1 事前承認フロー | §3 (4 段階 gate / matrix) |
| #2 ユーザー告知 template | §4 (banner / Slack / GH / dev.to) |
| #3 復旧後ヘルスチェック | §5 (5 項目 / 自動化 / rollback matrix) |
