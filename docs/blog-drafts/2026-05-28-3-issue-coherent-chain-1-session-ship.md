---
title: "1 ユーザー要望を 3 Issue に分解して 1 セッションで配り切る — 「coherent chain triage」パターン"
emoji: "🧩"
type: "tech"
topics: ["githubissues", "productmanagement", "triage", "workflow", "indiedev"]
published: true
---

## TL;DR

ユーザーが「給与明細を取り込んで残高をちゃんと出したい」みたいに **1 つの "ふんわりした" 要望** を持ってきたとき、それを 1 つの巨大 Issue に押し込めると着地しない。

代わりに、**過去・未来・データソース** の 3 角度に分解して、別々の Issue + 別々の WBS タスクとして配ると、**1 セッションのトリアージで 3 つすべてが流れ始める**。

自分株式会社の Win 版 part 236 (2026-05-25) で、給与明細関連の要望 1 件を以下の 3 Issue に分解し、それぞれ migration コミット + push まで 1 セッションで配り切った。

- [#3003](https://github.com/kanta13jp1/my_web_app/issues/3003) — **過去視点**: 給与明細 ingestion パイプライン (= データソース層)
- [#3006](https://github.com/kanta13jp1/my_web_app/issues/3006) — **未来視点**: 使いみち AI action (= 支出計画レコメンド)
- [#3007](https://github.com/kanta13jp1/my_web_app/issues/3007) — **現在残高視点**: 可処分残高 AI action (= 残り使える額の試算)

再現可能なトリアージ手順としてメモする。

---

## 起きていたこと

ユーザーが Slack/Issue/口頭で「ふんわり要望」を出してくる。例:

> 「給与明細をちゃんと取り込んで、今月いくら使えるか出してほしい」

このまま 1 Issue にすると、たいてい次のどれかになる:

- **巨大 Issue 化**: 要件が膨らみすぎて誰も着手しない (= triage dead lock)
- **インポート機能だけ作って残高が出ない**: ユーザーから見て価値ゼロのまま終わる
- **AI レコメンドだけ豪華**: データソースが空で hallucination

つまり、要望を **「ユーザーが見たいゴール」だけで切ろうとすると着地しない**。

---

## 解決パターン: 過去 / 未来 / 現在 の 3 角度に分解する

実装計画ではなく、**情報の流れる方向** で 3 つに切る。

| 角度 | 役割 | 例 (給与明細) |
|------|------|---------------|
| **過去視点** | データソース層 — 既に起こったことを取り込んで保存 | 給与明細 PDF/CSV ingestion パイプライン (#3003) |
| **未来視点** | アクション層 — これから何をすべきか提案 | 「今月の使いみち」AI レコメンド (#3006) |
| **現在残高視点** | 計算層 — 今この瞬間の状態を集計 | 可処分残高 = 収入 - 固定費 - 既支出 (#3007) |

このやり方の効くポイントは、**3 つが別々のチームに渡せる** こと。

- 過去視点 (= ingestion): Edge Function + 外部 API 連携 → バックエンド寄り
- 未来視点 (= AI action): プロンプト設計 + UI → AI 寄り
- 現在残高視点 (= 計算): SQL + materialized view → DB 寄り

依存はあるが、**スキーマと AI プロンプトを Win Claude (= architect/設計) 側で先に切る** ことで、3 つの実装を **Win Codex (= 実装) 側に並列に投げられる** ようになる。

---

## 1 セッションでやったこと (= part 236 実例)

セッション約 1 時間で全部やった作業内訳:

1. **要望の 3 角度分解** (5 min)
   - 「給与明細を取り込んで残高を出す」を上の表に沿って分解
   - GitHub Issue の draft を 3 本書く

2. **label 事前確認** (3 min) — ここで `gh label list | grep priority` を打つ
   - `priority:high`, `priority:medium`, `priority:low` は存在
   - `P2` は **存在しない** → 当初書いていた `P2` ラベルを `priority:medium` に pivot
   - 後で issue create が一発で通る

3. **Issue 起票 × 3** (10 min)
   - 各 Issue の body に "過去 / 未来 / 現在" のどの角度か明記
   - 互いに依存リンク (`Depends on #3003`) を貼る

4. **WBS migration × 3 を書く** (30 min)
   - `supabase/migrations/20260525150000_wbs_payslip_ingestion_issue3003.sql`
   - `supabase/migrations/20260525160000_wbs_salary_spending_ai_issue3006.sql`
   - `supabase/migrations/20260525170000_wbs_disposable_balance_ai_issue3007.sql`
   - 各 migration で WBS task 行を `ON CONFLICT DO NOTHING` で挿入 (= idempotent)
   - 担当を Codex 側に振る (= 振分 schema + プロンプト = Win Claude / 実装 = Win Codex)

5. **3 commit + push** (5 min)
   - `4b76bd19e`, `0621b18bd`, `a13a4f123`
   - PR は同 1 本にまとめても、3 本に分けてもよい (今回は 3 本)

6. **Codex backlog への配置** (5 min)
   - 8/13 - 9/17 の Codex sprint chain に 3 task を順に並べる
   - 依存順 = #3003 → #3007 → #3006

セッション終わったとき、**Codex は次のスタンドアップで「3 件 ready」を見つけられる状態** になっていた。

---

## なぜ「label 事前確認」が効くのか

地味だが、これが 1 セッション完結の鍵だった。

`gh issue create --label P2` を 3 連投で実行して、3 件とも `label 'P2' not found` で落ちたら、**3 回のエラーループ + 修正 commit + 再 push** が走る。これだけで 15 分溶ける。

最初に `gh label list | grep priority` で 1 回確認しておけば:

- 存在しない label を 0 回叩く
- 3 件すべて初回 issue create が緑になる
- セッション全体が「ぐるっと回す」フェーズで終わる (= retry なし)

**ラベル / branch 名 / WBS column などの "存在チェック"** は、複数 Issue を同セッションで配るときの first step として固定するとよい。

---

## やってはいけない分解

似た 3 分解で失敗するパターンも書いておく。

- **実装層で 3 分解する** (= "backend Issue / frontend Issue / API Issue")
  - → ユーザーから見た価値が 1 つも完成しない (= 全部マージするまで何も使えない)
- **画面で 3 分解する** (= "一覧画面 / 詳細画面 / 編集画面")
  - → データモデルが揃わず、3 画面とも空のまま着地する
- **時間軸で 3 分解する** (= "今週やる / 来週やる / 来月やる")
  - → triage ではなくスケジュール会議になり、その場で着手判断が下せない

うまくいくのは **データの流れ (過去 → 現在 → 未来)** で切るときだけ。なぜなら、

- 過去視点 (= データ取り込み) は単体で価値がある (生データを見られる)
- 現在残高 (= 集計) は過去視点を 1 行でも取り込めば動く
- 未来視点 (= AI action) は現在残高があれば proof-of-value が見せられる

つまり **小さい順に独立に「Hello World 価値」が出る** 切り方になる。

---

## 次にやること

- 部 236 chain を Codex がどれくらい速く回せるか測定する
- `priority:medium` のような "存在する label のリスト" を `gh issue create` の wrapper script に焼き込む (= label 不一致を CLI 側で fail-fast にする)
- 「給与明細」以外の領域 (= 資産 / 健康 / 学習) でも 3 角度分解が効くか試す

---

## 関連リンク

- [#3003](https://github.com/kanta13jp1/my_web_app/issues/3003) — 給与明細 ingestion pipeline
- [#3006](https://github.com/kanta13jp1/my_web_app/issues/3006) — 使いみち AI action
- [#3007](https://github.com/kanta13jp1/my_web_app/issues/3007) — 可処分残高 AI action
- 自分株式会社: <https://my-web-app-b67f4.web.app/>
