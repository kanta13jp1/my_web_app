# 成長戦略ロードマップ - MyMemo

作成日: 2025-11-10
最終更新: 2026-03-23
現時点の登録者数: 2人
最重要目的: Notion と Evernote を上回る規模の知的生産プラットフォームを作る
運用原則: flutter analyze を常に 0 に保ち、複雑な処理は可能な限り Supabase Edge Function へ移す

---

## 1. ビジョン

MyMemo を、AI が伴走する知的生産プラットフォームに進化させる。
単なるメモ保存ではなく、整理、共有、思考補助、行動変換、チーム運用までを支える。

勝ち筋は次の 4 本柱で作る。

1. 競合から移行しやすいこと
2. AI が自然に価値を生むこと
3. 共有と紹介が新規流入に変わること
4. 個人利用から法人導入まで伸びること

---

## 2. 競合到達ライン

ロードマップ上では次を最低到達ラインとして扱う。

- Notion: 100,000,000+ users 規模
- Evernote: 250,000,000+ customer 規模

MyMemo はこの 2 サービスを上回るために、移行、AI、共有、紹介、法人展開を同時に強化する。

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
- import 画面の backend-first execution result 表示
- public memo の共有導線と成長シグナル記録
- route / import / public memo / referral の獲得シグナル記録
- import と public memo から sign-up へ流す CTA 計測
- Growth Mission から note / Qiita / Zenn / Medium / dev.to / Hashnode / Substack 向けの配信ブリーフをコピー可能にした
- HomePage の operations calendar で日別の収入 / 支出を月単位で俯瞰できるようにした

### 残課題

- referral の本実装
- widget test の残件整理
- wasm build blocker の解消
- assisted conversion の週次集計

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

## 6. 2026-03-23 時点の最優先事項

1. import から登録までの転換率をさらに上げる
2. 共有、公開メモ、referral の assisted conversion を可視化する
3. flutter test --coverage の残件を解消する
4. route 単位の流入 KPI を週次レポートへ載せる
5. referral の本運用を開始する

---

## 7. 短期計画 0-90 日

### 開発

- route-level acquisition signal aggregation を weekly digest と assisted conversion 集計へ拡張する
- referral コードと紹介リンクを実装する
- import 成功後 onboarding を最適化する
- 公開メモの SEO と OGP を強化する
- ai_status_page_test と memory_drill_page_test の残件を解消する
- flutter_secure_storage_web の wasm blocker を調査する

### 企画

- Notion から移行、Evernote から移行の専用導線を定義する
- AI の価値訴求を 要約、整理、次アクション生成 の 3 本に絞る
- 勝ちテンプレート群を定義する

### 広告

- X、Meta、Google で少額テストを開始する
- import 訴求広告と AI 訴求広告の勝ち筋を比較する

### 宣伝

- 公開メモの weekly share 運用を始める
- ship log と改善ログを週次発信する
- Notion 比較、Evernote 比較の記事を継続公開する
- note と Substack で founder update を定期配信する

### 営業

- 小規模チーム向け導入提案を開始する
- 移行代行付き PoC を試す

### マーケティング

- SEO 着地面を比較記事、公開メモ、テンプレートで拡大する
- referral 施策の導線と報酬設計を固める
- Growth dashboard を毎週レビューする
- Qiita、Zenn、Medium、dev.to、Hashnode に技術記事を横展開して指名検索以外の入口を増やす
- 1つの shipped feature から 日本語記事、英語記事、公開メモ、SNS 要約 を派生させる

### 人事

- growth engineer と content marketer の採用要件を定義する
- 外部パートナー候補を確保する

### 経理

- 成長投資の月次予算上限を決める
- CAC、LTV、回収期間を試算する

### 調達

- 必要 SaaS を選定する
- 記事制作、動画制作、広告運用の外注候補を確保する

### 事業計画

- Free、Pro、Team、Enterprise の収益モデルを定義する
- 0 -> 1 の勝ち筋を文章化する
- 資金調達の条件と bootstrapping 継続条件を明文化する

---

## 8. 中期計画 3-12 ヶ月

### 数値目標

- 登録ユーザー数: 1,000 から 100,000
- 週次アクティブユーザー数: 300 から 20,000
- 初月継続率: 35% 以上
- 月次売上: 100 万円から 1,000 万円

### 重点施策

- Team / workspace 機能の実装
- テンプレートマーケットの立ち上げ
- AI による整理、検索、次アクション生成の強化
- referral の本運用
- B2B 営業資料の整備
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

1. referral activation 集計
2. onboarding brief 生成
3. public memo recommendation
4. growth weekly digest 生成
5. LP、import、public memo、referral の assisted conversion 集計
6. acquisition touchpoint ごとの cohort 分析

---

## 11. 次の 2 週間でやること

1. ai_status_page_test の残件を解消する
2. memory_drill_page_test の残件を解消する
3. referral registration と activation の計測を追加する
4. import success 後 onboarding をさらに改善する
5. acquisition touchpoint ごとの assisted conversion レポートを追加する
6. 毎週このファイルへ実績値を反映する

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

## 16. ベンチマーク参照元

- Notion product page: https://www.notion.com/product
- Evernote official / company references used in planning: https://evernote.com/blog/bending-spoons-to-acquire-evernote

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

今の MyMemo は規模ではまだ競合に遠く及ばない。
ただし、移行、AI、共有、referral、チーム導入を一貫した成長ループとして設計できれば、Notion と Evernote を上回る余地はある。

そのために当面は次を最優先にする。

- backend-first growth architecture
- import 起点の獲得強化
- 共有と referral 起点の獲得強化
- test と analyze の品質固定
- cross-functional な成長運営
