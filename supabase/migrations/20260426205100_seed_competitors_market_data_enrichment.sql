-- PS#4 S63: competitors market data enrichment (user_count / funding / key_features)
-- 対象: notion-ai / notion / v0 / bolt-new / cursor / obsidian / logseq / bear-app + 追加

-- notion-ai (overlap=9, 最高脅威)
UPDATE competitors SET
  user_count = 100000000,
  jp_strength = 'Notion ワークスペース統合AI / ドキュメント・DB・タスク横断でAIが動く / エンタープライズ信頼性',
  jp_weakness = '単体サービスとして独立不可 / Notion本体が必要 / 個人財務・習慣化・健康管理なし',
  key_features = ARRAY['AIドキュメント生成', 'Q&A・要約', 'オートフィル', '翻訳', 'AIデータベース', 'Custom Agents (β)'],
  updated_at = NOW()
WHERE id = 'notion-ai';

-- notion (本体 / overlap=7)
UPDATE competitors SET
  user_count = 100000000,
  founded_year = 2016,
  funding_or_valuation = '$10B (2021年評価額)',
  key_features = ARRAY['ノート/Wiki/DB一体化', 'Custom Agents', 'Japan DC 2026-05予定', 'AIライティング', 'テンプレギャラリー'],
  jp_strength = 'ノート/Wiki/DB/AI 一体化 / Japan DC 2026年5月開設予定 / チーム協調が強い',
  jp_weakness = '個人財務管理なし / 日本独自機能（確定申告等）なし / 価格が高い ($16+/月)',
  updated_at = NOW()
WHERE id = 'notion';

-- evernote (overlap=7)
UPDATE competitors SET
  user_count = 250000000,
  founded_year = 2004,
  funding_or_valuation = '$485M (累計調達)',
  key_features = ARRAY['ノート・メモ', 'Webクリッパー', 'OCR・手書き認識', 'PDF注釈', 'タスク管理'],
  updated_at = NOW()
WHERE id = 'evernote';

-- moneyforward (個人/overlap=7)
UPDATE competitors SET
  user_count = 15000000,
  founded_year = 2012,
  funding_or_valuation = '上場 (東証プライム / 時価総額約2000億円)',
  key_features = ARRAY['家計簿自動連携', '2500+金融機関対応', '資産管理', '請求書・確定申告', 'マネーフォワードME'],
  updated_at = NOW()
WHERE id = 'moneyforward';

-- v0 by Vercel (overlap=7)
UPDATE competitors SET
  user_count = 5000000,
  founded_year = 2023,
  funding_or_valuation = '$3.25B (Vercel 評価額)',
  key_features = ARRAY['テキスト→React UI生成', 'shadcn/ui出力', 'Next.js即デプロイ', 'ライブプレビュー', 'TypeScript対応'],
  updated_at = NOW()
WHERE id = 'v0';

-- bolt.new by StackBlitz (overlap=7)
UPDATE competitors SET
  user_count = 3000000,
  founded_year = 2023,
  funding_or_valuation = '$50M (StackBlitz 累計調達)',
  key_features = ARRAY['WebContainer技術', 'フルスタック生成', 'npm/node対応', 'ワンクリックデプロイ', 'AI対話型開発'],
  updated_at = NOW()
WHERE id = 'bolt-new';

-- cursor (overlap=7)
UPDATE competitors SET
  user_count = 500000,
  founded_year = 2022,
  key_features = ARRAY['VS Code互換IDE', 'Composer (マルチファイル編集)', 'コードベース理解', 'エージェントモード', 'Rules for AI'],
  updated_at = NOW()
WHERE id = 'cursor';

-- obsidian (overlap=7)
UPDATE competitors SET
  founded_year = 2020,
  key_features = ARRAY['ローカルMarkdown', 'グラフビュー (知識グラフ)', '豊富なプラグイン', 'Vault暗号化', 'Canvas (視覚化)'],
  updated_at = NOW()
WHERE id = 'obsidian';

-- logseq (overlap=7)
UPDATE competitors SET
  founded_year = 2020,
  key_features = ARRAY['アウトライナーDB', 'ブロックリファレンス', 'Journals (デイリーノート)', 'グラフビュー', 'Clojureベース OSS'],
  updated_at = NOW()
WHERE id = 'logseq';

-- bear-app (overlap=7)
UPDATE competitors SET
  founded_year = 2016,
  funding_or_valuation = 'ブートストラップ (設立者資金)',
  key_features = ARRAY['Markdownノート', 'タグシステム', 'iOS/Mac専用', 'テーマ豊富', 'Bear 2 (2023)'],
  updated_at = NOW()
WHERE id = 'bear-app';

-- hubspot-crm (overlap=7)
UPDATE competitors SET
  user_count = 200000,
  founded_year = 2006,
  funding_or_valuation = '上場 (NYSE: HUBS / 時価総額約2兆円)',
  key_features = ARRAY['CRM', 'マーケティングハブ', 'セールスハブ', 'AIコンテンツ生成', 'メール自動化'],
  updated_at = NOW()
WHERE id = 'hubspot-crm';

-- zoho-crm (overlap=8)
UPDATE competitors SET
  user_count = 100000000,
  founded_year = 1996,
  funding_or_valuation = 'プライベート / 推定$10B+',
  key_features = ARRAY['50+アプリスイート', 'CRM', '会計', 'HR', 'AI Zia', 'ゼロ広告ポリシー'],
  updated_at = NOW()
WHERE id = 'zoho-crm';
