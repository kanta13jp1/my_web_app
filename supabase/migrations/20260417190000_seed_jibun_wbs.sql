-- 自分株式会社 開発WBS シードデータ
-- 基準日: 2026-04-17

-- ── マイルストーン ─────────────────────────────────────────────────────────────

INSERT INTO wbs_milestones (code, name, target_date, goal_users, description, color) VALUES
  ('alpha', 'α版',        '2026-05-31', 50,   'コア機能安定化・50ユーザー達成・CI/CD完全自動化',           '#4CAF50'),
  ('beta',  'β版',        '2026-07-31', 500,  '全AI統合・公開ベータ・500ユーザー達成・グロース自動化完成', '#3D5AFE'),
  ('v1',    '最終版 v1.0', '2026-10-31', 5000, '競合21社全機能対抗・5000ユーザー・収益化開始',             '#FF6B35')
ON CONFLICT (code) DO UPDATE SET
  target_date  = EXCLUDED.target_date,
  goal_users   = EXCLUDED.goal_users,
  description  = EXCLUDED.description,
  color        = EXCLUDED.color;

-- ── WBSタスク ──────────────────────────────────────────────────────────────────

-- カテゴリ1: インフラ・CI/CD (PS版担当)
INSERT INTO wbs_tasks (category, category_icon, category_order, title, description, instance, status, progress, start_date, end_date, milestone_code, priority) VALUES
  ('インフラ・CI/CD', '⚙️', 1, 'EFハードキャップ16本維持',             'deploy-prod EF 50本以下・hub統合維持', 'ps', 'in_progress', 90, '2026-04-01', '2026-05-31', 'alpha', 'high'),
  ('インフラ・CI/CD', '⚙️', 1, 'deploy-prod 成功率100%維持',           'CI失敗即修正・flutter analyze 0エラー', 'ps', 'in_progress', 80, '2026-04-01', '2026-05-31', 'alpha', 'high'),
  ('インフラ・CI/CD', '⚙️', 1, 'BYPASS_RULES secret設定',              'GitHub PAT設定でGHA direct push有効化',  'ps', 'pending',     0,  '2026-04-17', '2026-04-30', 'alpha', 'high'),
  ('インフラ・CI/CD', '⚙️', 1, 'cs-check最適化完了',                   'チケット0件時スキップ・毎時不要push排除', 'ps', 'completed',   100,'2026-04-17', '2026-04-17', 'alpha', 'medium'),
  ('インフラ・CI/CD', '⚙️', 1, 'orphan branch 0本維持',                'blog-publish orphan完全排除',            'ps', 'completed',   100,'2026-04-17', '2026-04-17', 'alpha', 'medium'),
  ('インフラ・CI/CD', '⚙️', 1, 'Rule17 WF health weekly実施',          '全WF success率90%以上維持',               'ps', 'in_progress', 70, '2026-04-01', '2026-07-31', 'beta',  'medium')
ON CONFLICT DO NOTHING;

-- カテゴリ2: デザインシステム (VSCode版担当)
INSERT INTO wbs_tasks (category, category_icon, category_order, title, description, instance, status, progress, start_date, end_date, milestone_code, priority) VALUES
  ('デザインシステム', '🎨', 2, 'DESIGN.md全ページ準拠 60%達成',         'Orange+Indigo darkテーマ統一',           'vscode', 'in_progress', 55, '2026-04-01', '2026-05-31', 'alpha', 'high'),
  ('デザインシステム', '🎨', 2, 'モバイルレスポンシブ完全対応',           'ホーム・AI大学・LP主要ページ',           'vscode', 'in_progress', 60, '2026-04-01', '2026-05-31', 'alpha', 'high'),
  ('デザインシステム', '🎨', 2, 'タイポグラフィ統一 (line-height 1.7+)', '日本語line-height 1.7-2.0統一',          'vscode', 'in_progress', 40, '2026-04-17', '2026-06-30', 'beta',  'medium'),
  ('デザインシステム', '🎨', 2, 'DESIGN.md全ページ準拠 100%達成',        '226ページ全てDESIGN.mdトークン準拠',      'vscode', 'pending',     0,  '2026-06-01', '2026-09-30', 'v1',    'medium')
ON CONFLICT DO NOTHING;

-- カテゴリ3: AI大学 (Windows版担当)
INSERT INTO wbs_tasks (category, category_icon, category_order, title, description, instance, status, progress, start_date, end_date, milestone_code, priority) VALUES
  ('AI大学',          '🎓', 3, 'AI大学 78社コンテンツ完全化',           '全78社overview/models/api/quiz整備',     'windows', 'in_progress', 85, '2026-04-01', '2026-05-15', 'alpha', 'high'),
  ('AI大学',          '🎓', 3, 'FSRS学習システム完全実装',              'SRS+MemoryAgent+HybridLLM統合',          'vscode',  'in_progress', 70, '2026-04-01', '2026-05-31', 'alpha', 'high'),
  ('AI大学',          '🎓', 3, 'ストリーク・バッジ・ランキング',         'ai_university_streaks/badges EF完成',    'vscode',  'completed',   100,'2026-04-12', '2026-04-17', 'alpha', 'medium'),
  ('AI大学',          '🎓', 3, 'AIプロバイダー一覧・チャット機能',       '78社ステータス表示+試すボタン',           'ps',      'completed',   100,'2026-04-17', '2026-04-17', 'alpha', 'medium'),
  ('AI大学',          '🎓', 3, 'AI大学 100社達成',                      '新興AIプロバイダー追加継続',               'windows', 'pending',     0,  '2026-05-01', '2026-07-31', 'beta',  'medium'),
  ('AI大学',          '🎓', 3, '音声学習機能強化',                       'TTS+STT+音声クイズ統合',                  'vscode',  'in_progress', 40, '2026-04-17', '2026-06-30', 'beta',  'medium')
ON CONFLICT DO NOTHING;

-- カテゴリ4: コアSaaS機能 (全インスタンス)
INSERT INTO wbs_tasks (category, category_icon, category_order, title, description, instance, status, progress, start_date, end_date, milestone_code, priority) VALUES
  ('コアSaaS機能',    '💼', 4, 'ノート・メモ機能 (Notion対抗)',          'リアルタイム同期・タグ・検索強化',       'vscode',  'in_progress', 60, '2026-04-01', '2026-06-30', 'beta',  'high'),
  ('コアSaaS機能',    '💼', 4, 'タスク管理 (Asana対抗)',                 'ガント・カンバン・スプリント',            'vscode',  'in_progress', 50, '2026-04-01', '2026-07-31', 'beta',  'high'),
  ('コアSaaS機能',    '💼', 4, '資産管理 (MoneyForward対抗)',            '口座連携・予算管理・レポート',            'vscode',  'in_progress', 45, '2026-04-01', '2026-07-31', 'beta',  'high'),
  ('コアSaaS機能',    '💼', 4, '競合比較ページ最新化',                    '21社機能比較テーブル常時最新',           'all',     'in_progress', 70, '2026-04-01', '2026-05-31', 'alpha', 'medium'),
  ('コアSaaS機能',    '💼', 4, '課金機能実装 (Stripe)',                  'サブスク・決済・請求管理',                'vscode',  'pending',     0,  '2026-08-01', '2026-10-31', 'v1',    'high')
ON CONFLICT DO NOTHING;

-- カテゴリ5: AI統合 (PS版 + VSCode版)
INSERT INTO wbs_tasks (category, category_icon, category_order, title, description, instance, status, progress, start_date, end_date, milestone_code, priority) VALUES
  ('AI統合',          '🤖', 5, 'ai-hub 502エラー根本修正',               'FSRS/MemoryAgent supabase→admin修正',   'ps',      'completed',   100,'2026-04-17', '2026-04-17', 'alpha', 'high'),
  ('AI統合',          '🤖', 5, 'ai-hub provider.chat 全対応',            '78社チャット呼び出し完全実装',           'ps',      'in_progress', 20, '2026-04-17', '2026-06-30', 'beta',  'high'),
  ('AI統合',          '🤖', 5, 'AIアシスタント Opus4.7/Sonnet4.6更新',   '最新モデルへのパラメータ更新',           'vscode',  'in_progress', 80, '2026-04-17', '2026-05-15', 'alpha', 'medium'),
  ('AI統合',          '🤖', 5, '画像生成統合 (Stability/Runway)',         'Supabase secrets経由の画像生成',          'ps',      'pending',     0,  '2026-06-01', '2026-09-30', 'v1',    'low'),
  ('AI統合',          '🤖', 5, 'マルチモーダルAI (音声・動画)',           'Voxtral音声生成・動画AI統合',            'vscode',  'pending',     0,  '2026-06-01', '2026-09-30', 'v1',    'low')
ON CONFLICT DO NOTHING;

-- カテゴリ6: グロース自動化 (PS版担当)
INSERT INTO wbs_tasks (category, category_icon, category_order, title, description, instance, status, progress, start_date, end_date, milestone_code, priority) VALUES
  ('グロース自動化',  '📈', 6, 'ブログ自動投稿安定化 (Qiita/dev.to)',   'T-1毎セッション投稿・Rate limit回避',   'ps',      'in_progress', 75, '2026-04-01', '2026-05-31', 'alpha', 'high'),
  ('グロース自動化',  '📈', 6, 'X自動投稿 daily-report連携',             '@kanta13jp1 毎日自動ツイート',           'ps',      'in_progress', 60, '2026-04-01', '2026-05-31', 'alpha', 'medium'),
  ('グロース自動化',  '📈', 6, 'YouTube競合分析自動化',                   'updated_table.tsv日次更新',              'ps',      'in_progress', 70, '2026-04-01', '2026-06-30', 'beta',  'medium'),
  ('グロース自動化',  '📈', 6, '競合21社モニタリング自動化',              'competitor-monitoring.yml安定稼働',      'all',     'in_progress', 50, '2026-04-01', '2026-07-31', 'beta',  'medium'),
  ('グロース自動化',  '📈', 6, 'NotebookLM Master Brain完全活用',         '4時間毎Deep Research・知識蓄積',         'ps',      'in_progress', 40, '2026-04-17', '2026-07-31', 'beta',  'medium')
ON CONFLICT DO NOTHING;

-- カテゴリ7: ユーザー獲得 (全インスタンス)
INSERT INTO wbs_tasks (category, category_icon, category_order, title, description, instance, status, progress, start_date, end_date, milestone_code, priority) VALUES
  ('ユーザー獲得',    '👥', 7, 'LP最適化 (120のこと完全掲載)',           'CTA改善・価値訴求強化・A/Bテスト',       'all',     'in_progress', 65, '2026-04-01', '2026-05-31', 'alpha', 'high'),
  ('ユーザー獲得',    '👥', 7, 'SEO改善 (sitemap・meta tags)',            '22URL sitemap・OGP・キーワード最適化',   'all',     'in_progress', 55, '2026-04-01', '2026-05-31', 'alpha', 'high'),
  ('ユーザー獲得',    '👥', 7, 'オンボーディング最適化',                   '初回体験フロー・チュートリアル強化',     'vscode',  'pending',     10, '2026-05-01', '2026-07-31', 'beta',  'high'),
  ('ユーザー獲得',    '👥', 7, '紹介プログラム実装',                       '招待リンク・インセンティブ設計',         'vscode',  'pending',     0,  '2026-06-01', '2026-07-31', 'beta',  'medium'),
  ('ユーザー獲得',    '👥', 7, 'ユーザー数50人達成 (α版目標)',            'アクティブユーザー50人',                  'all',     'in_progress', 8,  '2026-04-17', '2026-05-31', 'alpha', 'high'),
  ('ユーザー獲得',    '👥', 7, 'ユーザー数500人達成 (β版目標)',           'アクティブユーザー500人',                 'all',     'pending',     0,  '2026-06-01', '2026-07-31', 'beta',  'high'),
  ('ユーザー獲得',    '👥', 7, 'ユーザー数5000人達成 (v1目標)',           'アクティブユーザー5000人',                'all',     'pending',     0,  '2026-08-01', '2026-10-31', 'v1',    'high')
ON CONFLICT DO NOTHING;

-- カテゴリ8: 品質・安定性 (全インスタンス)
INSERT INTO wbs_tasks (category, category_icon, category_order, title, description, instance, status, progress, start_date, end_date, milestone_code, priority) VALUES
  ('品質・安定性',    '🛡️', 8, 'flutter analyze 0エラー常時維持',        '全コミット前analyze必須',                'vscode',  'in_progress', 85, '2026-04-01', '2026-10-31', 'alpha', 'high'),
  ('品質・安定性',    '🛡️', 8, 'deno lint 0エラー維持',                  '全EF変更後deno lint必須',                'ps',      'in_progress', 85, '2026-04-01', '2026-10-31', 'alpha', 'high'),
  ('品質・安定性',    '🛡️', 8, 'Webパフォーマンス最適化 (LCP < 2.5s)',   'Flutter Web bundle size削減',            'vscode',  'pending',     20, '2026-05-01', '2026-07-31', 'beta',  'medium'),
  ('品質・安定性',    '🛡️', 8, 'E2Eテスト整備 (Playwright)',             'Playwrightで主要フロー自動テスト',       'vscode',  'pending',     0,  '2026-07-01', '2026-10-31', 'v1',    'medium'),
  ('品質・安定性',    '🛡️', 8, 'エラー監視強化 (Sentry連携)',             '本番エラー自動通知・アラート',            'ps',      'pending',     0,  '2026-06-01', '2026-10-31', 'v1',    'medium')
ON CONFLICT DO NOTHING;
