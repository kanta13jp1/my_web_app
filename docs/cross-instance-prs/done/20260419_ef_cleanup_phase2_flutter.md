---
date: 2026-04-19
from: Windowsアプリ版#122
to: PowerShell版#5 (on-call)
status: partial-done (2026-04-20 PS#5 S15+S16)
priority: medium
---

# EF cleanup 第2弾 - Flutter コードから 40 dead EF 呼出を削除

## 進捗 (PS#5 S15 / 2026-04-20)

### 確認済み事実
- **39/40 EFs が production で 404 確定** (memo-reactions のみ alive)
- 全 40 EFs が依然として Flutter から参照されている (try/catch fallback あり)
- deploy-prod.yml の delete list に 12 件のみ明示 → 残り 27 件も実態 404 (Supabase 側で deploy 漏れ)

### 本セッション完了分 (3 EFs migrated to ai-hub)

| # | 旧 EF | 新 action | Flutter file |
|---|---|---|---|
| 1 | ai-university-badges | `ai-hub:university.badges` | `lib/pages/ai_university_badges_page.dart` |
| 2 | ai-university-streaks | `ai-hub:university.streak` + `university.leaderboard` (新規追加) | `lib/pages/ai_university_streaks_page.dart` |
| 3 | ai-university-content | `ai-hub:university.content_all` (新規追加) | `lib/pages/ai_university_content_page.dart` |

ai-hub に追加した action:
- `university.leaderboard` (limit param) — `ai_university_leaderboard` view から取得
- `university.content_all` (limit param) — provider filter なし版 (admin 用)

### S16 完了分 (2026-04-20)

| # | 旧 EF | 新 action | Flutter file | commit |
|---|---|---|---|---|
| 4 | data-export-manager | `admin-hub:data.export` + `data.export_available` (新規追加) | `lib/pages/data_backup_page.dart` | fa9004af |

備考: data_backup_page.dart は EF が未実装のテーブル (tasks/habits/finances/blog_posts) を request body に含めていた → EXPORT_TABLES 4 件 (profile/notes/feature_requests/notifications) に修正.

### 残り 36 EFs (next session backlog)

全て Flutter から呼ばれているが try/catch + ローカル fallback あり → UX は graceful degraded.
緊急度: 低 (silent fail でユーザーは気付かない)

優先度順 (Flutter ref 数の少ない順 = migration 容易):

| 残数 | EF | Flutter ref count | 推奨 hub |
|---|---|---|---|
| 1 | growth-import-commit | 1 | growth-hub:import.commit (実装は別物・要 EF コード移植) |
| 2 | gemini-election-analysis | 2 | ai-hub:election.analyze |
| 2 | generate-daily-challenges | 2 | growth-hub:daily.challenges |
| 2 | growth-import-preview | 2 | growth-hub:import.preview (実装は別物・要 EF コード移植) |
| 2 | notify-feature-request | 2 | growth-hub:feature.notify |
| 3 | admin-notification-hub | 3 | admin-hub:notify |
| 3 | growth-acquisition | 3 | growth-hub:acquisition |
| 3 | landing-ab-test | 3 | growth-hub:landing.ab |
| 3 | viral-growth-engine | 3 | growth-hub:viral |
| 4-6 | (28 remaining) | 4-10 | 元タスク表 (本ファイル先頭) 参照 |

### 重要発見

1. **`memo-reactions` は alive (404 ではなく 400 = 引数エラー)** — deploy-prod.yml line 174 で comment-out 済み (削除しない). 元タスク表から除外可.

2. **`growth-import-preview/commit` の hub 既存 action は STUB** — `growth-hub:import.preview/commit` は metadata 記録のみで、Notion API 連携・ファイル parse などの実装はない. Flutter 移行には EF コード本体の hub 移植が必要.

3. **`daily-judgment` は移植先要検討** — ai-hub に既存 `judgment.get` action あり. Flutter 側は body 形式が違う (`save_thought_interrupt_diagnosis` action 参照). 移行コスト中.

## 推奨次回タスク (PS#5 next session)

1. **delete list cleanup**: `.github/workflows/deploy-prod.yml` の delete 行から既に削除完了の EF を削除 (空打ち防止)
2. **小規模 migration 5 EFs**: data-export-manager / gemini-election-analysis / generate-daily-challenges / notify-feature-request / admin-notification-hub
3. **import-preview/commit 本格 migration**: EF コードを growth-hub に移植 (Notion API ロジック含む)

宛先インスタンスが完了したら `done/` に移動してください。
→ 部分完了済み (2026-04-20 PS#5 S15)

---
[原文は元 issue 参照]
