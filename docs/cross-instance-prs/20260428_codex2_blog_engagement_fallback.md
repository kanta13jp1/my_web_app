# Cross-Instance PR: blog-engagement Gemini fallback

**作成**: Codex#2 / 2026-04-28
**依頼先**: PS版#1 / PS版#2
**優先度**: P1 — GHA fallback 広域ロードマップ
**branch**: `codex/codex2-blog-engagement-fallback`

---

## 背景

`docs/DEV_PROCESS_MULTI_AI.md` で `blog-engagement.yml Gemini fallback` が P1 / 2026-04-28 の要対応として残っていた。

既存の `scripts/blog_engagement.py` は Claude API が使えない場合、Gemini を試さず template 返信へ落ちていた。

---

## 実施内容

- `scripts/blog_engagement.py` に Claude → Gemini → template fallback を追加
- `GEMINI_API_KEY` を `blog-engagement.yml` から渡すように変更
- dev.to dry-run 時に `replied` が未定義になり得るバグを修正
- `DEV_PROCESS_MULTI_AI.md` / `AI_FALLBACK_RUNBOOK.md` の状態を更新

---

## 検証

- `python -m py_compile scripts/blog_engagement.py` 実行予定
- `git diff --check` 実行予定
- API 実呼び出しは secret が必要なため未実施予定

---

## 残リスク

- Gemini API の実レスポンス検証は GitHub Actions / secrets 環境で確認が必要。
- 自動返信内容は外部公開コメントになるため、初回は `workflow_dispatch dry_run=true` で確認推奨。
