# 成長戦略ロードマップ - 自分株式会社

作成日: 2025-11-10
最終更新: 2026-03-24
現時点の登録者数: 2人
最重要目的: Notion・EverNote・MoneyForward・X を上回る規模の知的生産・資産管理・SNS 統合プラットフォームを作る
運用原則: flutter analyze を常に 0 に保ち、複雑な処理は可能な限り Supabase Edge Function へ移す

---

## 1. ビジョン

自分株式会社 を、AI が伴走する知的生産プラットフォームに進化させる。
単なるメモ保存ではなく、整理、共有、思考補助、行動変換、チーム運用までを支える。

勝ち筋は次の 4 本柱で作る。

1. 競合から移行しやすいこと (Notion、Evernote、MoneyForward、X からのユーザーを取り込む)
2. AI が自然に価値を生むこと
3. 共有と紹介が新規流入に変わること
4. 個人利用から法人導入まで伸びること

---

## 2. 競合到達ライン

ロードマップ上では次を最低到達ラインとして扱う。

- Notion: 100,000,000+ users 規模
- Evernote: 250,000,000+ customer 規模
- MoneyForward: ~15,000,000 users 規模
- X (Twitter/X): ~600,000,000 monthly active users 規模
- Animaworks: ~500,000 users 規模 (国内パーソナル生産性アプリ)
- Claude Code (Anthropic): ~500,000 users 規模 (AI コーディングアシスタント)

2026-03-24 に再確認した公開ベンチマークの前提は次の通り。

- Notion product page: `Over 100M users worldwide`
- Evernote official announcement dated 2022-11-16: `Serving more than 250 million customers`
- MoneyForward: ~1,500 万ユーザー
- X (Twitter/X): ~6 億 monthly active users
- Animaworks: 国内パーソナル生産性・習慣管理アプリ (~50 万ユーザー推定)

自分株式会社 はこの 5 サービスを上回るために、移行、AI、共有、紹介、法人展開を同時に強化する。

---

## 3. 現在地

### 現状

- 登録者数は 2 人で、まだ PMF 前
- Flutter Web + Supabase で高速改善できる
- Import preview と import commit は Edge Function first 化済み
- Public memo の share と copy の計測は backend 化済み
- Growth command center を実装済み
- flutter analyze は 0 を維持
- flutter test --coverage は一部 widget test の安定化が残っている

### 直近の実装済み項目

- growth-import-preview
- growth-import-commit
- growth-command-center
- growth-acquisition-signal
- growth-share-signal
- growth-referral
- growth-acquisition-report
- growth-weekly-digest (2026-03-25 追加)
- import 画面の backend-first execution result 表示
- public memo の共有導線と成長シグナル記録
- route / import / public memo / referral の獲得シグナル記録
- /referral 導線と referral invite セクション
- import と public memo から sign-up へ流す CTA 計測
- referral code 発行、pending referral 適用、referral snapshot 集計の backend-first 化
- Growth Mission に assisted conversion proxy と import preview 集計を追加
- Growth Mission から note / Qiita / Zenn / Medium / dev.to / Hashnode / Substack 向けの配信ブリーフをコピー可能にした
- HomePage の operations calendar で日別の収入 / 支出を月単位で俯瞰できるようにした
- referral anti-abuse: rate limit (1日5件) + 1時間未満アカウントブロック + check_abuse アクション (2026-03-25 追加)
- import 成功後の onboarding CTA を personalized card に刷新 (2026-03-25 追加)
- ai_status_page_test の残件 "can set and show the default ai model" を解消 (2026-03-25 完了)
- ホーム画面最上部に GrowthRoadmapProgressCard を追加 (2026-03-25 追加)
  - 短期/中期/長期計画の目標期日・達成率・■□バーをリアルタイム表示
  - vs NOTION (1億ユーザー) / vs EverNote (2.5億ユーザー) 比較バー
  - user_profiles テーブルから登録者数をリアルタイム取得
- 技術ブログ発信戦略を GROWTH_STRATEGY_ROADMAP.md に追加 (Zenn / Qiita / はてなブログ / note / dev.to / Hashnode / Medium / Substack / GitHub Pages)
- ホーム画面に vs X 進捗バーを追加 (2026-03-24 追加)
- 競合機能比較カードに X タブを追加 (X: SNS・コンテンツ配信機能との比較) (2026-03-24 追加)
- ホーム画面に CompetitorFeatureComparisonCard を Notion/EverNote/MoneyForward/X の4タブで実装 (2026-03-24 追加)
- ユーザーマニュアルページを追加 (実装済み全機能の操作手順書) (2026-03-24 追加)
- vs MoneyForward 進捗バーを追加 (2026-03-24 追加)
- vs Animaworks 進捗バーを追加 (目標: ~50万ユーザー) (2026-03-24 追加)
- 競合機能比較カードに Animaworks タブを追加 (目標・習慣管理/振り返り/ライフデザイン機能との比較) (2026-03-24 追加)
- CompetitorFeatureComparisonCard を5タブ構成に拡張 (Notion/EverNote/MoneyForward/X/Animaworks) (2026-03-24 追加)
- vs Claude Code 進捗バーを追加 (目標: ~50万ユーザー) (2026-03-24 追加)
- 競合機能比較カードに Claude Code タブを追加 (AI コーディング支援機能との比較) (2026-03-24 追加)
- CompetitorFeatureComparisonCard を6タブ構成に拡張 (+ Claude Code) (2026-03-24 追加)
- DevelopmentAchievementsCard をホーム画面に追加 (2026-03-24 追加)
  - 13区間の期間セレクター (今日〜すべて) で開発実績を切り替え表示
  - 新規ユーザー / 成長シグナル / 紹介成立 / インポートプレビュー の4指標
  - growth-achievement-summary Edge Function でバックエンド集計

### 残課題

- wasm build blocker の解消
- weekly digest を admin analytics page / growth mission page から呼び出す UI
- referral reward ポイント付与の実際の運用確認
- B2B 営業資料の整備開始

---

## 4. 北極星指標

最重要 KPI は次の通り。

- 登録ユーザー数
- 週次アクティブユーザー数
- 4 週継続率
- import 実行数
- 公開メモ由来登録数
- referral 由来登録数
- チーム導入数
- 有料転換率

成長は次の式で見る。

新規登録 = SEO 流入 + 共有流入 + referral 流入 + import 流入 + 広告流入 + 営業流入

定着は次の式で見る。

定着 = オンボーディング完了率 × 初回価値到達率 × 継続利用率

---

## 5. 絶対に守る開発原則

### 品質

- flutter analyze は常に 0
- deno check supabase と deno lint supabase を壊さない
- 重要画面の変更には必ず test を追加または更新する
- 失敗ログを放置しない

### アーキテクチャ

- フロントエンドで複雑化したロジックは Edge Function へ移す
- import、共有計測、成長集計、brief 生成は backend-first
- Flutter 側は UI と入力体験に集中させる

### プロダクト

- 競合からの乗り換えを最優先で楽にする
- AI は飾りではなく価値到達を早めるために使う
- 共有できる価値を常に設計に入れる

---

## 6. 2026-03-24 時点の最優先事項

1. import から登録までの転換率をさらに上げる
2. 共有、公開メモ、referral の assisted conversion proxy を週次で可視化する
3. flutter test --coverage の残件を解消する
4. route 単位の流入 KPI を週次レポートへ載せる
5. referral の reward / anti-abuse / sales handoff を本運用に耐える形にする

---

## 7. 短期計画 0-90 日

### 開発

- route-level acquisition signal aggregation を weekly digest と assisted conversion 集計へ拡張する
- referral コードと紹介リンクを Edge Function first で運用する
- /referral 導線の CVR を改善する
- import 成功後 onboarding を最適化する
- 公開メモの SEO と OGP を強化する
- ai_status_page_test と memory_drill_page_test の残件を解消する
- flutter_secure_storage_web の wasm blocker を調査する
- ユーザーマニュアルを実装済み機能に合わせて随時更新する
- X (Twitter) との機能比較ページを SEO コンテンツとして活用する

### 企画

- Notion から移行、Evernote から移行の専用導線を定義する
- referral landing で約束する価値を `登録 -> import -> first memo` の 3 ステップに固定する
- AI の価値訴求を 要約、整理、次アクション生成 の 3 本に絞る
- 勝ちテンプレート群を定義する
- X (SNS) からの流入導線を設計する (公開メモの X シェアボタン → 自分株式会社 登録)

### 広告

- X、Meta、Google で少額テストを開始する
- import 訴求広告と AI 訴求広告の勝ち筋を比較する
- referral LP を使った friends-invite クリエイティブを検証する

### 宣伝

- 公開メモの weekly share 運用を始める
- ship log と改善ログを週次発信する
- Notion 比較、Evernote 比較の記事を継続公開する
- note と Substack で founder update を定期配信する
- `/referral` と import の改善ログを build in public で見せる

### 技術ブログ・コンテンツ発信

各媒体の特性に合わせて記事を最大化する。1 shipped feature → 1 article seed → 複数媒体への展開を習慣にする。

#### 国内技術メディア

- **Zenn**: Flutter / Supabase / Edge Function の実装詳細記事。コードスニペットを充実させる。
- **Qiita**: 「Notion → 自分株式会社 移行スクリプトを作った」「Evernote ENEX を Flutter で解析する」など実用系。
- **はてなブログ**: 週次 build-in-public 日記。登録者数の推移グラフ付きで毎週公開する。

#### 国内コンテンツ

- **note**: founder 視点の growth 戦略 essay。技術非エンジニア層にも読める温度で書く。

#### 海外技術メディア

- **dev.to**: English 記事。Flutter + Supabase の実装記事で検索流入を狙う。
- **Hashnode**: Personal dev blog として位置づけ、英語コンテンツを蓄積する。
- **Medium**: Growth hacking / product building の英語エッセイ。
- **Substack**: 英語版 founder newsletter として月次配信する。

#### OSS・ドキュメント

- **GitHub Pages**: Public changelog / release notes を公開する。import ツールの使い方ドキュメントも置く。

#### 発信テンプレート (1 feature → 多媒体展開)

1. **機能リリース直後**: はてなブログで日本語速報 + X/Twitter スレッド
2. **実装詳細**: Zenn に技術記事 (日本語) → dev.to に英語版
3. **ユーザー視点**: Qiita に「移行してみた」系記事 + note に使い方エッセイ
4. **週次 growth update**: はてなブログ週記 + Substack newsletter
5. **月次まとめ**: Medium essay (英語) + note まとめ記事

### 営業

- 小規模チーム向け導入提案を開始する
- 移行代行付き PoC を試す
- referral で流入した小規模チーム候補を founder sales へ handoff する

### マーケティング

- SEO 着地面を比較記事、公開メモ、テンプレートで拡大する
- referral 施策の導線と報酬設計を固める
- Growth dashboard を毎週レビューする
- Qiita、Zenn、Medium、dev.to、Hashnode に技術記事を横展開して指名検索以外の入口を増やす
- 1つの shipped feature から 日本語記事、英語記事、公開メモ、SNS 要約 を派生させる
- assisted conversion proxy を見ながら referral / import / public memo の勝ち筋を週次で更新する

### 人事

- growth engineer と content marketer の採用要件を定義する
- 外部パートナー候補を確保する
- Supabase Edge Function を触れる growth backend contractor の要件を追加する

### 経理

- 成長投資の月次予算上限を決める
- CAC、LTV、回収期間を試算する
- referral reward の会計処理方針を決める

### 調達

- 必要 SaaS を選定する
- 記事制作、動画制作、広告運用の外注候補を確保する
- 既存 stack で不足する attribution / CRM / support tool の優先順位を決める

### 事業計画

- Free、Pro、Team、Enterprise の収益モデルを定義する
- 0 -> 1 の勝ち筋を文章化する
- 資金調達の条件と bootstrapping 継続条件を明文化する
- 100 users、1,000 users、10,000 users の段階ごとに org / budget / infra 前提を分ける

---

## 7B. Notion 機能ギャップ分析 (2026-03-25 時点)

ホーム画面に `NotionFeatureComparisonCard` を実装し、32 機能を網羅的に整理した。

### 実装状況サマリー

| ステータス | 件数 | 主な機能 |
| --- | --- | --- |
| 実装済み | 9 | ノート編集、AI補助、タグ、インポート3種、公開ページ、Web |
| 部分実装 | 3 | コードブロック、検索、テンプレート、API連携 |
| 開発中 | 2 | モバイルアプリ、デスクトップアプリ |
| 未実装 | 12 | DB各ビュー、コラボ、コメント、バージョン履歴など |
| 独自機能 | 6 | マインドマップ、記憶ドリル、AIエージェント組織など |

Notion 機能カバー率 = **実装済み+部分実装+開発中 / Notion相当機能合計 ≈ 54%**

### 優先ギャップ補填ロードマップ

#### 短期 (0-90日) で補填すべきギャップ

- **全文検索の強化**: 埋め込み検索 (embedding) を Edge Function で安定化
- **テンプレートマーケット**: 既存ページを拡充してコミュニティ共有まで完成させる
- **バージョン履歴 (最低限)**: ノート保存履歴の閲覧機能

#### 中期 (3-12ヶ月) で補填すべきギャップ

- **テーブルビュー (Database)**: Notion の最大差別化機能。シンプルな実装から始める
- **カンバン/ボードビュー**: タスク管理としての利用を取り込む
- **Team workspace**: リアルタイム共同編集の基盤
- **コメント機能**: ページへのインラインコメント
- **モバイルアプリ**: Flutter iOS/Android ビルドのリリース

#### 長期 (1-3年) で補填すべきギャップ

- **リレーション/ロールアップ**: 本格 DB 機能
- **オフライン対応**: PWA + IndexedDB
- **カレンダー/ガントビュー**
- **Web クリッパー**: ブラウザ拡張

### 自分株式会社 独自優位点 (Notion にない機能)

以下は Notion が持たず 自分株式会社 が先行している機能。訴求に積極活用する。

1. **マインドマップ** — ノートをビジュアル構造化
2. **記憶ドリル** — スペーシング反復学習
3. **AI エージェント組織** — CEO/CFO/CMO 役員会議 AI
4. **経営コックピット** — KPI・資産・習慣を一元管理
5. **Growth ロードマップ進捗** — 開発状況をリアルタイムで自分で確認できる透明性
6. **Referral anti-abuse プログラム** — 安全な紹介制度

---

## 8. 中期計画 3-12 ヶ月

### 数値目標

- 登録ユーザー数: 1,000 から 100,000
- 週次アクティブユーザー数: 300 から 20,000
- 初月継続率: 35% 以上
- 月次売上: 100 万円から 1,000 万円

### 重点施策

- Team / workspace 機能の実装
- テーブルビュー (Database) の実装 — Notion 最大差別化機能を取り込む
- カンバン/ボードビューの実装
- テンプレートマーケットの拡充とコミュニティ共有
- AI による整理、検索、次アクション生成の強化
- referral の本運用
- B2B 営業資料の整備
- モバイルアプリ (iOS/Android) リリース
- 海外向け launch の準備

---

## 9. 長期計画 1-3 年

### 到達目標

- 登録ユーザー数: 1,000,000 から 100,000,000+
- チーム導入社数: 10,000+
- 多言語展開: 日本語と英語を軸に拡張
- 年商: 数十億円規模

### 長期の勝ち方

1. 個人の熱狂的利用を作る
2. 共有、公開、referral で自然流入を作る
3. チーム導入で利用人数を拡張する
4. AI の実用度で差別化する
5. テンプレートと知識資産のネットワーク効果を作る

---

## 10. Edge Function へ移す候補

優先度順に進める。

### 1. ホーム画面データ集約 (最優先)

- 内容: ホーム画面の表示に必要な運用スナップショット(`_loadOpsSnapshot`)とKPIサマリー(`_loadHomeKpiOverview`)の生成処理を、単一の `get-home-dashboard` Edge Function に統合する。
- 目的:
  - クライアント側の複数DBアクセスを単一化し、初期表示パフォーマンスを向上させる。
  - 複雑な状態判断・計算ロジックをバックエンドに集約し、フロントエンドを簡素化する。
  - Web/モバイルアプリ間で表示ロジックの一貫性を担保する。

### その他の移行候補 (優先度順)

- referral activation 集計
- onboarding brief 生成
- public memo recommendation
- growth weekly digest 生成
- LP、import、public memo、referral の assisted conversion 集計
- acquisition touchpoint ごとの cohort 分析

2026-03-24 実装済み:

- referral code 発行、pending referral 適用、snapshot 集計
- acquisition touchpoint 集計の Edge Function 化

---

## 11. 次の 2 週間でやること (2026-03-25 更新)

1. ~~ai_status_page_test の残件を解消する~~ ✓ 完了
2. ~~memory_drill_page_test の残件を解消する~~ ✓ 完了
3. ~~referral reward と anti-abuse ルールを追加する~~ ✓ 完了
4. ~~import success 後 onboarding をさらに改善する~~ ✓ 完了
5. ~~acquisition touchpoint ごとの weekly digest を追加する~~ ✓ 完了 (growth-weekly-digest Edge Function)
6. weekly digest を Growth Mission / Admin Analytics から UI で呼び出せるようにする
7. import → sign-up CVR を weekly digest で追い始め、数値を毎週このファイルへ反映する
8. wasm build blocker の原因を特定して解消する
9. 公開メモの SEO / OGP タグを強化して organic 流入を増やす
10. B2B 向け移行代行 LP の最初のドラフトを作る
11. 技術ブログ第 1 弾を Zenn に投稿する (「Flutter + Supabase で growth dashboard を作った」)
12. はてなブログで週次 progress bar 付き成長記録を開始する

---

## 12. 毎週更新する項目

- 登録ユーザー数
- WAU
- 継続率
- import 実行数
- 共有数
- referral 数
- SEO 流入
- import 起点 sign-up submit 数
- public memo 起点 sign-up submit 数
- referral 起点 sign-up submit 数
- note / Qiita / Zenn / Medium / dev.to / Hashnode / Substack ごとの流入と登録数
- 広告 CPA
- 営業面談数
- チーム導入数
- analyze と test の状態

---

## 12A. 2026-03-24 cross-functional execution board

### 開発 — 2026-03-24

- `growth-referral` と `growth-acquisition-report` を Edge Function として運用開始する
- `/referral` と landing の invite section の CVR を追う
- flutter analyze 0、deno check / deno lint を壊さない

### 企画 — 2026-03-24

- referral の価値訴求を `招待 -> import -> first memo` に固定する
- Notion 比較、Evernote 比較、referral LP の訴求を同じ言葉にそろえる

### 広告 — 2026-03-24

- referral / import / AI の 3 クリエイティブで少額テストを回す
- Sign-up submit 計測が安定した訴求だけに予算を寄せる

### 宣伝 — 2026-03-24

- note、Substack、SNS で `今週 ship した growth 機能` を定例化する
- 公開メモと build log を referral と import の流入導線に使う

### 営業 — 2026-03-24

- 小規模チーム向けに `Notion / Evernote からの移行代行` を最初の提案軸にする
- referral 経由で流入した法人候補を founder sales が即対応する

### マーケティング — 2026-03-24

- public memo、比較記事、template、referral LP を同じキーワード設計で増やす
- assisted conversion proxy をもとに週次でチャネル配分を更新する

### 人事 — 2026-03-24

- growth backend contractor と content marketer の JD を確定する
- 100 users / 1,000 users 到達時の採用トリガーを先に決める

### 経理 — 2026-03-24

- referral reward の上限予算と会計処理ルールを決める
- CAC 回収期間の目標レンジを広告前に固定する

### 調達 — 2026-03-24

- attribution、CRM、support tool の追加要件を整理する
- 既存 stack で代替できるものは新規契約しない

### 事業計画 — 2026-03-24

- 100、1,000、10,000 users の各段階で必要な org / infra / revenue model を分けて管理する
- Notion / Evernote を上回る目標は長期旗印として持ちつつ、短期は PMF と repeatable channel を先に取る

---

## 12B. 2026-03-25 cross-functional execution board

### 開発 — 2026-03-25

- `growth-weekly-digest` Edge Function を追加し、7 日間のチャネル別 CVR と前週比を返せるようにした
- `growth-referral` に rate limit (1 日 5 件)、1 時間未満アカウントブロック、`check_abuse` アクションを追加した
- import 成功後の onboarding CTA を personalized card に刷新した (Notion / Evernote / Markdown 別に訴求文を変える)
- `ai_status_page_test` の残件 1 件を解消した (ListView lazy rendering によるバッジ未検出)
- flutter analyze 0 を維持。deno check growth-weekly-digest / growth-referral を確認した

### 企画 — 2026-03-25

- import 成功後の CTA を「無料アカウントを作成してノートを保存」に統一した
- weekly digest を週次 KPI レビューの基盤として位置づける
- B2B 向け移行代行 LP のドラフト要件を次スプリントで定義する

### 広告 — 2026-03-25

- import CTA 改善後の sign-up submit 数を weekly digest で追い始める
- 今週の数値が出たら import / referral / landing クリエイティブの予算配分を更新する

### 宣伝 — 2026-03-25

- 今週 ship した機能 (weekly digest, anti-abuse, import CTA, growth progress card) を note / Zenn / dev.to に投稿する
- build in public として referral anti-abuse の設計思想を公開メモにする
- 技術ブログ発信テンプレートを確立: 1 feature → Zenn (実装) → Qiita (実用) → dev.to (英語) → note (エッセイ)
- はてなブログで登録者数 weekly progress bar を見せながら成長記録を開始する

### 営業 — 2026-03-25

- import 成功後 CTA の「ノートを保存」導線を法人向け移行代行の入口として活用する
- weekly digest で CVR が高いチャネルからのリードを founder sales に優先対応させる

### マーケティング — 2026-03-25

- weekly digest による週次チャネルレビューを今週から開始する
- import → sign-up の CVR baseline を今週中に計測して記録する

### 人事 — 2026-03-25

- weekly digest が安定したら growth analytics contractor の採用要件に「digest 設計理解」を追加する

### 経理 — 2026-03-25

- referral anti-abuse 導入後、referral reward の実際の発行件数と上限予算の整合を確認する

### 調達 — 2026-03-25

- weekly digest で attribution の精度が足りなくなった時点で attribution tool の導入を検討する

### 事業計画 — 2026-03-25

- import CTA 改善後の CVR 数値が出たら、import チャネルの CAC / LTV 試算に使う
- 週次 digest を investor update の数値源として確立する

---

## 16. ベンチマーク参照元

- 2026-03-24 verified: [Notion product page](https://www.notion.com/product)
- 2026-03-24 verified: [Evernote official announcement](https://evernote.com/blog/bending-spoons-to-acquire-evernote)

---

## 13. 失敗条件

次を放置すると Notion と Evernote を超える前に失速する。

- Linter エラーを常態化させる
- フロントエンドに複雑な業務ロジックを溜める
- 計測が曖昧なまま広告投資を始める
- import はあるが onboarding が弱く定着しない
- 個人向けと法人向けの価値訴求を混同する

---

## 14. 判断基準

優先順位は次で決める。

1. 登録者数を増やすか
2. 継続率を上げるか
3. 競合からの移行を楽にするか
4. Edge Function へ寄せられるか
5. flutter analyze 0 と test 安定性を維持できるか

---

## 15. 現時点の結論

今の 自分株式会社 は規模ではまだ競合に遠く及ばない。
ただし、移行、AI、共有、referral、チーム導入を一貫した成長ループとして設計できれば、Notion と Evernote を上回る余地はある。

そのために当面は次を最優先にする。

- backend-first growth architecture
- import 起点の獲得強化
- 共有と referral 起点の獲得強化
- test と analyze の品質固定
- cross-functional な成長運営
