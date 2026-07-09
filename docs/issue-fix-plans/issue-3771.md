# Issue Fix Plan #3771

- Issue: [[追加要望] 🧪 Claude Codeインフルエンサー実験 統括: 10仮説検証 + 運用プレイブック](https://github.com/kanta13jp1/my_web_app/issues/3771)
- Labels: priority:high,追加要望,growth,launch
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/28994193528

## Goal

[追加要望] 🧪 Claude Codeインフルエンサー実験 統括: 10仮説検証 + 運用プレイブック

## Current Context

```text
## 🧪 実験：「Claude Code だけでインフルエンサー → サイト流入・登録増」10仮説検証

6エージェントで10仮説を検証（repo file:line + 実データ + プラットフォーム現実）。**正直な結論を優先**。

### 結論（bottom line）
**Claude Code "だけ" ではインフルエンサーにはなれない**。実データがそれを証明：これだけの自動投稿機構が既にあるのに、アカウントは約4ユーザー・新規投稿は2〜11 Views。Claude Codeが端から端まで自動化するのは「トレンド取得→LLM下書き→画像/動画→URLリプライ投稿→3h毎メトリクス→勝ちバリアント反映」という**コンテンツ選択のループ**だが、**制約はコンテンツではない**。リーチを動かす5要素（他者スレッドへの本物の返信・フォロワー関係・アルゴのエンゲージシグナル・信頼性・時間）は自己投稿 botが偽装できない。自動アウトバウンド返信はToS/凍結リスク最大かつ最低転換なので**作らない**。

🔴 **最大レバーは"良い投稿を増やす"ことではない**：**プロフィール導線のアトリビューション修正**。固定ポストとX bioのWebsiteが**素のURL（UTM無し）**なので、profile訪問→サイトクリックが**全て不可視**＝「Xが登録を生むか」を判定すらできない。正しいKPI＝**vanity impressionsでなく utm_content 経由の実signup**。正直な枠組み：**「Claude Code ＋ 週次で本物の返信をする人間 ＝ 有意に速い成長」**。

### 10仮説 判定表
| # | 判定 | 一行の含意 |
|---|---|---|
| H1 自動生成 | 🟡PARTIAL | 生成は本物だがfallback文/動画スクリプトが固定byte一致→重複垢シグナル。回転プール+直近N件dedup要 |
| H2 トレンドジャック | 🔴REFUTED | 配線は本物だがトレンド名の言及≠トレンド面への露出。冷垢に発見性は生まれない。コピー鮮度ツールへ再定義 |
| H3 動画>テキスト | ⚪UNKNOWN | media別リーチデータ皆無。11view動画はURL位置と交絡。#3765/#3764着地後にmatched A/B要 |
| H4 URLリプライ | 🟢CONFIRMED | #3766で既定化済。40xはn=1逸話→cronで実測比に置換 |
| H5 スレッド/問いかけ | 🟡PARTIAL | 配管はあるがdailyBriefing以外スレッド返さず、スレcronも0件。検証不能状態 |
| H6 アウトバウンド返信 | 🔴REFUTED | 自動化は最大リスク。人間主導、Claudeは下書きのみ |
| H7 build-in-public物語 | 🟡PARTIAL | ニッチ飽和。実績ある高impressionはニュース/AI briefing。BiPは信頼層に |
| H8 プロフ導線 | 🟡PARTIAL | **最高レバーだが計測不能**（bio/pin=素URL）。UTM付与が最優先 |
| H9 A/Bループ複利 | 🟡PARTIAL | 機構は閉じるが最小サンプルゲート無し→2 vs 9 viewsでnoiseを"勝者"確定。閾値+探索要 |
| H10 メタ「単独で？」 | 🔴REFUTED | 天井=4ユーザー/2-11view。KPIをX経由signupへ。人間・API tier・数ヶ月が必須 |

### プレイブック（[AUTO]=Claude / [HUMAN]=運営者）
- **SETUP**: [HUMAN] bio/固定ポストに `?utm_source=x&utm_medium=profile&utm_campaign=first_user_growth` 付きURLを貼る（Xプロフィールはrepo内にAPI無し=人手）／[AUTO] Claudeがリンク生成+profile bucketをコード対応
- **SETUP**: [HUMAN] X API tier確認（投稿頻度+non_public impressionsはpaid Basic+要）／[AUTO] trends発火・public_metrics fallbackのprodログ追加
- **毎日07:00**: [AUTO] dailyBriefingスレッド（replyTexts+URL最終リプライ）cron（※未存在=下記タスク）。フックはニュース/AI briefing、BiPではない
- **毎日投稿前**: [AUTO] 直近N件と近すぎる下書きをdedup reject
- **毎日3h毎**: [AUTO] メトリクス収集（稼働中）
- **毎日（botが引けない唯一のレバー）**: [HUMAN] ニッチのスレッド5-10件に本物の返信。[AUTO]は候補返信2-3案の下書きのみ、**自動投稿は絶対に作らない**
- **毎週月**: [AUTO] min-impressionsゲート+ε探索(20%)付きでbestVariant算出／matched A/Bペア生成
- **毎週金**: [AUTO] **utm_content経由の実signup**レポート（impressionsでない）／[HUMAN] tier継続判断
- **毎月**: [HUMAN] signup+フォロワー増で数ヶ月horizonで判定／[AUTO] 節約できた工数を"Claudeの貢献"として報告

### 子タスク（P0=最大signupレバー）
- P0 プロフィール導線の計測化（UTM+profile bucket）← #下記
- P0 dailyBriefingスレッド日次cron ← #下記
- P1 投稿前dedupガード / P1 performance_contextにmin-sample+探索 / P1 questionPostもスレッド化 / P1 Hedra poll budget拡大or非同期
- P2 URL-in-reply実測A/B / P2 週次signup funnelレポート / P2 人手返信の候補ドラフトhelper(READ-only) / P2 x.trends tier検証ログ


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
