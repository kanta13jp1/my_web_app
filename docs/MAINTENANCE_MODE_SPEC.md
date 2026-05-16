# Maintenance Mode + Planned Outage Dashboard — UI/設計 spec (#1309 / part 142)

> **status**: 設計 spec / Win版#132 part 142 / 2026-05-05
> **issue**: [#1309](https://github.com/kanta13jp1/my_web_app/issues/1309) [追加要望] 計画停止情報のダッシュボード表示および自動メンテナンスモードの実装
> **scope**: 設計のみ (Win Claude territory) / 実装は Win Codex (= EF Deno + SQL migration + Flutter widget) ハンドオフ
> **NotebookLM source**: `f404e403` CATS System Planned Outage Notification and Correspondence

## 1. 機能概要

3 layer:

| layer | 役割 | 担当 |
|---|---|---|
| **L1 admin 登録 UI** | 計画停止 (= window) を CRUD | Flutter widget (CFO 部署 admin page) |
| **L2 user 事前通知 banner** | window 前 N 日 (default 3 日) から表示 | Flutter widget (= 全 page 上部 / Layout) |
| **L3 maintenance mode 自動切替** | window 中は機能 / 全体 lockdown | router guard + EF response 503 |

## 2. Schema (= Win Codex 担当 / 1 migration)

```sql
-- supabase/migrations/<YYYYMMDDHHMMSS>_create_maintenance_windows.sql

CREATE TABLE public.maintenance_windows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scope text NOT NULL DEFAULT 'system'
    CHECK (scope IN ('system','feature')),
  affected_features text[] NOT NULL DEFAULT '{}',  -- scope='feature' 時のみ
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL CHECK (ends_at > starts_at),
  notice_days_before int NOT NULL DEFAULT 3 CHECK (notice_days_before >= 0),
  message_ja text NOT NULL,
  message_en text,
  severity text NOT NULL DEFAULT 'info'
    CHECK (severity IN ('info','warning','critical')),
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 高速 lookup 用 index (= banner / mode 判定 hot path)
CREATE INDEX maintenance_windows_active_lookup
  ON public.maintenance_windows (starts_at, ends_at)
  WHERE ends_at > now();

-- RLS: read = 全員 / write = service_role (= admin EF 経由のみ)
ALTER TABLE public.maintenance_windows ENABLE ROW LEVEL SECURITY;
CREATE POLICY mw_public_read ON public.maintenance_windows FOR SELECT USING (true);
```

## 3. EF 設計 (= 既存 hub 拡張 / [EF-FIRST] [EF-CAP-50] 遵守)

**`schedule-hub`** に 4 action 追加:

| action | 入力 | 出力 | 認可 |
|---|---|---|---|
| `maintenance.list_active` | `now?: ISO` | `[{id, scope, message, banner_visible_from, ...}]` | public |
| `maintenance.create` | window full payload | `{id}` | admin only |
| `maintenance.update` | `id`, partial payload | `{id}` | admin only |
| `maintenance.delete` | `id` | `{ok}` | admin only |

= 新 EF ゼロ (= [EF-CAP-50] 維持)。

## 4. Flutter UI 設計 (= Win Codex 担当)

### 4.1 admin 登録 page (= L1)

`lib/pages/admin/maintenance_management_page.dart`:

```
┌─ AppBar: 「計画停止管理」+ Add (+) button ──────────┐
├─ DataTable                                          │
│  | scope | features | starts_at | ends_at | sev |  │
│  |────────|──────────|───────────|─────────|─────| │
│  | system | -        | 05/10 02:00 | 05/10 04:00 | warn |  │
│  | feature | [ai-hub] | 05/15 14:00 | 05/15 15:00 | info |  │
│ (rows tap → edit dialog / delete with confirmation) │
└──────────────────────────────────────────────────────┘
```

Edit dialog:
- scope radio: system / feature
- feature multiselect (= scope=feature 時のみ enable / from EF list)
- starts/ends date+time picker
- notice_days_before slider (0-14)
- message_ja TextField (multiline / required)
- message_en TextField (optional)
- severity dropdown (info/warning/critical)

### 4.2 user banner (= L2)

`lib/widgets/maintenance_banner.dart` を全 page 上部 (= MaterialApp.builder で wrap):

```
┌─ Banner (severity=info: blue / warning: amber / critical: red) ──┐
│ ⚠️ 2026-05-10 02:00-04:00 に system 計画停止予定                  │
│    → 詳細 / 通知設定 [×]                                          │
└────────────────────────────────────────────────────────────────────┘
```

表示条件:
- now ≥ starts_at - notice_days_before AND now < ends_at
- ユーザー dismiss は session 内のみ (= 翌 session で再表示)
- 5 分間隔で polling (= NetworkImage + cache に近い軽量 query)

### 4.3 maintenance mode page (= L3)

`lib/pages/maintenance_mode_page.dart`:

```
┌─ Centered card ──────────────────────────────────┐
│  🛠️ メンテナンス中                              │
│                                                  │
│  <message_ja>                                    │
│                                                  │
│  予定終了: 2026-05-10 04:00 JST                  │
│  ([残り時間 1h 23m] live update)                 │
│                                                  │
│  [ 復旧後に通知を受け取る (email) ]              │
└──────────────────────────────────────────────────┘
```

router guard:
- `lib/services/maintenance_guard.dart` で全 route 前に check
- scope=system → 全 route → MaintenanceModePage
- scope=feature → affected_features に含まれる route のみ → MaintenanceModePage
- admin route (`/admin/*`) は常に bypass (= 解除作業可能)

### 4.4 cache 戦略 (= 受け入れ条件 / 「画面描画が遅延しないよう」)

- `MaintenanceService` は in-memory cache (= TTL 5 分 / Riverpod Provider)
- 起動時に 1 回 prefetch (= main() / runApp 前)
- 5 分後 background refresh (= 期限切れ window 自動 hide)

## 5. 受け入れ条件 mapping

| # | 受け入れ条件 | 設計 mapping | 担当 |
|---|---|---|---|
| 1 | admin が CRUD 可 | `MaintenanceManagementPage` + `schedule-hub` 4 action | Win Codex |
| 2 | N 日前から banner 表示 | `MaintenanceBanner` + `notice_days_before` field | Win Codex |
| 3 | 期間中 機能 / 全体 lockdown | `MaintenanceGuard` + `MaintenanceModePage` | Win Codex |
| 4 | 期間後 自動解除 | `ends_at < now()` で natural exit (= polling で hide) | Win Codex |

## 6. 9 原則チェック (= [PHILOSOPHY-22])

| # | 原則 | 該当 |
|---|---|---|
| 1 | CEO 感 | ✅ 自社 SaaS の運用 transparency = CEO らしさ |
| 2 | ミッション | ✅ ユーザー体験劣化を最小化 |
| 4 | 6 部署 | ✅ CTO 部署 (= 運用) で window 管理 |
| 5 | 商品=価値 | ✅ 信頼性 = 価値 (= MTBF / MTTR の透明化) |
| 8 | KPI | ✅ planned downtime % を CFO ledger 反映可能 |

= **5/9 直接該当 / 7+/9 ✅ 閾値クリア**

## 7. IMBUE-25 / COLLAB-26 (= UX 設計原則)

| pattern | 該当 |
|---|---|
| IMBUE #1 (= 即座 feedback) | banner = 画面遷移なし即視認 |
| IMBUE #4 (= proactive 警告) | N 日前 notice |
| COLLAB #2 (= human override) | admin bypass |

## 8. 実装手順 (= Win Codex hand off / 6 step)

1. `supabase/migrations/<ts>_create_maintenance_windows.sql` 起票 (= section 2)
2. `supabase/functions/schedule-hub/index.ts` に 4 action 追加 (= section 3)
3. `lib/services/maintenance_service.dart` 新規 (= cache 5min TTL)
4. `lib/widgets/maintenance_banner.dart` 新規 + MaterialApp.builder で wrap
5. `lib/pages/maintenance_mode_page.dart` + `lib/services/maintenance_guard.dart` 新規
6. `lib/pages/admin/maintenance_management_page.dart` + `/admin/maintenance` route 追加

## 9. 次回拡張 (= part 143+)

- email 復旧通知 (= L3 #4 button / Resend integration)
- multi-language (= en 以外も)
- Slack notification on window create
- Status page 統合 (= statuspage.io 互換 endpoint)

---

**Spec status**: 設計完了 / 実装ハンドオフ準備済 → cross-instance-pr 経由で Win Codex へ
