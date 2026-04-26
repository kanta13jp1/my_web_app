-- PS#4 S66: jp_strength/jp_weakness 補完 Batch 2 (15社)
-- 対象: cloudsign(CRITICAL/ov8) + 14社(MEDIUM/LOW/ov5-6)

UPDATE competitors SET
  jp_strength = '国内電子署名 No.1 / 弁護士ドットコム運営 / 法務省電子署名法完全対応 / 180万件超の契約実績 / 金融機関・官公庁・上場企業多数導入',
  jp_weakness = '契約・法務管理に特化 = ライフマネジメント機能ゼロ / 個人向け無料プランなし / タスク管理・財務・健康管理なし'
WHERE id = 'cloudsign';

UPDATE competitors SET
  jp_strength = '国産 HR 管理 SaaS / 無料プランあり / SMBC グループ等大手採用 / 人事評価・勤怠・採用管理を一体化 / 日本語 UI 完備',
  jp_weakness = 'B2B 専用 / 個人ライフマネジメント・財務管理なし / メモ・タスク・AI 機能なし'
WHERE id = 'hrmos';

UPDATE competitors SET
  jp_strength = '企業向け健康経営支援 / 産業医サポート連携 / 労務・健康管理統合 / 上場企業 600 社超導入 / 法令遵守対応',
  jp_weakness = '企業向けに完全特化 / 個人利用不可 / 財務・目標管理・AI 機能なし'
WHERE id = 'carely';

UPDATE competitors SET
  jp_strength = '1000+ API 統合 / ノーコード + コードハイブリッド自動化 / 無料プラン充実 / 開発者向け高度な自動化フロー',
  jp_weakness = '日本語ドキュメント薄い / エンドユーザー向け UI なし / 個人ライフ OS 機能なし / 非エンジニアには難易度高'
WHERE id = 'pipedream';

UPDATE competitors SET
  jp_strength = '国産ネットショップ作成 No.1 / フリープランあり / 決済・在庫・分析一体化 / 日本語サポート充実 / 30万店舗超',
  jp_weakness = 'EC 特化 = メモ・タスク・AI・健康機能なし / 個人ライフマネジメントなし'
WHERE id = 'stores-jp';

UPDATE competitors SET
  jp_strength = '世界最大 Web サイトビルダー / AI 生成サイト機能 / 日本語対応 / 2 億超ユーザー / 豊富なテンプレート',
  jp_weakness = 'Web サイト作成特化 / 個人財務・健康・AI 学習機能なし / ライフ OS 機能なし'
WHERE id = 'wix';

UPDATE competitors SET
  jp_strength = '美しいインタラクティブフォーム / 高回答率 / 500+ 統合 / AI 自動化対応 / UX が業界最高水準',
  jp_weakness = 'フォーム・アンケート特化 / 個人ライフマネジメント機能なし / 日本語ローカライズ薄い / 高コスト'
WHERE id = 'typeform';

UPDATE competitors SET
  jp_strength = 'ゲーマー・クリエイターコミュニティ 3 億超ユーザー / 無料・低遅延音声通話 / Bot 自動化豊富 / 日本語サーバー活発',
  jp_weakness = '業務・財務・タスク管理機能なし / エンタープライズセキュリティ弱い / AI 機能まだ限定的'
WHERE id = 'discord';

UPDATE competitors SET
  jp_strength = '英語ライティング AI 世界 No.1 / 3500 万ユーザー / ブラウザ全体統合 / ビジネス文書品質向上 / 企業向け強化',
  jp_weakness = '英語専用（日本語対応なし） / 財務・タスク・健康管理なし / 日本市場での利用限定的'
WHERE id = 'grammarly';

UPDATE competitors SET
  jp_strength = '音声クローン業界最高品質 / 29 言語対応 / API 充実 / $80M 調達 / 1 億件超コンテンツ生成実績',
  jp_weakness = '音声合成特化 / 個人ライフマネジメント機能なし / Pro プラン $22/月と高コスト'
WHERE id = 'elevenlabs';

UPDATE competitors SET
  jp_strength = 'SOC2/ISO27001 自動化 / 750+ 統合 / Series C $150M / Fortune500 採用 / コンプライアンス自動化のデファクト',
  jp_weakness = '企業コンプライアンス特化 / 個人向け機能なし / 日本市場参入まだ薄い / 高コスト'
WHERE id = 'vanta';

UPDATE competitors SET
  jp_strength = 'エラー監視世界標準 / 4 万社以上導入 / OSS + SaaS / 多言語 SDK 完備 / AI エラー分析機能追加中',
  jp_weakness = '開発者専用ツール / 個人ライフ管理機能なし / 非エンジニア向け UI なし'
WHERE id = 'sentry';

UPDATE competitors SET
  jp_strength = 'SOC2/HIPAA/GDPR 自動コンプライアンス / Series C $200M / 4000 社超 / AI ドリフト検知 / 監査自動化',
  jp_weakness = 'エンタープライズコンプライアンス特化 / 個人向け機能なし / 日本語対応限定的 / 高コスト'
WHERE id = 'drata';

UPDATE competitors SET
  jp_strength = '国内 D2C 専門 EC No.1 / 定期通販・LTV 最適化 / API 充実 / 売上管理・CRM 統合 / 高い LTV',
  jp_weakness = 'EC 事業者専用 / 個人ライフマネジメント・AI 機能なし / 一般消費者向けでない'
WHERE id = 'ecforce';

UPDATE competitors SET
  jp_strength = '日本最大オンライン学習 / 8500 本+ 講座 / 法人 930 社+ / 生放送授業あり / 月額 980 円の低コスト',
  jp_weakness = '動画学習特化 / AI 機能なし / 個人財務・習慣化・タスク管理なし'
WHERE id = 'schoo';
