---
date: 2026-04-19
from: WEB版#2
to: Windowsアプリ版
status: pending
priority: medium
---

# NotebookLM Master Brain 同期依頼 (2026-04-19 WEB#2 wrapup-hook メモリ)

## 概要

WEB版#2 セッションで「PostToolUse wrapup-nudge hook の正規表現厳格化」に関する
3 件のメモリファイル + 索引を作成し main へマージ済み。WEB版はサンドボックス上で
`notebooklm` CLI のブラウザ OAuth (`~/.notebooklm/storage_state.json`) が使えないため、
Windows版から Master Brain への source add を依頼する。

## 依頼内容

次回セッション冒頭で以下を順に実行:

1. `notebooklm status` で認証確認 (期限切れなら `notebooklm login` で再認証)
2. `notebooklm use jibun-master-brain` で Master Brain ノートブックに切替
3. 以下 3 ファイルを source add:
   ```bash
   notebooklm source add memory/feedback_success_20260419_wrapup_hook.md
   notebooklm source add memory/feedback_correction_20260419_wrapup_hook.md
   notebooklm source add memory/project_20260419_wrapup_hook.md
   ```
4. 追加確認: `notebooklm ask "2026-04-19 の wrapup hook 正規表現厳格化から学んだことは？"`
   → 3 ファイルの内容が回答に反映されれば成功
5. 完了後、このファイルを `docs/cross-instance-prs/done/` に `git mv` で移動してコミット

## 関連ファイル

- `memory/feedback_success_20260419_wrapup_hook.md` — hook 厳格化の成功記録
- `memory/feedback_correction_20260419_wrapup_hook.md` — Read→Edit 前提 / branch 乖離時の確認ルール
- `memory/project_20260419_wrapup_hook.md` — PostToolUse wiring 参照実装
- `memory/MEMORY.md` — 索引 (新規作成)

## 完了条件

- [ ] Master Brain に 3 ファイル追加完了 (`notebooklm source list` で確認)
- [ ] `notebooklm ask "..."` で内容が参照可能
- [ ] このファイルを `docs/cross-instance-prs/done/20260419_notebooklm_master_brain_sync.md` へ移動
- [ ] 完了コミットを main に push

---

## 背景: なぜ WEB版から直接できないのか

サンドボックス環境 (Linux, 非対話) では以下のブロッカーがあり Master Brain 書込み不可:

1. `notebooklm login` は Google OAuth をブラウザで要求 → headless/非対話では突破不可
2. `~/.notebooklm/storage_state.json` (Google セッション Cookie = 全権アクセス) を
   sandbox に持ち込むのは `.gitignore` 管理 + CLAUDE.md の記載通りセキュリティ上禁止
3. サンドボックスはセッション毎に破棄されるため、一度 login しても永続化されない

Windows版は `notebooklm login` 済みで storage_state.json が永続化されているため、
コマンド 3 行で完了する軽作業。

宛先インスタンスが完了したら `done/` に移動してください。
