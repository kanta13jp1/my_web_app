# セッション 8h+ 長時間化 対策 3 点 全インスタンス周知

**起票**: PS版#3 S26 (2026-04-21 07:15 JST)
**起票元**: ユーザー directive (2026-04-21 07:07 JST) 「8h 以上セッションが続いています。異常な状態だと思うので原因を調査してください → 対策案を優先度順にすべて実施してください」
**ステータス**: 自分 (PS#3) 先行実施済・他 instance 追従 & 運用周知

---

## 原因 audit 結果 (PS#3 S26 分析)

対象セッション: `2c75c51b-0399-48f8-a9db-096bf07f9ba0.jsonl`

| 測定項目 | 値 |
|---|---|
| セッション span | 2026-04-20T13:24Z → 22:06Z = **8h42m** |
| user 手入力 text 件数 | **3 件** (PS#3 起動 / WBS 要望 / summary 継続) |
| last-prompt 総数 | 31 件 (28/31 は ScheduleWakeup auto) |
| 最大 idle gap | 12718s (3h32m) + 12469s (3h28m) = **7h idle** |
| 実作業時間 | 約 1.5-2h (Sierra seed + WBS UI 5 site + rebase push) |
| 無駄待機 (dart format pipe hang) | 180s × 3 + flutter analyze 300s × 複数 = **30-40 min** |

**根本原因** = idle gap (80%) + ScheduleWakeup 自動連鎖 + dart format pipe hang。プロセス暴走ではない。

---

## 対策 3 点 (優先度順に実施)

### P1: dart format pipe hang 回避テンプレ化 (実施済)

**変更 2 箇所**:
1. `~/.claude/hooks/inject-rules.txt` `[DART-FORMAT]` セクション拡張 — 「絶対パス + pipe なし」正規テンプレ追記 (毎ターン system-reminder 注入)
2. `docs/instance-constraints.md` 制約発見ログに新規 3 行追加 (PS#3 S26 発見)

**使い方 (全 instance)**:
```bash
# ❌ 禁止テンプレ (cygwin + pipe buffering で hang)
cd <worktree> && dart format <file> 2>&1 | tail -5

# ✅ 正規テンプレ (絶対パス + pipe なし)
dart format C:/absolute/path/file.dart 2>&1
```

exit code のみ必要 → `--set-exit-if-changed` 付加。pipe は完全禁止。

---

### P2: ScheduleWakeup 深夜抑制 (実施済)

**変更 1 箇所**:
- `~/.claude/hooks/inject-rules.txt` 末尾に `[SCHEDULE-WAKEUP]` 新ルール追加

**運用原則**:
- 深夜 JST 02:00-06:00 は ScheduleWakeup 呼出禁止
- 連続 3h+ idle gap 検知 → 作業中断 + wrap-up → session 終了
- `delaySeconds` は **1800 (30 min) 以内** を上限
- 「user input なしで 2 回連続自動起動」発生 = 停止サイン (暴走防止)

---

### P3: compaction 継続セッション短時間化 (実施済)

**変更 1 箇所**:
- `~/.claude/hooks/inject-rules.txt` 末尾に `[COMPACTION-RESUME]` 新ルール追加

**運用原則**:
- context 限界 → compaction → summary 継続時は **wrap-up だけで終わる** 短 session に
- 新規大規模タスクを summary 継続セッションに詰め込まない
- 目安: compaction 後 **90 min 以内** で commit + roadmap + memory + 終了
- 次タスクは **新セッション**で起動

---

## 検証チェックリスト (各 instance でセッション冒頭に確認)

- [ ] `~/.claude/hooks/inject-rules.txt` が最新 (grep `SCHEDULE-WAKEUP` で 1 行 hit する) か
- [ ] dart format 実行時に pipe を使っていないか (`dart format <絶対パス> 2>&1` 単発)
- [ ] idle gap 3h+ になる前に wrap-up → session 終了判断をしているか
- [ ] compaction 直後に新規大規模タスク追加をしていないか

違反検出 → `docs/instance-constraints.md` 制約発見ログに追記 + memory `feedback_correction_YYYYMMDD_*.md` 保存。

---

## PS#3 からの handoff notes

- inject-rules.txt は personal `~/.claude/` 配下で worktree 外 → git にも入らない。他 instance でも同一ファイルが読まれる (全 Claude Code CLI 共有)
- 追加 3 rule は 2026-04-21 以降の全セッションで system-reminder 注入される
- Win版 Option A (SessionStart hook) 実装完了時にこの 3 rule も hook 内で強制実行できるか検討推奨

Philosophy 9 原則:
- 原則 3 (優しい mentor): 失敗パターン即 rule 化 = 次回同じ轍を踏まない ✅
- 原則 6 (資本=時間): 7h idle 撲滅で実作業比率 20% → 80% に上昇 ✅
- 原則 9 (ウェルビーイング): 深夜 wake 抑制で user 睡眠保護 ✅

3/9 ✅ (小規模 infra 変更のため採点控えめ)
