---
name: CI ゲートの現況 (2026-11 実測) と Supabase/Flutter 実装の落とし穴
description: my_web_app の PR ゲート 3 種 (minimal E2E / high-risk ultrareview / design a11y) の現在の要求と blocking 可否、CCR 経由の auto-merge、Postgres CHECK の制約、Slider の value 範囲、クラウドセッションの Remote Control 可否。
type: project
---

## 1. PR ゲート 3 種の現況 (2026-11-28 実測)

| ゲート | blocking | 通し方 |
|---|---|---|
| `PR minimal E2E declaration` | **する** | 本文に `- E2E-Exception: <8 文字以上の理由>` の 1 行。テンプレのチェックボックス文言は**マッチしない** |
| `High-risk ultrareview gate` | **する** | 本文に `- Reviewer: Claude Code #1` と `- High-Risk-Ultrareview-Exception: <12 文字以上>` |
| `Design accessibility audit` | **しない** (`continue-on-error: true`) | `## Design Accessibility Audit` セクション。未実行なら `not-run` と理由を書く |

- 3 つとも `--body-file` + `--changed-files` (design a11y は `--changed-files-status`) で**ローカル検証できる**。
- `--emit-snippet` / `--emit-exception "<理由>"` / `--emit-evidence` で雛形を出せる。
- design a11y は `docs/DESIGN_ACCESSIBILITY_AUDIT.md` の方針 (2026-09-12) で
  「推奨であり merge gate ではない / 実行していない監査を pass と書かない」と明記されている。
  **実機ブラウザの無いクラウドセッションでは `Design-Plugin-Status: not-run` が正しい答え**。
- migration を含む PR は high-risk ゲートが発火する (`supabase/migrations/` が high-risk path)。

## 2. `AI Review Gate` は base SHA の一致を要求する → auto-merge に委ねる

`scripts/ai_review_merge_gate.py` が
`evidence.workflow_sha == PR の base sha` を検証する。main が活発なため、
`update-branch` → CI 実行中に main が進む → `Review source is not current trusted base` で落ちる。

手動で追いかけると終わらないので、グリーンを確認したら auto-merge を有効にする:

```bash
gh api -X PUT repos/kanta13jp1/my_web_app/pulls/<n>/ccr/auto_merge -f merge_method=squash
```

**GraphQL (`enablePullRequestAutoMerge`) は Claude Code セッションから 403 で使えない。**
auto-merge / review thread の解決 / draft 切替は `.../ccr/...` の REST ルートを使う。

## 3. Postgres の CHECK 制約に副問い合わせは書けない

曜日ごとの値を `integer[]` 1 列で持ち、`check ((select bool_and(m between 0 and 1440) from unnest(...)))`
と書こうとしたが、**CHECK 制約に副問い合わせは使えない**。
曜日ごとに列を分けて 1 列ずつ `check (x between 0 and 1440)` にするのが素直。

`feature_releases.category` には制約が無く自由文字列。既存の語彙は
`learning` / `productivity` / `ai` など。

## 4. `Slider` の `value` は `max` を超えると assert で落ちる

「毎日 N 分増やす」のような**後からプログラムで値を押し上げる操作**があると、
`Slider(value: minutes.toDouble(), max: 720)` が範囲外で例外になる。
DB の CHECK 上限 (0〜1440) と `max` を揃え、`value` 側も `clamp` する。

## 5. `clamp` の戻り型は Dart の特別規則で決まる

`num.clamp` は本来 `num` を返すが、**レシーバと両引数がすべて `int` なら `int`、
すべて `double` なら `double`** という言語仕様の特別規則がある。
`int get x => raw.clamp(0, 1440);` は通るが、`double get y => (a / b).clamp(0, 4);`
は引数が `int` リテラルなので `num` になり型エラーになる。`clamp(0.0, 4.0)` と書く。

## 6. `avoid_dynamic_calls: error` 下での行パース

`Map<String, dynamic>` から読むとき `(row['id'] ?? '').toString()` は **dynamic 呼び出し**で
エラーになる。リポジトリの既存パターン (`lib/models/agent_board_models.dart`) に合わせて
`(row['id'] as String?) ?? ''` と書く。`is int` / `is num` / `is String` での型昇格は安全。

## 7. `analysis_options.yaml` の `errors:` は linter で有効な規則にしか効かない

`prefer_final_parameters: error` と書かれているが `linter.rules` に無いため**発火しない**
(既存コードの関数引数に `final` が付いていないのはこのため)。
一方 `prefer_final_locals` / `avoid_dynamic_calls` / `require_trailing_commas` /
`use_build_context_synchronously` は `linter.rules` にあるので**本当にエラーになる**。

## 8. クラウドセッションから user のマシンには繋げなかった (2026-11-28 時点)

- Computer Use のツール (`mcp__computer-use__*` / `mcp__remote-devices__computer_*`) は
  このクラウドセッションに**提供されていない**。
- `list_computer_folders` の結果: `kanta` の 3 フォルダ
  (`company` / `mighty-link-ai-connect` / `my_web_app`) がすべて `cannot_be_used`、
  reason=`not_available` (そのコンピュータがクラウドセッションに提供していない)。
- → Antigravity など**ローカル IDE の直接操作はできない**。引き継ぎは
  `docs/cross-instance-prs/` のドキュメント + 貼り付け用プロンプトで行う。

## 9. 今セッションの成果物

- PR #6496 `/deadline-weight`「締め切りの重さ」(migration 2 テーブル + 純粋関数 + 画面 + テスト)
- `docs/cross-instance-prs/20261128_antigravity_deadline_weight_followups.md` (Antigravity 向け引き継ぎ)
- **未了 (引き継ぎ済み)**: Supabase 本番への migration 適用 / デザイン a11y 監査 /
  既存データ (`life_goals` `wbs_tasks`) からの取り込み
