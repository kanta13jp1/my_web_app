-- PS#4 S67: jp_strength/jp_weakness 補完 Batch 3 (13社)
-- 対象: ov≥5 で Batch 1/2 未カバー分 (slack・chatwork 等 original 21 + 新規高優先)

UPDATE competitors SET
  jp_strength = 'ビジネスコミュニケーション世界標準 / 日本の大手企業・スタートアップ主流 / Slack AI・ワークフロー自動化 / Salesforce との連携 / CRM 機能 (2026-04 日本提供開始)',
  jp_weakness = '月額課金必須で個人利用コスト高 / 財務・健康・習慣管理機能なし / ライフ OS としての統合なし'
WHERE id = 'slack';

UPDATE competitors SET
  jp_strength = '国内ビジネスチャット No.1 / 日本製で国内企業の信頼高い / 無料プランあり / 個人情報の日本国内保管 / SME・フリーランスに普及',
  jp_weakness = 'AI 機能が Slack/Teams に劣る / 個人ライフマネジメント・財務管理なし / 海外展開なし'
WHERE id = 'chatwork';

UPDATE competitors SET
  jp_strength = '世界最大の AI モデルハブ / 30万+ モデル・データセット公開 / OSS 開発者の事実上の標準基盤 / 日本語モデルも充実',
  jp_weakness = '開発者向けプラットフォーム = エンドユーザー向け UI なし / 個人ライフマネジメント機能なし'
WHERE id = 'huggingface';

UPDATE competitors SET
  jp_strength = 'LLM アプリ開発フレームワーク最大手 / 大規模 OSS コミュニティ / LangGraph・LangSmith で本番対応 / Sequoia 出資',
  jp_weakness = '開発者ツール = 一般ユーザー向け製品なし / 個人ライフ OS 機能なし / 日本語ドキュメント薄い'
WHERE id = 'langchain-inc';

UPDATE competitors SET
  jp_strength = '欧米 No.1 後払い (BNPL) / AI 不正検知 / Klarna AI アシスタント 8500 万ユーザー / 金融サービスへの AI 統合先進',
  jp_weakness = '日本市場参入済みだが普及率低い / 個人財務管理の総合 OS としての機能なし'
WHERE id = 'klarna-ai';

UPDATE competitors SET
  jp_strength = '会話 AI・コンタクトセンター特化 / Fortune 500 採用 / 30 言語対応 / エンタープライズ AI の実績豊富 / $150M+ 調達',
  jp_weakness = 'コンタクトセンター B2B 特化 / 個人ライフマネジメント機能なし / 日本市場の個人向けなし'
WHERE id = 'kore-ai';

UPDATE competitors SET
  jp_strength = '世界最大の広告プラットフォーム / 精度の高い検索意図ターゲティング / 小規模予算から利用可 / AI 入札最適化',
  jp_weakness = '広告特化 = 個人生産性・財務管理・ライフ OS 機能なし / データプライバシー懸念強い'
WHERE id = 'google-ads';

UPDATE competitors SET
  jp_strength = '世界最大 SNS 広告 / Instagram・WhatsApp 連携 / AI 広告クリエイティブ自動生成 / 圧倒的リーチ',
  jp_weakness = '広告・SNS 特化 / 個人ライフマネジメント・財務管理なし / データプライバシー問題多い'
WHERE id = 'meta-ads';

UPDATE competitors SET
  jp_strength = '日本国内通信インフラ No.1 / Softbank AI 活用 (Yahoo! Japan / Paypay 等) / 法人向け ICT サービス豊富 / AGI 投資 (SoftBank Vision Fund)',
  jp_weakness = '通信キャリア特化 / 個人 AI ライフ OS としての統合機能なし / ロックイン型ビジネス'
WHERE id = 'softbank-telecom';

UPDATE competitors SET
  jp_strength = '日本最大のブログ・ブックマーク / はてなブログ無料 / IT エンジニアの知的コミュニティ形成 / 20年超の蓄積コンテンツ',
  jp_weakness = 'AI 機能なし / 個人財務・健康・習慣管理なし / メモ・タスク管理特化でなく日記・発信向け'
WHERE id = 'hatena';

UPDATE competitors SET
  jp_strength = '世界最大 E ラーニング / 21 万+ コース / 日本語コース増加中 / 買い切り型で安価 / ビジネス・IT スキル充実',
  jp_weakness = '動画学習特化 / AI 学習支援機能まだ限定的 / 個人財務・習慣・タスク管理なし'
WHERE id = 'udemy';

UPDATE competitors SET
  jp_strength = '国内 No.1 不動産 IT SaaS / 仲介・管理業向け / 電子契約・内見予約・物件管理統合 / freee 連携',
  jp_weakness = '不動産業者向け B2B 特化 / 個人ライフマネジメント・AI 機能なし / 一般消費者向けでない'
WHERE id = 'itandi';

UPDATE competitors SET
  jp_strength = 'オンライン診療 No.1 (日本) / 24 時間受診可能 / 2800 医療機関連携 / 処方箋配送 / スマホ完結',
  jp_weakness = '医療特化 = 財務・タスク・AI 学習機能なし / 健康管理の包括 OS ではない'
WHERE id = 'curon';
