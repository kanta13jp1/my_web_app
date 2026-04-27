---
title: "Claude Code Schedule で「日次開発」を自動運転にする — daily-development タスク設計"
tags: claude-code,自動化,個人開発,scheduled-tasks
published: true
---

# Claude Code Schedule で「日次開発」を自動運転にする — daily-development タスク設計

## なぜ「毎朝のルーチン開発」を AI に任せるのか

個人開発で一番続かないのは **毎日の小さな積み上げ** だ。

- ロードマップを読み直す
- 今日の進捗を seed migration で残す
- ブログ下書きを 1 本書く
- ROADMAP_LOG に追記する
- commit / push する

どれも 5 分で終わるが、「やる気が出ないと飛ばす」を 1 週間続けると 1 ヶ月分の差になる。

自分株式会社では、この **毎朝のルーチン開発** を Claude Code Schedule に任せている。`daily-development` という SKILL を 1 個用意して、cron で毎日 1 回起動するだけだ。

---

## SKILL.md の構成

```text
~/.claude/scheduled-tasks/daily-development/SKILL.md
```

中身は 7 ステップのチェックリストになっている:

1. **Master Brain 参照** — `memory/MEMORY.md` を最初に読む
2. **ロードマップ確認** — `docs/GROWTH_STRATEGY_ROADMAP.md` 末尾から次タスクを拾う
3. **ダミーデータ修正** — 実装の穴を最優先で埋める
4. **ロードマップ実装** — 短期計画の未完了タスク
5. **技術ブログ投稿** — JA + EN draft を `docs/blog-drafts/` に追加
6. **開発実績記録** — `supabase/migrations/` に seed 追加
7. **コミット & プッシュ** — main にデプロイ

ポイントは **「ユーザー不在で自律実行する」** 前提でステップを書くこと。質問が必要なステップは入れない。

---

## 衝突回避: timestamp 採番ルール

scheduled task が一番事故りやすいのは **migration timestamp の衝突** だ。

並行で他インスタンス (PowerShell 版・Windows アプリ版) が seed を追加すると、`SQLSTATE 23505 (schema_migrations_pkey)` で deploy が即死する。

回避策はシンプル:

```bash
# 採番前に必ず今日の最新 timestamp を確認
ls supabase/migrations/ | grep "^$(date +%Y%m%d)" | sort | tail -3
```

最新 + 30 分 (= 003000) ではなく **+10 分刻み** で詰めて、衝突しても rename しやすくする。

---

## Bash 並列禁止ルール

scheduled task 環境では **Bash の並列発行を禁止** している。

理由は permission stream が不安定で、parallel Bash 1 本が permission deny されると残り全部が cancel されて作業が中断するからだ。

```yaml
# NG: 同一メッセージで複数 Bash を発行
# OK: 1 Bash 完了後に次の Bash を発行
```

Read / Glob / Grep など permission 不要な tool は parallel で問題ない。Bash だけが特別扱い。

---

## Anthropic outage 時のフォールバック

Anthropic API が落ちた日は Claude Code Schedule も止まる。

そのとき何が止まるかを事前に **fallback runbook** にまとめておく:

| タスク | Primary | Fallback |
|---|---|---|
| Migration seed (定型) | Codex CLI | GitHub Copilot |
| Flutter widget 修正 | Gemini Code Assist | Copilot |
| 競合 21 社調査 | NotebookLM Deep Research | WebSearch |
| アーキテクチャ判断 | Claude Code | **48h pause 許容** |

`daily-development` のうち判断系 (Step 1 + Step 4) だけ 48h 止まっても、定型系 (Step 5 + Step 6) は他 AI で継続可能。

Schedule タスクを **「Claude 必須タスク」と「他 AI 代替可能タスク」** に分けて設計するのがコツ。

---

## 実運用 KPI

| 指標 | Before (手動) | After (Schedule) |
|---|---|---|
| 1 日あたり commit 数 | 0〜2 | 1〜3 |
| ブログ下書き完成数 | 月 3 本 | 月 25 本+ |
| ロードマップ未更新日数 | 5〜10 日 | 0 日 |
| 朝の「やる気」必要量 | 100% | 0% |

ブログ下書きに関しては `docs/blog-drafts/` に毎日 1 本以上 ストックされ、T-1 ブログ dispatch ルーチン (PowerShell 版#2) が dev.to / Qiita に順次投稿してくれる。

---

## まとめ — 「毎日の自分」を外注する

- Schedule タスクは `~/.claude/scheduled-tasks/<name>/SKILL.md` に書く
- ステップは **ユーザー不在前提** で記述する (質問なし・推測 OK)
- migration timestamp は **+10 分刻み** で衝突回避
- Bash は **並列禁止** (permission stream 対策)
- Anthropic outage 時の **fallback runbook** を併設

朝起きて何をやるか考えるエネルギーは、もっと面白いことに使ったほうがいい。
ルーチンは Claude Code Schedule に任せて、自分は **「昨日の自分との差分」** だけ見ればいい。
