# Cross-Instance PR: 宮崎県連 25 人擁立 News を election dashboard に反映 UI

**作成**: Win版#132 part 106 / 2026-05-01
**FROM**: Win版 (User News 共有 + schema 反映)
**TO**: VSCode版 (Flutter UI 専任 territory)
**優先度**: medium (= News 反映 / blocking ではないが timely)
**期限**: 2026-05-08 (1 週間)
**親軸**: election_victory_page UI / IMBUE #6 (UX 体験)

---

## 1. 背景

User 共有 News (2026-04-29):
> 国民民主党宮崎県連が来年の統一地方選 + 地方議員選挙について計25人擁立目標発表 (= 20人確定 + 公募5人追加方針 / 代表 長友慎治 衆院議員)

Win territory done:
- migration `20260501030000_create_prefecture_election_news.sql`:
  - `prefecture_election_news` テーブル新規
  - 宮崎 entry seed (= total_candidate_target 25 / confirmed 20 / public_recruitment 5)

VSCode territory (= phase 2 / 本 PR):
- `lib/pages/election_victory_page.dart` の宮崎県 detail panel に **News badge** 表示
- 既存 dashboard の数値 (= 新人擁立目標 9) と公式 News 数値 (= 25) を 並列表示

## 2. 期待する UI 改造

### 2.1 News badge widget

宮崎県選択時の右側 KGI/KPI panel 上部に **News alert** を表示:

```
┌─────────────────────────────────────────┐
│  宮崎県 KGI/KPI                          │
│  ┌─────────────────────────────────────┐│
│  │ 📢 公式発表 (2026-04-29)             ││
│  │ 国民民主党宮崎県連: 計 25 人擁立目標   ││
│  │ ・確定 20 人 / 公募追加 5 人          ││
│  │ ・代表: 長友慎治衆院議員              ││
│  │ ・参照: 読売新聞 [link] ↗            ││
│  └─────────────────────────────────────┘│
│  重点度 32 pt                            │
│  [既存 KGI/KPI 表示]                     │
└─────────────────────────────────────────┘
```

= 公式発表値と内部 formula 値の **対比表示** で User 認知容易化.

### 2.2 既存 KGI/KPI と公式値の並列表示

| 項目 | 内部 formula (= tier 3) | 公式 News 値 |
| --- | --- | --- |
| 新人擁立目標 | 9 (= 算出) | **25** ← 公式 |
| 立候補予定者確定 | (= 不明) | **20** |
| 公募追加 | (= 不明) | **5** |

### 2.3 全 prefecture 共通 (= 将来拡張)

`prefecture_election_news` テーブルは prefecture 単位で event 蓄積可能 → 他県でも News 出ればここに seed → 自動表示.

## 3. 実装方針

### 3.1 EF action (= Codex#2 territory / 並行 PR 候補)

`ai-hub` (= or 既存 election service) に新 action:
- `election.news_for_prefecture` → prefecture filter で fetch

### 3.2 新規 / 修正 file

| file | 変更内容 |
| --- | --- |
| `lib/services/local_election_news_service.dart` | 新規 (= prefecture_election_news fetch) |
| `lib/widgets/election_news_badge.dart` | 新規 (= News badge widget) |
| `lib/pages/election_victory_page.dart` | 宮崎県 detail panel に news badge 統合 |
| `lib/models/prefecture_election_news.dart` | 新規 (= model class) |

### 3.3 design tokens

- `docs/DESIGN.md` 準拠
- News badge: 警告色なし (= info color / Indigo accent)
- アイコン: 📢 megaphone or 🗞️ newspaper

## 4. 受入基準

- [ ] 宮崎県選択時に news badge 表示
- [ ] tap で news source URL 開く (= url_launcher)
- [ ] 公式発表値 vs 内部 formula 値の対比 visible
- [ ] flutter analyze 0 issues
- [ ] integration test (= 宮崎県 tap → news visible 確認)
- [ ] cross-instance-pr 完了時 `done/` 移動

## 5. 関連 cross-instance-pr

- [Codex#2] EF action 追加候補 (= `election.news_for_prefecture`) — 必要なら別 PR

## 6. 将来拡張 (= 本 PR スコープ外)

- prefecture_election_news の monthly cron 自動更新 (= NotebookLM 蒸留 routine + 競合モニタリング統合)
- News based override で internal formula value を automatic update する option
- 全 47 都道府県 News alert 一覧 page

---

*Win版#132 part 106 / 2026-05-01 起票 / 宮崎県 News 反映 UI / Win → VSCode lane*
