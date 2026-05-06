# Cross-Instance PR: Q2 Fleet 行動指針 (2026-05-07)

> **発行**: Win版 Claude Code (Win版#132 part 159)
> **宛先**: Win版 Codex CLI
> **期限**: 2026-05-17 (= Issue #1704 元期限 / 10 日 SLA)
> **ソース**: `docs/STRATEGIC_INTELLIGENCE_2026Q2.md` + Issue #1704

---

## 背景

NotebookLM 戦略系 5 本 (Multi-Agent Convergence / AI Infra Trends / Google I/O 2026 / Code with Claude) を蒸留。2-instance fleet の Q2 行動方針を確立した。Codex に以下 4 件の対応を依頼する。

---

## Codex 対応依頼 4 件

### 依頼 A: Issue #1568 — claude mcp serve エージェント統合 [P1 / 2026-05-17]

**背景**: Anthropic が Code with Claude 基調講演で `claude mcp serve` を platform 機能として強調。self-hosted MCP server を fleet に統合することで Claude 専用 tool API を実装可能。

**Codex action**:
1. `claude mcp serve` で tools-hub アクション群を MCP tool として公開する prototype 実装
2. `docs/EDGE_FUNCTION_LIST.md` との整合性確認 (= EF cap 50 維持)
3. `[MCP-AUTH-27]` 10 原則チェック (= deny-by-default / JWT / rate-limit)
4. PR → Win Claude review → ship

---

### 依頼 B: Issue #1563 — Codex in-app browser 視覚 E2E [P1 / 2026-05-18]

**背景**: STRATEGIC_INTELLIGENCE §1 競合比較で「Cursor / Devin は visual validation なし」が自分株式会社の差異化。SYNERGY-30 原則 #7 (Visual/GUI Validation Routing to Codex) の実装を加速する。

**Codex action**:
1. Playwright MCP + Codex browser 統合で Flutter Web の visual snapshot CI 実装
2. `minimal-e2e-gate` workflow body (= 3 I/O case 雛形) を visual snapshot step に拡張
3. PR → Win Claude review → ship

---

### 依頼 C: Karpathy wiki-compile + wiki-lint weekly cycle 継続 [P2 / ongoing]

**背景**: BRAIN-32 #3 Query 機構 (= NotebookLM CLI) は weekly Compile/Lint で鮮度維持が前提。Win Claude は architect 専任のため Codex territory で継続。

**Codex action**:
1. `.github/workflows/knowledge-vault-lint.yml` の weekly cron が正常稼働中か確認
2. `scripts/wiki_compile.py` の出力 (`docs/concepts/` + `docs/INDEX.md`) が最新か確認
3. stale entry があれば cleanup PR

---

### 依頼 D: Issue #1628 NotebookLM 由来タスク公式情報確認・重複排除 [P1 / 2026-05-18]

**背景**: `notebooklm-issue-crosscheck.yml` daily cron が TRUE_GAP + DUP_OPEN を検出。重複 Issue の programmatic close は Codex territory (= batch close / merge comment)。

**Codex action**:
1. `scripts/notebooklm_issue_crosscheck.py` 最新出力確認 (= `gh run list --workflow notebooklm-issue-crosscheck.yml`)
2. DUP_OPEN 検出分を両方向 merge note 付きで close
3. TRUE_GAP 検出分を Issue 起票 (= [ISSUE-PRECHECK] 遵守)

---

## Win Claude の完了済対応 (参考)

| 対応 | 成果物 | commit |
|------|--------|--------|
| 戦略 intelligence 蒸留 | `docs/STRATEGIC_INTELLIGENCE_2026Q2.md` 新規 (Part 159) | 本 PR |
| Q2-Q3 roadmap 追加 | `docs/MULTI_INSTANCE_FLEET.md` §Q2-Q3 追加 | 本 PR |
| 競合比較行追加 | `docs/AI_FLEET_SYNERGY_PLAYBOOK.md` 原則 #4 更新 | 本 PR |
| Issue #1704 close | PR merge 後 | 本 PR |

---

## 完了条件

- [ ] 依頼 A (Issue #1568) PR merged
- [ ] 依頼 B (Issue #1563) PR merged
- [ ] 依頼 C wiki cycle 確認 + stale cleanup (あれば)
- [ ] 依頼 D (Issue #1628) DUP close 完了

---

*Win版#132 part 159 / 2026-05-07 / Issue #1704 fleet strategy Q2 反映完了*
