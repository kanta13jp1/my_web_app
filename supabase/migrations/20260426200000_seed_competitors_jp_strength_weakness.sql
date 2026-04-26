-- PS#4 S62: competitors jp_strength/jp_weakness 補完 (18 high-threat 対象)
-- 2026-04-26 競合インテリジェンス品質向上

UPDATE competitors SET
  jp_strength = '国内SME向けクラウド会計 No.1 / 会計士・税理士連携が密 / freeeと並ぶ2強',
  jp_weakness = '個人ユーザーには複雑すぎる / 月額コストが高い / ライフ統合機能なし',
  updated_at = NOW()
WHERE id = 'moneyforward-cloud';

UPDATE competitors SET
  jp_strength = '50+ アプリスイート / 低価格・無料プランあり / CRM+会計+HRワンストップ',
  jp_weakness = '日本語サポートが弱い / UXが古くモバイル体験劣る / ローカライズ不足',
  updated_at = NOW()
WHERE id = 'zoho-crm';

UPDATE competitors SET
  jp_strength = 'スケジュール自動化グローバル標準 / 多数カレンダー統合 / Zoom/Teams連携',
  jp_weakness = '日本語対応が弱い / 個人ライフ統合には特化していない / 単機能',
  updated_at = NOW()
WHERE id = 'calendly';

UPDATE competitors SET
  jp_strength = 'CRM + マーケティング一体化 / 無料プランが充実 / 日本法人あり',
  jp_weakness = '個人ユーザー向けではない / 有料プラン価格が高い / 法人向けに偏重',
  updated_at = NOW()
WHERE id = 'hubspot-crm';

UPDATE competitors SET
  jp_strength = '電子署名グローバル標準 / 法的効力が高い / 日本電子署名法対応',
  jp_weakness = '個人ライフ管理との親和性が低い / 高価格 / 単機能',
  updated_at = NOW()
WHERE id = 'docusign';

UPDATE competitors SET
  jp_strength = 'マーケティングコンテンツ生成特化 / ブランドボイス管理 / SEO最適化',
  jp_weakness = '日本語コンテンツ品質が低い / 価格が高い ($49+/月) / 個人向けでない',
  updated_at = NOW()
WHERE id = 'jasper-ai';

UPDATE competitors SET
  jp_strength = 'ノーコード自動化 / 1500+ アプリ統合 / Zapier比低価格',
  jp_weakness = '学習曲線が急 / 日本語ドキュメントが少ない / UXが複雑',
  updated_at = NOW()
WHERE id = 'make-integromat';

UPDATE competitors SET
  jp_strength = 'ノート/Wiki/DB/AI 一体化 / Japan DC 2026年5月開設予定 / チーム協調が強い',
  jp_weakness = '個人財務管理なし / 日本独自機能（確定申告等）なし / 価格が高い',
  updated_at = NOW()
WHERE id = 'notion';

UPDATE competitors SET
  jp_strength = '長年の信頼と知名度 / Web クリッパーが強い / タグ・検索が優秀',
  jp_weakness = '有料化で競争力低下 / AI機能が後れを取る / 2023年大幅値上げ批判',
  updated_at = NOW()
WHERE id = 'evernote';

UPDATE competitors SET
  jp_strength = '個人家計管理 No.1 / 2500+ 金融機関連携 / MoneyForward ME で個人向け',
  jp_weakness = 'AIパーソナライゼーション弱い / 生活全体の統合なし / Notionとの連携なし',
  updated_at = NOW()
WHERE id = 'moneyforward';

UPDATE competitors SET
  jp_strength = 'AI 検索エンジン / 引用付き回答で信頼性高い / Pro プラン成長中',
  jp_weakness = '生活管理機能なし / 単機能AI / 記憶・継続性が弱い',
  updated_at = NOW()
WHERE id = 'perplexity-ai';

UPDATE competitors SET
  jp_strength = '法務特化AI / Big Law 採用実績 / 契約レビュー高精度',
  jp_weakness = '個人ライフ管理とは無関係 / 高価格 / 日本法対応未確認',
  updated_at = NOW()
WHERE id = 'harvey-ai';

UPDATE competitors SET
  jp_strength = '完全自律型コーディングエージェント / GitHub 統合 / PR 自動作成',
  jp_weakness = '開発者専用 / 個人ライフ管理なし / 月額$500+ と高価',
  updated_at = NOW()
WHERE id = 'devin-cognition';

UPDATE competitors SET
  jp_strength = 'Google エコシステム統合 / 無料提供の可能性 / バックグラウンド自律実行',
  jp_weakness = '限定公開 (beta) / UI なし / 個人ライフ管理なし',
  updated_at = NOW()
WHERE id = 'jules-google';

UPDATE competitors SET
  jp_strength = 'エンタメ×EC融合でエンゲージメント高 / 若年層へのリーチ力',
  jp_weakness = '日本規制リスク / プライバシー懸念 / ライフ管理機能なし',
  updated_at = NOW()
WHERE id = 'tiktok-shop';

UPDATE competitors SET
  jp_strength = 'コード品質・テスト自動化専門 / ドリフト検出が強み',
  jp_weakness = 'エンジニア専用 / 個人ライフ管理なし / 日本市場展開未確認',
  updated_at = NOW()
WHERE id = 'factory-ai';

UPDATE competitors SET
  jp_strength = 'エンタープライズ向け LLM / RAG特化 / Command R+ でコスト効率高',
  jp_weakness = '個人向け製品なし / 技術系のみ / B2B 専業',
  updated_at = NOW()
WHERE id = 'cohere-ai';

UPDATE competitors SET
  jp_strength = '長期記憶 LLM (100M+ token) / コーディング特化 / $23M調達済',
  jp_weakness = '個人向け製品なし / 限定アクセス中 / 日本市場展開なし',
  updated_at = NOW()
WHERE id = 'magic-ai';
