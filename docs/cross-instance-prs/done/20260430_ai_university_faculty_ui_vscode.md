# Cross-Instance PR: AI 大学 学部/学科 4 層 drill-down UI

**作成**: Win版#132 part 93 / 2026-04-30
**FROM**: Win版 (User 要望 + schema 設計)
**TO**: VSCode版 (Flutter UI 専任 territory)
**優先度**: HIGH
**期限**: 2026-05-07 (1 週間)
**親軸**: AI 大学拡張 + INDIE_DEV_VELOCITY (#3 Deployment Scaffolding / #5 Hand-Written Art)

---

## 1. 背景

User 要望: AI 大学に学部/学科 hierarchy 追加.

Win territory done (= phase 1):
- schema migration `20260430020000_create_university_faculties_departments.sql`
- 5 学部 / 22 学科 seed
- `ai_university_content.faculty_id` + `department_id` column 追加 (nullable)

VSCode territory (= phase 5 / 本 PR):
- Flutter UI で **学部 → 学科 → provider → content** の 4 層 drill-down 実装

## 2. 現状 UI (= 修正対象)

`lib/pages/ai_university_content_page.dart`:
- ai-hub `university.content_all` action で 全 content fetch
- ListView で flat list 表示 (= 380+ row が 1 列に並ぶ)

`lib/widgets/ai_university_home_card.dart`:
- AI 大学トップカード (home page から遷移)

## 3. 期待する UI 改造

### 3.1 学部選択画面 (= 新規 / `/ai-university` route)

```
┌─────────────────────────────────────────┐
│ AI 大学 — 学部選択                      │
├─────────────────────────────────────────┤
│  🤖 AI 学部              7 学科 380+ 講義│
│  ☁️ クラウド学部          5 学科 30+ 講義 │
│  🛠️ 開発ツール学部        4 学科 20+ 講義 │
│  💾 データ基盤学部        3 学科 15+ 講義 │
│  📚 学術研究学部          3 学科 20+ 講義 │
└─────────────────────────────────────────┘
```

各学部 card tap → 学科選択画面へ.

### 3.2 学科選択画面 (= 新規 / `/ai-university/faculty/<faculty_code>`)

```
┌─────────────────────────────────────────┐
│ ← 戻る  ☁️ クラウド学部                 │
│  クラウドサービス全般を学ぶ...          │
├─────────────────────────────────────────┤
│  🟠 AWS 学科             7 provider     │
│  🔵 GCP 学科             6 provider     │
│  🟦 Azure 学科           6 provider     │
│  🔴 Oracle Cloud 学科    4 provider     │
│  ⚡ エッジ・新興学科      6 provider     │
└─────────────────────────────────────────┘
```

学部紹介 (description) 表示 + 学科 cards.

### 3.3 provider 一覧画面 (= 既存 / 学科 filter 追加 / `/ai-university/department/<department_code>`)

```
┌─────────────────────────────────────────┐
│ ← AI 大学 > ☁️ クラウド学部 > 🟠 AWS 学科│
├─────────────────────────────────────────┤
│ 🔍 [検索]                                │
│  ┌───────┐ ┌───────┐ ┌───────┐         │
│  │ EC2  │ │  S3  │ │Lambda│         │
│  └───────┘ └───────┘ └───────┘         │
│  ┌───────────┐ ┌───────────┐           │
│  │ SageMaker │ │  Bedrock  │           │
│  └───────────┘ └───────────┘           │
└─────────────────────────────────────────┘
```

= 既存 provider grid を学科 filter で絞り込み. Breadcrumb で 4 階層を表示.

### 3.4 content 詳細画面 (= 既存 / breadcrumb 追加)

```
AI 大学 > ☁️ クラウド学部 > 🟠 AWS 学科 > AWS Lambda > 概要
```

= 既存 content 詳細に上部 breadcrumb 追加.

## 4. 実装方針

### 4.1 EF action (= Codex#2 territory / 並行 PR)

ai-hub に新 4 actions:
- `university.faculty_list` → 全学部 list
- `university.department_list` → 学部別学科 (= faculty_id filter)
- `university.provider_by_department` → 学科別 provider
- `university.content_by_faculty` → 学部別 content

= **VSCode は EF 完成後に UI 連携** (= Codex#2 cross-instance-pr 完了待ち / 本 PR の前提).

### 4.2 新規 / 修正 file

| file | 変更内容 |
| --- | --- |
| `lib/pages/ai_university_faculty_select_page.dart` | 新規 (= 学部選択画面 / 3.1) |
| `lib/pages/ai_university_department_select_page.dart` | 新規 (= 学科選択画面 / 3.2) |
| `lib/pages/ai_university_content_page.dart` | 学科 filter + breadcrumb 追加 (3.3) |
| `lib/main.dart` | 新 routes 2 件 (`/ai-university/faculty/:code` + `/ai-university/department/:code`) |
| `lib/widgets/ai_university_home_card.dart` | tap → faculty select に変更 |
| `lib/widgets/breadcrumb.dart` | 新規 (= 4 階層 breadcrumb widget / 既存なら拡張) |

### 4.3 design tokens

`docs/DESIGN.md` 準拠:
- 学部 emoji + name で大型 ListTile (= card / Material 3)
- 学科 emoji + name で中型 ListTile
- provider grid は既存 design retain

### 4.4 integration test

`integration_test/ai_university_drill_down_test.dart` 新規:
- LP → AI 大学 → クラウド学部 → AWS 学科 → AWS Lambda content 詳細 → breadcrumb 戻る → 学部選択

= **VIBE_CODING #5 (Minimal E2E Tests) dogfood**.

## 5. 受入基準

- [ ] 学部選択画面 + 学科選択画面 新規 (5 学部 / 22 学科 全表示)
- [ ] provider 一覧画面に学科 filter + breadcrumb
- [ ] content 詳細画面に breadcrumb (4 階層)
- [ ] route 2 件追加 (`/ai-university/faculty/:code` / `/ai-university/department/:code`)
- [ ] DESIGN.md 準拠 (= dark theme / orange+indigo accent)
- [ ] integration test 1 シナリオ pass
- [ ] flutter analyze 0 issues
- [ ] cross-instance-pr 完了時 `done/` 移動

## 6. 並行 PR

- PS#3: provider mapping + クラウド/DevOps/データ provider seed (= phase 2-4)
- Codex#2: ai-hub action 4 件追加 (= phase 6)

= **3 instance 並行で 1 機能完成** (= co-implementation pattern 第 5 例).

---

*Win版#132 part 93 / 2026-04-30 起票 / AI 大学 学部/学科 UI 4 層 drill-down / Win → VSCode lane*
