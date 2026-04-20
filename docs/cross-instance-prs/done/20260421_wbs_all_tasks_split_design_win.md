# Win版 宛: WBS "ALL" tasks を instance 別に split する設計判断

## ✅ Win版 決裁 (2026-04-21 朝 / Win#131 part 14-15 / commit 04402bc0)

**結論: 案 D (shared keep + owner_instance 必須 + UI warning)** を採用・実装済。

- 3 ALL tasks は **残す** (milestone 相当として横断目標を見れる場所を維持)
- ただし `owner_instance` 列 (NOT NULL + CHECK 制約 12 値 / `'all'` 禁止) を追加し、
  各タスクの **primary owner** を明示 (現状 3 件とも backfill で `vscode` に集約)
- `wbs.add_task` は `instance='all'` 指定時に `owner_instance` 明示必須化
  (未指定は 400 エラー = default leak 完全遮断)
- UI warning chip (instance='all' のとき "🌐 ALL - owner: vscode" 表示) は
  **VSCode版 T2-VSCode に handoff** (Gantt Grid 5 列実装と同時に組み込む)

→ 以後この handoff は **closed** (done/ に移管)

---

- **起票元**: PS版#6 S23 (2026-04-21)
- **優先度**: MEDIUM (user 明示要望だが design 判断必要)
- **起票理由**: user Q「すべてのインスタンスに本当に ALL で割り当てられているのか — ALL タスクは N 個に split すべきでは」

## Context

### 現状 (commit 232b2783 post-fix)

`wbs.priority_for_instance` が ps6 に返す TOP 3 はすべて `instance:"all"`:

| id | title | instance | progress |
| --- | --- | --- | --- |
| 9d9ea821 | ユーザー数50人達成 (α版目標) | all | 8% |
| 50fd622d | ユーザー数500人達成 (β版目標) | all | 0% |
| 2ba58757 | ユーザー数5000人達成 (v1目標) | all | 0% |

= どの instance を見ても同じ 3 件が top に出て、自 instance の個別タスクが埋もれる。

### PS#6 S23 で実施した防御 (commit <TBD>)

`wbs.add_task` の `instance` field を **required** 化 (デフォルト 'all' 廃止):
- 以後の新規 add_task は explicit instance 指定強制
- `validInstances` = vscode/win/ps1-6/web/mobile/all の 11 値
- 'all' は明示指定のみ可 (default leak 禁止)

→ 新規追加はクリーン、**既存 3 ALL tasks の処遇が未決定**

## 判断ポイント

user 要望「ALL なら N 個 split」を額面通り実装すると以下 3 案:

### 案 A: 完全 split (8 × 3 = 24 tasks)

各 instance に 1 行ずつ。"ユーザー数50人達成 (vscode)" "... (win)" "... (ps1)" ...
- メリット: priority_for_instance が他 instance goal を一切出さない (clean)
- デメリット: 24 行膨張 / 「全体目標」見る場所がなくなる / progress rollup 不明

### 案 B: Section-level milestone + per-instance sub-tasks

既存 3 ALL tasks を **milestone** に昇格 (= 横断目標マーカー)、各 instance が達成寄与する sub-task を 1-2 個ずつ所有。
- メリット: 全体目標 1 行 + 各 instance 責務明確 / progress rollup 自然
- デメリット: table schema 変更 (parent_milestone_id 追加) / 移行 SQL 必要

### 案 C: filter UI で "instance ≠ all" 絞り込み (schema 変更なし)

Gantt UI に「他 instance 割当隠す」チェックボックス追加。ALL は常に表示。
- メリット: schema 変更ゼロ / UI 実装のみ (数時間)
- デメリット: 「ALL を split すべき」という user 発言の根本意図には未応答

## Win版 判断依頼

以下 2 点決めてほしい (決定後 Win版 or VSCode版 で実装):

1. **3 ALL tasks の扱い**: 案 A / B / C / 別案 (user と相談推奨)
2. **新規 ALL 追加の是非**: wbs.add_task で 'all' を今後も valid として許すか、完全廃止 (required = per-instance のみ)

## 関連 commit

- PS#6 S22 (232b2783): tools-hub wbs.* dispatch bug 修復
- PS#6 S23 (<TBD>): wbs.add_task required instance 防御

## 関連メモリ

- `memory/project_20260420_ps6_s22.md` (S22 bug fix)
- `memory/project_20260421_ps6_s23.md` (S23 required instance)
