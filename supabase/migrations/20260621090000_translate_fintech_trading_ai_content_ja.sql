-- AI大学 FinTech/Trading AI 学科の掲載コンテンツを日本語化 (2026-06-21)
--
-- 20260512090000_seed_fintech_trading_ai_university.sql で英語 seed された 8 プロバイダーの
-- title / content と、学科 (university_departments) の name_ja / description を日本語へ更新する。
-- 既存行は本番適用済み (INSERT ... ON CONFLICT DO UPDATE) のため、本 migration で UPDATE する
-- (適用済み migration の編集は不可)。
--
-- ユーザー要望「AI大学に残る英語を日本語化したい」(UI 全部 + 掲載記事本文) の後段対応。
-- UI 文字列は別 PR (#3545) で対応済み。本 migration は DB 掲載記事本文を対象とする。
--
-- nocheck: time-relative
--   ai_university_content / university_departments の BEFORE UPDATE トリガは
--   updated_at = now() を設定するだけの無害なトリガで、CHECK 制約も RAISE も持たず
--   リプレイで失敗しない (PS#5 S78 の date-CHECK 失敗とは別系統)。本 migration は
--   表示文字列の UPDATE のみで時刻相対の制約に触れないため、時刻相対ガードを除外する。

-- ==============================================
-- 学科メタ
-- ==============================================
UPDATE university_departments
SET name_ja = 'FinTech ディスラプション / トレーディング × AI',
    description = '機関投資家向けの市場インテリジェンスツールと低コスト AI ワークフローを比較し、'
      || '金融シグナルを学習・WBS アクション・個人 KPI レビューへ変える学科。',
    updated_at = now()
WHERE department_code = 'fintech_trading_ai';

-- ==============================================
-- 掲載記事 8 本 (title + content)
-- ==============================================

UPDATE ai_university_content SET
  title = 'Bloomberg Terminal — 機関投資家の市場インテリジェンスの基準',
  content = $$## Bloomberg Terminal

Bloomberg Terminal は、リアルタイムの市場データ・ニュース・価格・プロ向けトレーディングワークフローにおける機関投資家の標準です。

学習ポイント:
- 金融インテリジェンスにおいて、速度・情報源の質・監査可能性がなぜ重要か。
- 高コストな端末ワークフローを、ソース取得・重複排除・確信度スコアリング・アナリストレビューへ分解する方法。
- 個人向け AI ワークフローが有料データ端末の模倣に踏み込まず、公開シグナルを規律ある行動へ変えるべき境界はどこか。

自分株式会社での活用:
Bloomberg は機能の写しではなく参照アーキテクチャとして使う。ローカルのワークフローでは、ソース URL・確信度・次のアクション・人による最終判断を必ず保持する。$$,
  updated_at = now()
WHERE provider = 'bloomberg_terminal' AND category = 'fintech_trading_ai';

UPDATE ai_university_content SET
  title = 'Refinitiv Eikon / Workspace — 市場データ・ワークフロー比較',
  content = $$## Refinitiv Eikon / Workspace

Refinitiv Eikon は現在 LSEG Workspace の一部で、市場データ・ニュース・チャート・リサーチのワークフローを機関投資家向けに統合します。

学習ポイント:
- ニュース・市場データ・企業ファンダメンタルズをまたいだエンティティ解決。
- 生データからリサーチノート・意思決定へと進むワークフロー設計。
- 機関投資家ワークフローの一部を AI エージェントで置き換える際のコストとガバナンスのトレードオフ。

自分株式会社での活用:
このパターンで市場イベントを個人の資産台帳・KPI ノート・レビュータスクへ結びつけつつ、有料データ依存は本体アプリから排除する。$$,
  updated_at = now()
WHERE provider = 'refinitiv_eikon' AND category = 'fintech_trading_ai';

UPDATE ai_university_content SET
  title = 'FactSet — ポートフォリオ分析と機関投資家リサーチのパターン',
  content = $$## FactSet

FactSet は、プロ投資家向けのポートフォリオ分析・業績予想・企業データ・リサーチ生産性を体現します。

学習ポイント:
- ポートフォリオ分析が企業ファンダメンタルズと投資レビューをどう結びつけるか。
- AI が生成する金融インサイトに、なぜ情報源リンク・前提・確信度ラベルが必要か。
- 結果が判明した後に振り返れる意思決定ログをどう残すか。

自分株式会社での活用:
金融インサイトを、単発のトレード推奨ではなく、監査可能なノート・個人 KPI の差分・WBS のフォローアップへ変える。$$,
  updated_at = now()
WHERE provider = 'factset' AND category = 'fintech_trading_ai';

UPDATE ai_university_content SET
  title = 'Sentieo — AI 支援による金融ドキュメントリサーチ',
  content = $$## Sentieo

Sentieo は金融ドキュメントの検索・リサーチワークフローで、現在は AlphaSense 傘下です。

学習ポイント:
- 開示資料・決算説明・市場ニュースを横断する検索ファーストのリサーチ。
- 引用と一次証拠を近くに保つ要約。
- ドキュメント検索・仮説形成・人による投資判断を分離する。

自分株式会社での活用:
NotebookLM・Claude・Supabase のログを使い、リサーチの主張を一次資料からタスクの意思決定までトレース可能に保つ。$$,
  updated_at = now()
WHERE provider = 'sentieo' AND category = 'fintech_trading_ai';

UPDATE ai_university_content SET
  title = 'Koyfin — 低価格の市場ダッシュボード挑戦者',
  content = $$## Koyfin

Koyfin は低コストの市場ダッシュボード挑戦者で、チャート・ウォッチリスト・マクロデータ・スクリーニングをより手軽にします。

学習ポイント:
- 端末の価値のうち、絞り込んだダッシュボードで提供できる部分はどこか。
- ウォッチリスト・チャート・マクロ指標が日次レビューのループをどう支えるか。
- 個人ユーザーが無関係な市場シグナルに溺れないようにする方法。

自分株式会社での活用:
市場ダッシュボードを、個人の目標・資産・未完了の WBS タスクに紐づくシグナルだけを浮かび上がらせる日次ダイジェストへ変換する。$$,
  updated_at = now()
WHERE provider = 'koyfin' AND category = 'fintech_trading_ai';

UPDATE ai_university_content SET
  title = 'Atom Finance — 個人投資家向けリサーチワークフロー',
  content = $$## Atom Finance

Atom Finance は個人投資のリサーチとポートフォリオインサイトに注力します。

学習ポイント:
- プロ仕様に見えるリサーチを、個人投資家向けにどう翻訳するか。
- ポートフォリオ通知が根拠のないトレード助言にならないようにする方法。
- 不完全・遅延・単一ソースの市場主張に対するガードレールの設計。

自分株式会社での活用:
分かりやすい金融解説にこのパターンを使いつつ、推奨は情報源リンクとリスク注記付きの「レビュー喚起」として提示する。$$,
  updated_at = now()
WHERE provider = 'atom_finance' AND category = 'fintech_trading_ai';

UPDATE ai_university_content SET
  title = 'Claude Pro 金融ワークフロー — 市場リサーチのための低コスト外部脳',
  content = $$## Claude Pro 金融ワークフロー

Claude Pro は、厳格なソース規律と併用すれば、日次の市場リサーチのための低コストな外部脳になります。

学習ポイント:
- 公開情報に対するパターン検出・矛盾チェック・フェイクニュース判定。
- SNS のみ・単一ソース・証拠なき価格変動といった主張への警告。
- 長いリサーチを、人がレビューしやすい簡潔なブリーフへ圧縮する。

自分株式会社での活用:
Claude を意思決定者ではなくリサーチ助手として扱う。ソース URL・タイムスタンプ・確信度・次のアクションを構造化ログに保持する。$$,
  updated_at = now()
WHERE provider = 'claude_pro_finance' AND category = 'fintech_trading_ai';

UPDATE ai_university_content SET
  title = 'Cursor + 自分株式会社 — シグナルからアクションまで統合した金融 OS',
  content = $$## Cursor + 自分株式会社 金融 OS

Cursor と自分株式会社の組み合わせは、金融インテリジェンスのワークフローを、コード・データ・UI・レビューの自動化へと変えます。

学習ポイント:
- ソース取得・重複排除・確信度スコアリング・下書き生成を、小さな PR 単位の変更へ分割する。
- 1 つのシグナルを、ブログ下書き・WBS タスク・ポートフォリオノート・日次ブリーフに使い回す。
- 不要な有料データや外部 API への依存を避けてコスト規律を保つ。

自分株式会社での活用:
市場ニュースを読むだけの状態から、取得・検証・分類・割り当て・レビューという日次のアクション OS の運用へ移行する。$$,
  updated_at = now()
WHERE provider = 'cursor_jibun_finance' AND category = 'fintech_trading_ai';

-- ==============================================
-- development_achievements
-- ==============================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 FinTech/Trading AI 掲載コンテンツの日本語化',
  'AI大学プロバイダーページに残っていた英語の掲載記事本文を日本語化。FinTech/Trading AI 学科の 8 プロバイダー (Bloomberg Terminal / Refinitiv Eikon / FactSet / Sentieo / Koyfin / Atom Finance / Claude Pro 金融ワークフロー / Cursor + 自分株式会社) の title・content と学科 name_ja・description を UPDATE。UI 文字列は #3545 で対応済み。',
  '2026-06-21'
)
ON CONFLICT DO NOTHING;
