# Cross-Instance PR: Codex#2 ops charter sync

**作成**: Codex#2 / 2026-04-28
**依頼先**: PS版#1 / Win版
**優先度**: MEDIUM — 12インスタンス運用の正本ズレ修正
**branch**: `codex/codex2-wip`

---

## 背景

User 指示で、今後は 12 インスタンス並行開発を前提に、作業と同時に運用改善も常に見る方針になった。

`docs/OPERATIONS_CHARTER.md` が追加された一方で、`CLAUDE.md` / `MULTI_INSTANCE_FLEET.md` / `CODEX_WORKFLOW.md` / `DEV_PROCESS_MULTI_AI.md` に古い Codex 役割定義が残っていた。

---

## 実施内容

- Codex#1 を「横断調査 / 修正PR / SQL・migration レビュー補助」に統一
- Codex#2 を「CI / 同期 / 運用 / EF(Deno)・GHA レビュー補助」に統一
- Claude Code を「設計判断 + 大きめ実装 + 既存設計沿い機能追加 + 統合」に再定義
- Gemini Code Assist / GitHub Copilot / Manus AI / NotebookLM の配置を routing に追記
- `MULTI_INSTANCE_FLEET.md` の Codex worktree 未作成表記と直 push 前提を修正

---

## 変更ファイル

- `CLAUDE.md`
- `docs/OPERATIONS_CHARTER.md`
- `docs/MULTI_INSTANCE_FLEET.md`
- `docs/CODEX_WORKFLOW.md`
- `docs/DEV_PROCESS_MULTI_AI.md`

---

## 検証

- `git diff --check` 実行済み (改行 warning のみ)
- docs-only 変更のため build / lint は対象外

---

## 残リスク

- `~/.claude/hooks/inject-rules.txt` は repo 管理外のため、この branch では更新していない。
- WBS / Notion / Slack の実データ同期は未実施。PS版#1 または Win版で確認が必要。
