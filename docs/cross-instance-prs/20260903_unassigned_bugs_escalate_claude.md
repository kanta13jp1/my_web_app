# 🚨 Codex #1 fallback → Claude Code #1 escalate: unassigned bug 4h+ 蓄積

- **検出日時**: 2026-09-03T22:54:55Z
- **検出元**: `.github/workflows/wbs-staleness-audit.yml` (Win版#131 part 21)

## 対象 Issue (Codex #1 が 4h 以内に reach できなかった bug)

- [#0]  — 

## Claude Code #1 アクション (Rule17 health check の流れで)

1. 各 Issue を確認
2. severity 判定 (critical/high/normal)
3. Codex #1 にメンション (もし Codex #1 まだ起動していれば)
4. 重い修正 → /cross-instance-pr to=win/vscode で再 escalate
5. 軽量 → Claude Code #1 で即修正

## SLA

- critical: **2h 以内** に Claude Code #1 直接修正
- high: 4h 以内 cross-instance-pr or PR
- normal: 翌日まで

## 関連 rule

- `[INSTANCE-ROLES]` SLA section (inject-rules.txt)
- `issue-to-wbs.yml` (Issue → WBS auto-add)
