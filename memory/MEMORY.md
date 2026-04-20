# MEMORY Index — 自分株式会社

Master Brain のローカル索引。各ファイルは `memory/` 配下に置き、日付 + スコープで命名。
NotebookLM Master Brain (jibun-master-brain ノートブック) にも同内容を蓄積する。

## 2026-04-20 (VSCode版 — DESIGN token batch template)

- `feedback_success_20260420_design_token_batch_template.md` — Python + dart fix + flutter analyze pipeline w/ full shade map (green/red/orange shade50-900) for 600+ Colors.X → hex replacements

## 2026-04-19 (PS版#5 — on-call バグ修正)

- `project_20260419_ps5.md` — CI修復(esm.sh→npm) + AI大学URL修正 + ホーム履歴recordFeatureTap統合

## 2026-04-19 (VSCode版 — wrapup hook tightening)

- `feedback_success_20260419_wrapup_hook.md` — PostToolUse 正規表現を厳格化して heredoc/echo 誤マッチを排除。`if: "Bash(git *)"` でさらに scope。ライブ検証成功。
- `feedback_correction_20260419_wrapup_hook.md` — Edit tool は Read 前提。指定ブランチと作業ブランチの乖離時はユーザー確認必須。
- `project_20260419_wrapup_hook.md` — PostToolUse hook の wiring (settings.json + shell script + jq + JSON out) 参照実装。

## 2026-04-19 (WEB版 — mobile setup)

- `feedback_success_20260419_web_mobile.md`
- `feedback_correction_20260419_web_mobile.md`
- `project_20260419_web_mobile_setup.md`

## 2026-04-17 (Windows版)

- `project_20260417_win_opus47.md`
- `project_20260417_win_web_disabled.md`

<!-- wrap-up 20260419
未完了: 0 件 (wrapup-hook タスクは完了・push 済み)

次回優先候補 (Step 6 参照):
- 🔴 指定ブランチ claude/fix-mobile-keyboard-overlap-6kjnm で実際の keyboard overlap を調査・修正
- 🟡 AI大学: 学習リマインダー通知バッチ (notification-center EF action)
- 🟡 Rule 17 WF health チェック (最近失敗した run の集計)
- 🟢 t-1 ブログ dispatch (未投稿 draft があれば)
-->
