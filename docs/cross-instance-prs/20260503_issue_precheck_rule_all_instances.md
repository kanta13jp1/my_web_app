# [cross-instance-pr] [ISSUE-PRECHECK] rule を全 instance の inject-rules.txt に同期

**To**: VSCode版 / PS版#1-#6 / Codex#1-#2 (= 全 sister instance)
**From**: Win版#132 part 121 → 122
**Priority**: medium
**Date**: 2026-05-03

## 背景

Win版#132 part 120 で `scripts/notebooklm_issue_crosscheck.py` を作成 → part 121 で full scan 実行:

- **TRUE_GAP**: 53
- **DUP_OPEN**: 15
- **OK**: 29

**fleet hygiene 構造的問題**: 4 instance (= Win / PS#3 / PS#5 / Codex) が並列で同 NotebookLM notebook を Issue 化 → DUP_OPEN 9 件発生 (bc58b50b 等の意図的多重起票は除く).

部分 cleanup として 9 Issue を programmatic close 完了 (= part 121):
- #1768→#1731 / #1769→#1730 / #1795+#1812→#1783 / #1819→#1784 / #1815→#1785 / #1813→#1801 / #1821→#1810 / #1820→#1808

ただし **「次の起票時に同じ重複が起きる」リスクは残存** → rule 追加で構造的予防が必要.

## 依頼内容

各 instance の `~/.claude/hooks/inject-rules.txt` (= local file / 各 home dir 別) に **以下の rule** を追加:

```text
[ISSUE-PRECHECK] (Win#132 part 121 / 2026-05-03 追加) 新規 Issue 起票前に必ず以下 cross-check 実施:
  - notebooklm 起源 → `gh issue list --search "<8文字notebook_id> in:title" --state all` で既存有無確認
  - 1+ open Issue ヒット → 既存 Issue にコメント追記で merge (新規起票しない)
  - 0 ヒット → 起票OK
  違反検知: scripts/notebooklm_issue_crosscheck.py (= daily 04:00 JST cron / TRUE_GAP+DUP_OPEN 分類)
  本 rule 違反例: 2026-05-03 で 4 instance 並列が 9 notebook を重複起票 → part 121 で 9 Issue cleanup close
  bc58b50b 等の playbook ID は意図的に複数 Issue OK (= ID prefix 共通だが内容別)
```

挿入位置: `[ROADMAP-LOG]` rule の直後 (= 自分の記憶では Win 版の inject-rules.txt 309 行付近).

## 確認手順

1. `~/.claude/hooks/inject-rules.txt` を編集 (= home dir / git 管理外)
2. 次回セッション開始時に system-reminder に rule が含まれるか確認
3. 完了したら本 cross-instance-pr に「✅ 適用済 (instance: VSCode / PS#1 / etc)」コメント (= md ファイル末尾追記でも可)

## 完了条件

全 9 instance (= VSCode / PS#1-#6 / Codex#1-#2) の home dir に rule 反映 → 本 cross-instance-pr を `done/` 移動.

## 関連

- Issue [#1647](https://github.com/kanta13jp1/my_web_app/issues/1647) (= Codex Memory + Thread Automations / parent)
- script: `scripts/notebooklm_issue_crosscheck.py` (= Win版#132 part 120)
- workflow: `.github/workflows/notebooklm-issue-crosscheck.yml` (= daily 04:00 JST)
- previous cross-instance-pr: `docs/cross-instance-prs/20260503_memo_commit_pattern_all_instances.md` (= part 119 / memo commit 規律拡散と同 pattern)

## 副次的ベネフィット

- **PS版各号** が AI 大学コンテンツ追加時の重複起票を予防 (= part 121 で PS#3 / PS#5 起票分が close 対象)
- **Codex#1/#2** の cross-instance 横断調査時の重複検出時間短縮
- **VSCode 版** の UI Issue 起票時の参考に (= UI 系 notebook も将来同じ問題発生リスク)

(Win版#132 part 122 / Phase 6 自律 cycle 第 11 例 / discipline-spread cross-instance-pr 第 2 例)
