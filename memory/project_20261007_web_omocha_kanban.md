---
name: CI ゲートの機械可読フォーマットと Flutter 実装の落とし穴 (Web cloud セッション実測)
description: my_web_app の PR CI ゲート (minimal E2E / high-risk ultrareview / kAllAppRoutes) が要求する厳密な文字列形式、ci-auto-fix bot の挙動、IntrinsicHeight+ListView の実行時 assert、AssetManagementPage の時刻源。Flutter/Dart SDK の無いクラウド環境での検証戦略。
type: project
---

## 1. 新規 route は 2 箇所に登録が必須

`lib/main.dart` の `onGenerateRoute` に足すだけでは CI が落ちる。
`test/routes/app_route_names.dart` の `kAllAppRoutes` にも**同じ文字列**を追加する
(`route_url_sync_test.dart` が main.dart と完全一致を検証)。今回 `/agent-board` で踏んだ。

## 2. PR 本文の機械可読ゲート形式 (チェックボックス文言では通らない)

`scripts/check_minimal_e2e_gate.py` / `scripts/check_high_risk_ultrareview_gate.py` は
**ラベル付き 1 行**を正規表現で探す。PR テンプレートのチェックボックス文 (例:
「E2E を含めない場合の例外理由」) は `e2e[- ]exception` に**マッチしない**。

```
- E2E-Exception: <理由>
- High-Risk-Ultrareview-Exception: <理由 (ラベル除去後 12 文字以上)>
```

- high-risk ゲートは本文に `Claude Code #1` の記載も要求する。
- **重要**: high-risk ゲートは PR 本文の `edited` イベントでは**再実行されない**。
  push / synchronize でのみ走るので、本文を直したら空コミットなどで再走させる。

## 3. ci-auto-fix bot は commit を push してくる

`.github/workflows/ci-auto-fix.yml` が `dart fix` / `dart format` / `deno fmt` を自動適用して
ブランチに push する。その結果、元の commit の CI は `action_required` のまま止まる (失敗ではない)。
bot の `deno fmt` と main 側の変更で**コンフリクトが起きる** (今回 `supabase/functions/growth-hub/index.ts`)。
解決後は `git diff origin/main -- <file>` が空であることを確認する。

## 4. analysis_options は warning でなく error

`require_trailing_commas` / `prefer_const_constructors` / `library_directive_not_first` は **error** 扱いで
`flutter analyze` が 0 error 強制のため落ちる。

- 安定する書き方: 最後の引数をコレクションリテラルにし、`]` と `)` を同じ行に置く / ローカル変数へ分割する。
- `library;` は**ファイル先頭**。import の後ろの doc comment の下に置くと `library_directive_not_first`。

## 5. `IntrinsicHeight` で `ListView` を包むと実行時に落ちる

`RenderViewport does not support returning intrinsic dimensions` を投げる。
高さを合わせたい箇所は、スクロールしない `Column` + `for (final x in items.take(n)) row(x)` に置き換える。

## 6. `AssetManagementPage` の時刻源は `debugCalendarNow` で上書きできない

- `_todayDateKey()` は `_dateOnly(DateTime.now())`
- `_currentSalaryCycleKey()` は `_now` (= 実 `DateTime.now()`)

→ テストで固定日を使うと salaryDay (既定 25) 跨ぎで落ちる。資産 dateKey と支払い monthKey を
**両方**実 `DateTime.now()` 基準に揃えるのが正解。

## 7. クラウド (Linux) セッションの環境差分

- **Flutter / Dart SDK は無い** → `flutter analyze` / `flutter test` はローカル実行不可。
  検証は CI のみ。ローカルでは波括弧バランス・API 互換性の目視確認に留める。
- `memory/` は **リポジトリ内** (`/home/user/my_web_app/memory/`)。
  `/wrap-up` skill が書いている Windows パス `C:\Users\kanta\.claude\projects\...` は存在しない。
- `notebooklm` CLI は**未インストール** → wrap-up Step 3 はスキップになる。
- `SUPABASE_ANON_KEY_PROD` は**未設定** → wrap-up Step 5.5 の WBS-SYNC curl / 自己検証は実行不可。

**Why:** クラウドセッションは Windows 版と前提が違うため、skill をそのまま実行すると途中で止まる。
**How to apply:** クラウドで `/wrap-up` を回すときは memory/ をリポジトリ内パスに読み替え、
NotebookLM と WBS-SYNC は**スキップを明示**して報告する (黙って飛ばさない)。

## 8. 今セッションの成果物 (merge 済み)

| PR | 内容 | merge commit |
|----|------|--------------|
| #4304 | OMOCHA WORKS 自律運用コンソール (`/autonomous-ops-console`) | `c477d02` |
| #4324 | GitHub Actions 実データ化 EF + `grill-me` skill | `93b1798` |
| #4396 | AI エージェント カンバン盤 (`/agent-board`) | `f613bc3` |

- `/agent-board` は `wbs_tasks` を RLS 準拠で読み、Realtime + 60 秒フォールバックで 4 列
  (未着手 / 進行中 / ブロック / 完了) を更新。ログイン必須 (未ログインは導線のみ)。
- **ユーザー側の残作業**: fine-grained PAT (対象 `my_web_app` / Actions: read + Metadata: read) を発行し
  Supabase Function Secret `GH_ACTIONS_READ_TOKEN` に設定するまで、OMOCHA WORKS はシミュレーション表示のまま。

## 9. wrap-up 実行時のスキップ記録 (2026-10-07)

- **Step 3 (NotebookLM Master Brain 蓄積): スキップ** — `notebooklm` CLI がこのクラウドコンテナに未インストール。
  memory/ へのローカル保存 (= リポジトリ内 `memory/`) は実行済み。次回 Windows 版セッションで
  `notebooklm use ea6cff25` → `notebooklm source add memory/*_20261007_web_omocha_kanban.md` を実行して追いつかせる。
- **Step 5.5 (WBS-SYNC blocking): skip-wbs-sync** — `SUPABASE_ANON_KEY_PROD` が未設定のため
  `tools-hub` への `wbs.update_progress` / `wbs.list_tasks` curl が実行不可。
  本セッションの成果はすべて PR (#4304 / #4324 / #4396) として main にマージ済みで追跡可能。
  WBS タスク側の progress 反映は次回 key のあるインスタンスから実施する。
