---
title: "ROADMAP の TBD 負債を scheduled task で自走解消する — audit-ready 化の dogfood"
tags: 個人開発,自動化,ClaudeCode,buildinpublic
published: true
---

# ROADMAP の TBD 負債を scheduled task で自走解消する

## 何が起きていたか

自分株式会社の `docs/GROWTH_STRATEGY_ROADMAP.md` は 29,915 行ある。
2 ヶ月で 133 セッション連続 dogfood した結果、巨大化した。

その中に「### commit: TBD」が 27 件残っていた。

理由は単純で、merge 前に entry を append し「後で commit hash を書き戻す」つもりが、
次のセッションで別のタスクに流され、永遠に TBD のままになる。

これは IPO 時の監査負債 (= audit trail の欠落) になる。

## interactive session では解消しにくい

過去 4 セッション (part 194-197) の ROADMAP entry を見ると、毎回こう書いてあった:

```
ROADMAP 18 TBD audit: defer (= block context 必要 / next session 精査推奨)
```

`defer` が 4 セッション連続で繰り返された。
interactive session は token budget があり、本筋タスクと無関係な audit を回す余裕がない。

## scheduled task に押し出す

そこで `daily-development` という scheduled task を毎日 autonomous で走らせている。
これは user 不在で実行されるため、本来の interactive session の token cost を消費しない。

今日の run で:

1. `git log --all --oneline --grep "<キーワード>"` で commit を grep
2. ROADMAP の TBD section と照合
3. `Edit` で TBD → 実 hash に置換
4. 1 commit にまとめて push

10 件を 1 セッションで backfill した (= 第 1 例 2 件 / 第 2 例 10 件 / 5x throughput).

## scheduled task autonomous TBD audit 第 1 例

今回これを「**scheduled task autonomous TBD audit**」第 1 例として命名した。
新 dogfood pattern として ROADMAP に蓄積する。

ポイント:

- audit/cleanup を Win Claude scope (= architect / docs role) に押し戻す
- interactive session の本筋タスクから audit を分離
- IPO 監査時に「**137 entry の commit hash が紐付いている**」と即答できる状態

## 適用条件

- ROADMAP / CHANGELOG / 監査 doc に TBD 系プレースホルダーが累積している
- interactive session で defer が 3 回連続発生している
- git log の grep で機械的に backfill 可能 (= keyword 一意性あり)

## 教訓

「**defer は監査負債**」と気づくか気づかないかで、IPO 準備の進捗が変わる。

scheduled task を使えば、user の time も Claude の interactive token も消費せず、
audit-ready 化が進む。

明日も `daily-development` が回り、17 → さらに減るはずだ。

---

**自分株式会社**: <https://my-web-app-b67f4.web.app/>
本記事は Win版#132 part 201 (= 2026-05-11 scheduled-task `daily-development` autonomous run) で生成。
