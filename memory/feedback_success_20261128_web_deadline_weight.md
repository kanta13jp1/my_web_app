---
name: grill-me 8 問で UX 判断を先に固め、純粋関数 + CI ゲートの事前ローカル検証で 1 往復に収めた
description: /deadline-weight「締め切りの重さ」を Web クラウドセッションで設計→実装→マージした際に効いた進め方。設計判断の先出し、(items, settings, now) 純粋関数、PR 本文ゲートのローカル事前検証、81 文字 1 行の format 失敗の特定方法。
type: feedback
---

## 1. 「作るもの」より先に「記事のどの核を取るか」を決める

元ネタ (note 記事) が複数の主張を含むとき、最初の質問は「どの章を機能にするか」にした。
候補を 4 つ (時間盲目性 / DMN 対策 / 朝の 5 分 / 統合ダッシュボード) 出し、**既存機能との重複を
事前調査した事実つきで**提示したところ、一発で「時間盲目性」に決まった。

事前調査で分かっていた事実を質問文に織り込んだのが効いた:

- `/procrastination-reset` が既にあり、記事の第 4〜5 章と重なる (SharedPreferences 保存)
- `/thought-anchor` `/focus-timer` `/thought-interrupt-diagnosis` が DMN 対策と重なる
- ADHD を主題にした機能はリポジトリにまだ無い

**Why:** 「何を作るか」を決めずに「どう作るか」を聞くと、重複機能を作ってから気づく。
**How to apply:** 元ネタのある機能依頼は、`/grill-me` の 1 問目を必ず「元ネタのどの核か」にし、
既存機能との重複調査を済ませてから選択肢を出す。

## 2. データ源の調査で「既存テーブルが使えない」と分かったことに価値があった

前回 (OMOCHA WORKS) は `wbs_tasks.instance` が実データとして使えたので「まず既存を探す」が正解だった。
今回も同じ手順で探した結果:

- `todos` テーブルは存在するが **アプリから使われていない死にテーブル**
- `life_goals.target_date` は長期目標で、日次の「動き出し」には遠い
- `wbs_tasks.end_date` は AI fleet の作業期日で、人間の個人的な締め切りではない

→ 専用テーブルを作る、が正しい結論になった。

**Why:** 「既存を探す」は、見つけるためだけでなく **無いと確信するため** にもやる価値がある。
調査しないまま新テーブルを作ると「既存があるのでは」が最後まで残る。
**How to apply:** データ源の質問には、既存候補を 1 つずつ「なぜ使えないか」まで調べてから出す。

## 3. CI ゲートは PR を作る前にローカルで通す

`scripts/check_minimal_e2e_gate.py` と `scripts/check_high_risk_ultrareview_gate.py` は
`--body-file` と `--changed-files` を取るので、**PR 本文を書いた直後にローカルで検証できる**。
今回はこれで両方 PASS を確認してから PR を作り、ゲート起因の往復が 0 回だった。

```bash
git diff --name-only origin/main...HEAD > changed.txt
python3 scripts/check_minimal_e2e_gate.py --body-file pr_body.md --changed-files changed.txt
python3 scripts/check_high_risk_ultrareview_gate.py --body-file pr_body.md --changed-files changed.txt
```

`--emit-snippet` / `--emit-exception "<理由>"` で、通る形式の雛形をスクリプト自身に出させられる。
手で書式を当てにいかない。

**Why:** 前回はこのゲート形式で 3 往復した。ローカル検証は数秒、CI 1 周は約 10 分。
**How to apply:** PR を作る前に、必ず 3 ゲート (minimal E2E / high-risk / design a11y) を
ローカルで回す。design a11y は advisory だが、何が要求されるかを先に見ておく。

## 4. `dart format` 失敗は「80 文字超の *コード* 行」を文字数で探す

CI が `Changed lib/models/deadline_weight_models.dart` とだけ言って落ちたとき、
`awk 'length>80'` では日本語コメントが大量に引っかかって使い物にならなかった
(awk はバイト数で数える)。Python で **文字数** を数えたら、該当は 1 行だけだった。

```bash
python3 -I -c "
for p in ['lib/models/x.dart']:
    for i,l in enumerate(open(p,encoding='utf-8').read().split('\n'),1):
        if len(l)>80: print(f'{p}:{i} ({len(l)}): {l[:70]}')
"
```

実際の原因は `copyWith({required int weekday, required int minutes}) {` の 81 文字。

**Why:** Flutter SDK の無い環境では `dart format` を実行できず、CI の 1 往復が唯一の検証手段。
当てずっぽうで直すと 10 分 × 回数のコストになる。
**How to apply:** format 失敗は「文字数 > 80 かつコメント行でない行」をまず全部出す。
日本語コメントはバイト数では必ず引っかかるので、バイト数で数えない。

## 5. main の churn が激しいリポジトリでは auto-merge を使う

`AI Review Gate` は「trusted review を実行した base」と「PR の現在の base」の一致を要求する。
main が 10 分おきに動くこのリポジトリでは、`update-branch` → CI → その間に main が進む → 再び
`behind` + gate 失敗、という追いかけっこになった。

CCR 経由で auto-merge を有効にすると、この競合を GitHub 側が解決してくれる:

```bash
gh api -X PUT repos/<owner>/<repo>/pulls/<n>/ccr/auto_merge -f merge_method=squash
```

(GraphQL の `enablePullRequestAutoMerge` は Claude Code セッションから使えない。CCR ルートを使う。)

**Why:** 手で `update-branch` を繰り返すと、main の更新頻度次第で永久に追いつかない。
**How to apply:** CI が重く main が活発なリポジトリでは、グリーンを確認したら auto-merge に委ねる。
