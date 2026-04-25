-- PS#4 S50: 競合 Phase 3 Batch 2 — 95→110社化 (2026-04-26)
-- Developer Tools / Finance JP / Health JP / Collaboration / Data/AI Platform
-- 累計 110社 (目標190社の 58%)

INSERT INTO public.competitors (
  id, name, display_name, category, website_url,
  description, funding_or_valuation, employee_count_range,
  key_features, our_overlap_score, threat_level,
  founded_year, headquarters, is_active, created_at, updated_at
) VALUES

-- ============================================================
-- Developer Tools / DevOps (5社)
-- ============================================================
(
  'datadog',
  'DataDog',
  'Datadog',
  'developer-tools',
  'https://www.datadoghq.com',
  'クラウド規模のモニタリング・APM・ログ管理。インフラ〜アプリ〜セキュリティを統合可視化。',
  '$50B valuation (NYSE: DDOG, 2024)',
  '5000+',
  ARRAY['APM','インフラモニタリング','ログ管理','セキュリティ監視','AI Observability'],
  4, 'medium',
  2010, 'New York, USA', true, now(), now()
),
(
  'sentry',
  'Sentry',
  'Sentry',
  'developer-tools',
  'https://sentry.io',
  'アプリケーションエラー監視・パフォーマンストレーシング。90,000社以上が利用するOSSベースのエラー管理プラットフォーム。',
  '$3.5B valuation (Series F $200M)',
  '1000+',
  ARRAY['エラー監視','パフォーマンストレース','リリース追跡','AI修正提案','Slack連携'],
  5, 'medium',
  2012, 'San Francisco, USA', true, now(), now()
),
(
  'postman',
  'Postman',
  'Postman',
  'developer-tools',
  'https://www.postman.com',
  'API開発・テスト・ドキュメント化プラットフォーム。世界30万社・2,000万人の開発者が利用。',
  '$5.6B valuation (Series D $225M)',
  '1000+',
  ARRAY['APIテスト','APIドキュメント','モックサーバー','APIモニタリング','チームコラボ'],
  4, 'low',
  2014, 'San Francisco, USA', true, now(), now()
),
(
  'vercel',
  'Vercel',
  'Vercel',
  'developer-tools',
  'https://vercel.com',
  'フロントエンド向けクラウドプラットフォーム。Next.js作者が創業。GitプッシュでCI/CD+CDNデプロイ自動化。',
  '$3.25B valuation (Series E $150M)',
  '500+',
  ARRAY['フロントエンドデプロイ','エッジネットワーク','プレビュー環境','Analytics','AI SDK'],
  5, 'medium',
  2015, 'San Francisco, USA', true, now(), now()
),
(
  'linear',
  'Linear',
  'Linear',
  'developer-tools',
  'https://linear.app',
  '高速プロジェクト管理ツール。開発チーム向けIssueトラッカー。Notionのdev向け競合。シンプルUX+高速動作が特徴。',
  '$400M valuation (Series B $35M)',
  '100+',
  ARRAY['Issueトラッカー','スプリント管理','GitHubリンク','ロードマップ','API'],
  7, 'high',
  2019, 'San Francisco, USA', true, now(), now()
),

-- ============================================================
-- Finance JP / クラウド会計 (4社)
-- ============================================================
(
  'freee',
  'freee',
  'freee',
  'fintech',
  'https://www.freee.co.jp',
  '日本最大のクラウド会計・労務SaaS。個人事業主〜中小企業向け。売上450億円超。TSE:4478。',
  '¥450億売上 (TSE:4478)',
  '2000+',
  ARRAY['クラウド会計','給与計算','確定申告','マイナンバー管理','銀行自動連携'],
  8, 'high',
  2012, '東京都品川区', true, now(), now()
),
(
  'moneyforward-cloud',
  'Money Forward Cloud',
  'マネーフォワード クラウド',
  'fintech',
  'https://biz.moneyforward.com',
  '法人向けクラウド会計・経費精算・請求書・給与計算SaaS。TSE:3994。個人向けMFとは別プロダクト。',
  '¥300億売上 (TSE:3994)',
  '3000+',
  ARRAY['クラウド会計','経費精算','請求書作成','給与計算','電子帳簿保存法対応'],
  8, 'high',
  2012, '東京都港区', true, now(), now()
),
(
  'yayoi',
  'Yayoi',
  '弥生',
  'fintech',
  'https://www.yayoi-kk.co.jp',
  '日本最老舗の会計ソフト。中小企業・個人事業主向けパッケージ＆クラウド。累計250万社超。MF傘下。',
  '売上非公開 (MFグループ)',
  '1000+',
  ARRAY['青色申告','確定申告','給与計算','請求書作成','インボイス対応'],
  7, 'medium',
  1978, '東京都千代田区', true, now(), now()
),
(
  'sansan',
  'Sansan',
  'Sansan',
  'fintech',
  'https://sansan.com',
  '法人向け名刺管理・営業DXプラットフォーム。Eight個人版も展開。「名刺をデジタル資産に」売上260億超。',
  '¥260億売上 (TSE:4443)',
  '2000+',
  ARRAY['名刺デジタル化','人脈管理','SFA連携','Eight個人版','請求書受領自動化'],
  6, 'medium',
  2007, '東京都渋谷区', true, now(), now()
),

-- ============================================================
-- Health JP / オンライン医療 (2社)
-- ============================================================
(
  'curon',
  'curon',
  'curon（クロン）',
  'health',
  'https://curon.co',
  '日本最大級のオンライン診療サービス。スマホで予約→診察→処方→薬を自宅に配送まで完結。MICIN運営。',
  '非公開 (MICIN: Series D $70M)',
  '300+',
  ARRAY['オンライン診療','処方箋発行','服薬指導','医療機関検索','電子処方箋'],
  5, 'low',
  2015, '東京都千代田区', true, now(), now()
),
(
  'carely',
  'Carely',
  'Carely',
  'health',
  'https://carely.jp',
  '産業医・保健師と連携する健康管理SaaS。ストレスチェック・勤怠連携・健康診断管理。800社導入。',
  '非公開 (iCARE: シリーズB)',
  '100+',
  ARRAY['ストレスチェック','健康診断管理','勤怠連携','産業医面談','健康スコア'],
  6, 'medium',
  2016, '東京都渋谷区', true, now(), now()
),

-- ============================================================
-- Collaboration / ホワイトボード・デザイン (2社)
-- ============================================================
(
  'miro',
  'Miro',
  'Miro',
  'productivity',
  'https://miro.com',
  'オンラインホワイトボード・コラボレーションプラットフォーム。60M+ユーザー。リモートワーク定番ツール。',
  '$17.5B valuation (Series C $400M)',
  '2000+',
  ARRAY['デジタルホワイトボード','ブレスト','マインドマップ','プロジェクト管理','AI機能'],
  6, 'medium',
  2011, 'San Francisco, USA', true, now(), now()
),
(
  'figma',
  'Figma',
  'Figma',
  'developer-tools',
  'https://www.figma.com',
  'ブラウザベースのコラボレーティブデザインツール。UI/UXデザイン業界標準。Adobe買収案$20Bが独禁法で破談。',
  '$20B valuation (IPO準備中)',
  '1000+',
  ARRAY['UIデザイン','プロトタイプ','デザインシステム','Dev Mode','FigJam'],
  5, 'medium',
  2012, 'San Francisco, USA', true, now(), now()
),

-- ============================================================
-- Data / AI Platform (2社)
-- ============================================================
(
  'snowflake',
  'Snowflake',
  'Snowflake',
  'ai-infrastructure',
  'https://www.snowflake.com',
  'クラウドデータウェアハウス。NYSE:SNOW。AIアプリ・データシェアリング・Cortex AI MLまで統合。',
  '$50B valuation (NYSE: SNOW)',
  '7000+',
  ARRAY['データウェアハウス','データシェアリング','Snowpark ML','Cortex AI','ストリーミング'],
  4, 'medium',
  2012, 'Bozeman, USA', true, now(), now()
),
(
  'databricks',
  'Databricks',
  'Databricks',
  'ai-infrastructure',
  'https://www.databricks.com',
  'データ+AIの統合レイクハウスプラットフォーム。Spark/Delta Lake/MLflowの生みの親。$62B評価額。',
  '$62B valuation (Series J $500M)',
  '6000+',
  ARRAY['Delta Lake','MLflow','Spark','Unity Catalog','DBRX LLM'],
  4, 'medium',
  2013, 'San Francisco, USA', true, now(), now()
)

ON CONFLICT (id) DO UPDATE SET
  display_name        = EXCLUDED.display_name,
  description         = EXCLUDED.description,
  funding_or_valuation= EXCLUDED.funding_or_valuation,
  key_features        = EXCLUDED.key_features,
  our_overlap_score   = EXCLUDED.our_overlap_score,
  threat_level        = EXCLUDED.threat_level,
  updated_at          = now();

-- ============================================================
-- 実績記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競合 95→110社化 Phase 3 Batch 2 (PS#4 S50)',
  'Developer Tools (DataDog/Sentry/Postman/Vercel/Linear) + Finance JP (freee/MF Cloud/弥生/Sansan) + ' ||
  'Health JP (curon/Carely) + Collaboration (Miro/Figma) + Data/AI Platform (Snowflake/Databricks) = 15社追加。' ||
  '累計 110社 / 目標190社の 58%。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
