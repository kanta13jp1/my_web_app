# Issue Fix Plan #1638

- Issue: [[追加要望][P1] Claude Code未適用Notebookをセッション運用・Remote Control・Second Brainへ反映](https://github.com/kanta13jp1/my_web_app/issues/1638)
- Labels: enhancement,priority:high,automation,追加要望,ai-tool-update,wbs
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25352429339

## Goal

[追加要望][P1] Claude Code未適用Notebookをセッション運用・Remote Control・Second Brainへ反映

## Current Context

```text
## 背景

Codex #7 / 2026-05-02 セッションで `notebooklm list --json` を再実行し、NotebookLM intake gate を更新した。

- Notebook count: 90
- Routed candidates: 31
- Skipped notebooks: 59
- Harness notebook: `bc58b50b-5fc4-4840-9a62-b397d6d3b65a`
- Generated report: `docs/notebooklm-intake/latest-report.md`

既存Issueへ接続できたものは新規登録しない。以下は `ready_for_issue_or_wbs` のまま残った Claude Code 運用系 NotebookLM 項目。

- `Mastering Claude: A Guide to Intelligent Collaboration`
- `Code with Claude 開会の基調講演`
- `Anthropic Claude Design Plugin and Platform Ecosystem`
- `Claude Code Remote Control Guide`
- `Claude Code: The Agentic Future of Terminal Programming`
- `Claude API Cost Optimization Strategies`
- `Claude Code and Obsidian: Building Your AI Second Brain`

## 追加要望

上記Notebookを、Claude Code / Codex fleet のセッション運用に適用するか判定し、採用する内容を WBS / AGENTS / CLAUDE / hooks / GitHub Actions / issue-routing へ反映する。

優先して見る観点:

- Remote Control / terminal agent workflow を、Codex worktree isolation と衝突しない運用に落とす
- Second Brain / Obsidian 系の知見を NotebookLM intake gate と memory consolidation に接続する
- Claude API cost optimization を AI Tool Watch の cost controls route に接続する
- Code with Claude / platform ecosystem の内容は、公式 changelog で裏取りできるものだけ採用する
- Claude Code と Codex の担当分担を、WBS top pressure と自動化余地に合わせて見直す

## 受け入れ条件

- NotebookLM由来の主張は、公式ソースまたは既存 `ai_tool_watch.py` の検証結果に接続してから採用されている
- 重複Issueがある項目は新規Issueを作らず、既存Issueへコメントまたはリンクされている
- 採用項目が WBS / GitHub Issue / docs / hook / workflow のいずれかに必ず着地している
- 後続セッションが `docs/notebooklm-intake/latest-report.md` だけで未適用項目を再開できる

## 参照

```

## Autonomous Repair Loop

1. Reproduce the smallest failing path for this issue.
2. Apply the minimum safe fix on this branch.
3. Let normal CI run on the draft PR.
4. If CI fails on mechanical issues, `ci-auto-fix.yml` attempts `dart fix --apply` and `deno fmt`.
5. Merge only after CI is green and the issue scope is satisfied.

## Checklist

- [ ] Reproduction is clear
- [ ] Smallest safe fix is implemented
- [ ] Analyze/tests/CI are checked
- [ ] PR notes explain the change and the remaining risk
