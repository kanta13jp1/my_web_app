# Notion / Evernote 超え逆算プラン

作成日: 2026-03-23

## 1. ベンチマーク前提

2026年3月23日時点で、このサイトの登録者数は 2 人です。

競合ベンチマークは次の公開情報を基準に置きます。

- Notion: `Over 100M users worldwide` を公式 product page が掲示
  - https://www.notion.com/product
- Notion: 2024-09-03 公開の公式ブログで `100M users` 到達を明示
  - https://www.notion.com/ja/blog/100-million-of-you
- Evernote: 2022-11-16 公開の公式ブログで `Serving more than 250 million customers` と明記
  - https://evernote.com/blog/bending-spoons-to-acquire-evernote

このため、`Evernote 250M+` を上回る `250,000,001 登録者` を最低の長期目標に置きます。

## 2. いまの結論

現状の 2 人から 250M+ を狙うには、単なるノートアプリでは届きません。`個人メモ` から `共有・実行・AI・知識資産・公開流通` を一体化したプロダクトへ進化させ、`獲得 -> 登録 -> 継続 -> 紹介 -> 再訪` を日次で回す必要があります。

今回の実装で入れた土台は次の 4 つです。

- ライブ成長メーター
  - 登録者数、閲覧者数、LP 閲覧数、今日の登録数をサイト内で更新表示
- 紹介プログラム
  - referral code と招待リンクをユーザーごとに発行
- Growth Mission 画面
  - 成長指標、紹介状況、施策状況を 1 画面に集約
- LP の成長可視化
  - public LP 上でも登録者数と閲覧者数を見せ、社会的証明に使う

## 3. 北極星指標

最終的な北極星指標は `MAU` ではなく `登録者総数 + 共有起点登録者 + 週次継続率` の 3 本柱に置きます。

毎日見る数値:

- 総登録者数
- 今日の登録数
- 現在の閲覧者数
- 今日の LP 閲覧数
- 今日の登録 CVR
- 今日の紹介数
- 紹介成立数
- 7 日継続率
- 30 日継続率

## 4. 短期計画 0-90日

目標:

- 2 人 -> 1,000 人
- LP から登録までの CVR を毎週改善
- 紹介経由登録を全新規登録の 20% 以上へ

必須開発:

1. LP の公開価値を増やす
   - 共有された公開メモ、公開テンプレート、公開日報を検索流入で拾える形にする
   - `登録しなくても価値が伝わる` 状態を先に作る
2. 紹介を主導線にする
   - 招待リンクごとに登録率を比較
   - 紹介成立時の報酬、招待達成バッジ、月間紹介ランキング
3. 登録直後の定着を改善する
   - 初回 5 分で `1メモ作成 -> 1共有 -> 1再訪理由` まで完了させる
4. 成長実験の運用を固定化する
   - LP 見出し、CTA、Magic Link 導線、共有文面を A/B テストできるようにする

短期の主要機能テーマ:

- Public notes / public templates
- 招待ランキング
- LP A/B test フラグ
- onboarding checklist
- 共有実績バッジ

## 5. 中期計画 3-12か月

目標:

- 1,000 人 -> 100,000 人
- `個人メモアプリ` ではなく `個人 + 共同作業 + AI 実行 OS` へ広げる

必須開発:

1. Notion / Evernote からの移行導線
   - Evernote import
   - Notion import
   - テンプレート互換とデータ移行ウィザード
2. コラボレーション強化
   - 共有ノート
   - コメント
   - 共同編集
   - タスク割当
3. 公開流通面の拡大
   - 公開ページ
   - テンプレート marketplace
   - 検索流入向けの静的ページ生成
4. AI の差別化
   - MAGI を全主要画面へ標準搭載
   - ノート整理だけでなく、日課・行動改善・資産管理・会議支援へ統合

中期の主要機能テーマ:

- workspace / teamspace
- shared notebook / shared database
- import / export parity
- template distribution
- public publishing / SEO landing pages

## 6. 長期計画 1-3年

目標:

- 100,000 人 -> 10M+ -> 250M+
- Notion / Evernote と同じ土俵ではなく、`AI 主導の実行型 knowledge system` として別カテゴリまで広げる

必須開発:

1. プロダクトの再定義
   - note app ではなく `personal operating system`
2. プラットフォーム化
   - API
   - plugin / extension
   - community template economy
3. 企業導入
   - admin
   - audit log
   - SSO
   - team billing
4. 国際展開
   - 日本語だけでなく英語圏、アジア圏へ最初から広げる

長期の主要機能テーマ:

- enterprise admin
- marketplace revenue share
- AI agents for teams
- multilingual growth engine
- ecosystem / partner motion

## 7. Notion / Evernote を上回るための機能優先順位

優先順位は次の順です。

1. 獲得導線
   - SEO / public pages / share / referral
2. 移行障壁の除去
   - Notion / Evernote import
3. 継続理由
   - AI 実行支援、daily workflow、共有
4. 紹介ループ
   - 招待で人が増える構造
5. 企業導入
   - 個人利用から組織利用へ拡張

理由:

- 2 人から 250M+ を狙うには、`既存ユーザーの紹介` と `検索流入` が同時に伸びる設計が必要
- Notion / Evernote の既存ユーザーを奪うには、`移行しやすさ` と `移行後の価値差` の両方が要る
- 継続率が弱い状態で広告や露出だけ増やしても、母数は増えない

## 8. 毎週の運用ルール

毎週月曜に見るもの:

- LP 閲覧数の前週比
- 登録数の前週比
- 登録 CVR
- 紹介リンク経由登録率
- 7 日継続率
- 30 日継続率
- 公開ページ流入数

毎週やること:

1. LP の見出しを 1 つ改善
2. 招待文を 1 つ改善
3. onboarding の離脱ポイントを 1 つ削る
4. 公開導線を 1 つ追加
5. 既存ユーザーの共有理由を 1 つ増やす

## 9. 直近 30 日の実装順

Week 1:

- ライブ成長メーターを LP / Growth Mission に常設
- 紹介リンクのコピー率と登録率を計測

Week 2:

- 公開メモの一覧 / 詳細ページを追加
- 検索流入を取れる URL を整える

Week 3:

- Notion import と Evernote import の調査と MVP 実装着手
- onboarding を `1メモ -> 1共有 -> 1再訪理由` に絞る

Week 4:

- 招待報酬
- 紹介ランキング
- LP A/B テスト

## 10. 最後に

Notion 100M+ と Evernote 250M+ を上回るには、`メモを取れる` だけでは絶対に届きません。必要なのは、`見つかる`, `登録したくなる`, `使い続ける`, `人を連れてきたくなる`, `移行しやすい` を全部つなげることです。

この計画は、その前提で逆算した開発ロードマップです。
