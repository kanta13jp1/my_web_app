-- PS#4 S55: competitor_features seed — 21 社 × 10 機能 (Phase 1)
-- feature_key リスト: notes / task_management / calendar / finance_tracking /
--   ai_assistant / messaging / social_sharing / code_assistant / document_management / collaboration
-- jibun_status: 自分株式会社の実装状況 (done/partial/notYet)

INSERT INTO public.competitor_features
  (competitor_id, feature_key, feature_name_ja, has_feature, jibun_status)
VALUES
-- ================================================================
-- notion
-- ================================================================
('notion', 'notes',               'ノート・メモ',       true,  'done'),
('notion', 'task_management',     'タスク管理',         true,  'done'),
('notion', 'calendar',            'カレンダー',         true,  'notYet'),
('notion', 'finance_tracking',    '家計・財務管理',     false, 'notYet'),
('notion', 'ai_assistant',        'AIアシスタント',     true,  'done'),
('notion', 'messaging',           'メッセージ・チャット',false, 'notYet'),
('notion', 'social_sharing',      'SNS・シェア',        false, 'partial'),
('notion', 'code_assistant',      'コード補助',         false, 'notYet'),
('notion', 'document_management', 'ドキュメント管理',   true,  'partial'),
('notion', 'collaboration',       'チームコラボ',       true,  'notYet'),
-- ================================================================
-- evernote
-- ================================================================
('evernote', 'notes',               'ノート・メモ',       true,  'done'),
('evernote', 'task_management',     'タスク管理',         true,  'done'),
('evernote', 'calendar',            'カレンダー',         false, 'notYet'),
('evernote', 'finance_tracking',    '家計・財務管理',     false, 'notYet'),
('evernote', 'ai_assistant',        'AIアシスタント',     true,  'done'),
('evernote', 'messaging',           'メッセージ・チャット',false, 'notYet'),
('evernote', 'social_sharing',      'SNS・シェア',        false, 'partial'),
('evernote', 'code_assistant',      'コード補助',         false, 'notYet'),
('evernote', 'document_management', 'ドキュメント管理',   true,  'partial'),
('evernote', 'collaboration',       'チームコラボ',       true,  'notYet'),
-- ================================================================
-- moneyforward
-- ================================================================
('moneyforward', 'notes',               'ノート・メモ',       false, 'done'),
('moneyforward', 'task_management',     'タスク管理',         false, 'done'),
('moneyforward', 'calendar',            'カレンダー',         false, 'notYet'),
('moneyforward', 'finance_tracking',    '家計・財務管理',     true,  'notYet'),
('moneyforward', 'ai_assistant',        'AIアシスタント',     true,  'done'),
('moneyforward', 'messaging',           'メッセージ・チャット',false, 'notYet'),
('moneyforward', 'social_sharing',      'SNS・シェア',        false, 'partial'),
('moneyforward', 'code_assistant',      'コード補助',         false, 'notYet'),
('moneyforward', 'document_management', 'ドキュメント管理',   false, 'partial'),
('moneyforward', 'collaboration',       'チームコラボ',       false, 'notYet'),
-- ================================================================
-- slack
-- ================================================================
('slack', 'notes',               'ノート・メモ',       true,  'done'),
('slack', 'task_management',     'タスク管理',         true,  'done'),
('slack', 'calendar',            'カレンダー',         true,  'notYet'),
('slack', 'finance_tracking',    '家計・財務管理',     false, 'notYet'),
('slack', 'ai_assistant',        'AIアシスタント',     true,  'done'),
('slack', 'messaging',           'メッセージ・チャット',true,  'notYet'),
('slack', 'social_sharing',      'SNS・シェア',        false, 'partial'),
('slack', 'code_assistant',      'コード補助',         true,  'notYet'),
('slack', 'document_management', 'ドキュメント管理',   true,  'partial'),
('slack', 'collaboration',       'チームコラボ',       true,  'notYet'),
-- ================================================================
-- chatwork
-- ================================================================
('chatwork', 'notes',               'ノート・メモ',       false, 'done'),
('chatwork', 'task_management',     'タスク管理',         true,  'done'),
('chatwork', 'calendar',            'カレンダー',         false, 'notYet'),
('chatwork', 'finance_tracking',    '家計・財務管理',     false, 'notYet'),
('chatwork', 'ai_assistant',        'AIアシスタント',     true,  'done'),
('chatwork', 'messaging',           'メッセージ・チャット',true,  'notYet'),
('chatwork', 'social_sharing',      'SNS・シェア',        false, 'partial'),
('chatwork', 'code_assistant',      'コード補助',         false, 'notYet'),
('chatwork', 'document_management', 'ドキュメント管理',   false, 'partial'),
('chatwork', 'collaboration',       'チームコラボ',       true,  'notYet'),
-- ================================================================
-- discord
-- ================================================================
('discord', 'notes',               'ノート・メモ',       false, 'done'),
('discord', 'task_management',     'タスク管理',         false, 'done'),
('discord', 'calendar',            'カレンダー',         false, 'notYet'),
('discord', 'finance_tracking',    '家計・財務管理',     false, 'notYet'),
('discord', 'ai_assistant',        'AIアシスタント',     true,  'done'),
('discord', 'messaging',           'メッセージ・チャット',true,  'notYet'),
('discord', 'social_sharing',      'SNS・シェア',        true,  'partial'),
('discord', 'code_assistant',      'コード補助',         false, 'notYet'),
('discord', 'document_management', 'ドキュメント管理',   false, 'partial'),
('discord', 'collaboration',       'チームコラボ',       true,  'notYet'),
-- ================================================================
-- line
-- ================================================================
('line', 'notes',               'ノート・メモ',       false, 'done'),
('line', 'task_management',     'タスク管理',         false, 'done'),
('line', 'calendar',            'カレンダー',         false, 'notYet'),
('line', 'finance_tracking',    '家計・財務管理',     false, 'notYet'),
('line', 'ai_assistant',        'AIアシスタント',     true,  'done'),
('line', 'messaging',           'メッセージ・チャット',true,  'notYet'),
('line', 'social_sharing',      'SNS・シェア',        true,  'partial'),
('line', 'code_assistant',      'コード補助',         false, 'notYet'),
('line', 'document_management', 'ドキュメント管理',   false, 'partial'),
('line', 'collaboration',       'チームコラボ',       false, 'notYet'),
-- ================================================================
-- x (旧 Twitter)
-- ================================================================
('x', 'notes',               'ノート・メモ',       false, 'done'),
('x', 'task_management',     'タスク管理',         false, 'done'),
('x', 'calendar',            'カレンダー',         false, 'notYet'),
('x', 'finance_tracking',    '家計・財務管理',     false, 'notYet'),
('x', 'ai_assistant',        'AIアシスタント',     true,  'done'),
('x', 'messaging',           'メッセージ・チャット',true,  'notYet'),
('x', 'social_sharing',      'SNS・シェア',        true,  'partial'),
('x', 'code_assistant',      'コード補助',         false, 'notYet'),
('x', 'document_management', 'ドキュメント管理',   false, 'partial'),
('x', 'collaboration',       'チームコラボ',       false, 'notYet'),
-- ================================================================
-- facebook (Meta)
-- ================================================================
('facebook', 'notes',               'ノート・メモ',       false, 'done'),
('facebook', 'task_management',     'タスク管理',         false, 'done'),
('facebook', 'calendar',            'カレンダー',         true,  'notYet'),
('facebook', 'finance_tracking',    '家計・財務管理',     false, 'notYet'),
('facebook', 'ai_assistant',        'AIアシスタント',     true,  'done'),
('facebook', 'messaging',           'メッセージ・チャット',true,  'notYet'),
('facebook', 'social_sharing',      'SNS・シェア',        true,  'partial'),
('facebook', 'code_assistant',      'コード補助',         false, 'notYet'),
('facebook', 'document_management', 'ドキュメント管理',   false, 'partial'),
('facebook', 'collaboration',       'チームコラボ',       true,  'notYet'),
-- ================================================================
-- claude-code
-- ================================================================
('claude-code', 'notes',               'ノート・メモ',       false, 'done'),
('claude-code', 'task_management',     'タスク管理',         false, 'done'),
('claude-code', 'calendar',            'カレンダー',         false, 'notYet'),
('claude-code', 'finance_tracking',    '家計・財務管理',     false, 'notYet'),
('claude-code', 'ai_assistant',        'AIアシスタント',     true,  'done'),
('claude-code', 'messaging',           'メッセージ・チャット',false, 'notYet'),
('claude-code', 'social_sharing',      'SNS・シェア',        false, 'partial'),
('claude-code', 'code_assistant',      'コード補助',         true,  'notYet'),
('claude-code', 'document_management', 'ドキュメント管理',   false, 'partial'),
('claude-code', 'collaboration',       'チームコラボ',       false, 'notYet'),
-- ================================================================
-- codex
-- ================================================================
('codex', 'notes',               'ノート・メモ',       false, 'done'),
('codex', 'task_management',     'タスク管理',         false, 'done'),
('codex', 'calendar',            'カレンダー',         false, 'notYet'),
('codex', 'finance_tracking',    '家計・財務管理',     false, 'notYet'),
('codex', 'ai_assistant',        'AIアシスタント',     true,  'done'),
('codex', 'messaging',           'メッセージ・チャット',false, 'notYet'),
('codex', 'social_sharing',      'SNS・シェア',        false, 'partial'),
('codex', 'code_assistant',      'コード補助',         true,  'notYet'),
('codex', 'document_management', 'ドキュメント管理',   false, 'partial'),
('codex', 'collaboration',       'チームコラボ',       false, 'notYet'),
-- ================================================================
-- claude-cowork
-- ================================================================
('claude-cowork', 'notes',               'ノート・メモ',       true,  'done'),
('claude-cowork', 'task_management',     'タスク管理',         true,  'done'),
('claude-cowork', 'calendar',            'カレンダー',         false, 'notYet'),
('claude-cowork', 'finance_tracking',    '家計・財務管理',     false, 'notYet'),
('claude-cowork', 'ai_assistant',        'AIアシスタント',     true,  'done'),
('claude-cowork', 'messaging',           'メッセージ・チャット',true,  'notYet'),
('claude-cowork', 'social_sharing',      'SNS・シェア',        false, 'partial'),
('claude-cowork', 'code_assistant',      'コード補助',         true,  'notYet'),
('claude-cowork', 'document_management', 'ドキュメント管理',   true,  'partial'),
('claude-cowork', 'collaboration',       'チームコラボ',       true,  'notYet'),
-- ================================================================
-- openclaw
-- ================================================================
('openclaw', 'notes',               'ノート・メモ',       false, 'done'),
('openclaw', 'task_management',     'タスク管理',         false, 'done'),
('openclaw', 'calendar',            'カレンダー',         false, 'notYet'),
('openclaw', 'finance_tracking',    '家計・財務管理',     false, 'notYet'),
('openclaw', 'ai_assistant',        'AIアシスタント',     true,  'done'),
('openclaw', 'messaging',           'メッセージ・チャット',false, 'notYet'),
('openclaw', 'social_sharing',      'SNS・シェア',        false, 'partial'),
('openclaw', 'code_assistant',      'コード補助',         true,  'notYet'),
('openclaw', 'document_management', 'ドキュメント管理',   false, 'partial'),
('openclaw', 'collaboration',       'チームコラボ',       false, 'notYet'),
-- ================================================================
-- amazon
-- ================================================================
('amazon', 'notes',               'ノート・メモ',       false, 'done'),
('amazon', 'task_management',     'タスク管理',         true,  'done'),
('amazon', 'calendar',            'カレンダー',         false, 'notYet'),
('amazon', 'finance_tracking',    '家計・財務管理',     true,  'notYet'),
('amazon', 'ai_assistant',        'AIアシスタント',     true,  'done'),
('amazon', 'messaging',           'メッセージ・チャット',true,  'notYet'),
('amazon', 'social_sharing',      'SNS・シェア',        true,  'partial'),
('amazon', 'code_assistant',      'コード補助',         false, 'notYet'),
('amazon', 'document_management', 'ドキュメント管理',   false, 'partial'),
('amazon', 'collaboration',       'チームコラボ',       true,  'notYet'),
-- ================================================================
-- google
-- ================================================================
('google', 'notes',               'ノート・メモ',       true,  'done'),
('google', 'task_management',     'タスク管理',         true,  'done'),
('google', 'calendar',            'カレンダー',         true,  'notYet'),
('google', 'finance_tracking',    '家計・財務管理',     false, 'notYet'),
('google', 'ai_assistant',        'AIアシスタント',     true,  'done'),
('google', 'messaging',           'メッセージ・チャット',true,  'notYet'),
('google', 'social_sharing',      'SNS・シェア',        true,  'partial'),
('google', 'code_assistant',      'コード補助',         true,  'notYet'),
('google', 'document_management', 'ドキュメント管理',   true,  'partial'),
('google', 'collaboration',       'チームコラボ',       true,  'notYet'),
-- ================================================================
-- microsoft
-- ================================================================
('microsoft', 'notes',               'ノート・メモ',       true,  'done'),
('microsoft', 'task_management',     'タスク管理',         true,  'done'),
('microsoft', 'calendar',            'カレンダー',         true,  'notYet'),
('microsoft', 'finance_tracking',    '家計・財務管理',     true,  'notYet'),
('microsoft', 'ai_assistant',        'AIアシスタント',     true,  'done'),
('microsoft', 'messaging',           'メッセージ・チャット',true,  'notYet'),
('microsoft', 'social_sharing',      'SNS・シェア',        false, 'partial'),
('microsoft', 'code_assistant',      'コード補助',         true,  'notYet'),
('microsoft', 'document_management', 'ドキュメント管理',   true,  'partial'),
('microsoft', 'collaboration',       'チームコラボ',       true,  'notYet'),
-- ================================================================
-- github
-- ================================================================
('github', 'notes',               'ノート・メモ',       true,  'done'),
('github', 'task_management',     'タスク管理',         true,  'done'),
('github', 'calendar',            'カレンダー',         false, 'notYet'),
('github', 'finance_tracking',    '家計・財務管理',     false, 'notYet'),
('github', 'ai_assistant',        'AIアシスタント',     true,  'done'),
('github', 'messaging',           'メッセージ・チャット',true,  'notYet'),
('github', 'social_sharing',      'SNS・シェア',        true,  'partial'),
('github', 'code_assistant',      'コード補助',         true,  'notYet'),
('github', 'document_management', 'ドキュメント管理',   true,  'partial'),
('github', 'collaboration',       'チームコラボ',       true,  'notYet'),
-- ================================================================
-- jobcan
-- ================================================================
('jobcan', 'notes',               'ノート・メモ',       false, 'done'),
('jobcan', 'task_management',     'タスク管理',         true,  'done'),
('jobcan', 'calendar',            'カレンダー',         true,  'notYet'),
('jobcan', 'finance_tracking',    '家計・財務管理',     true,  'notYet'),
('jobcan', 'ai_assistant',        'AIアシスタント',     true,  'done'),
('jobcan', 'messaging',           'メッセージ・チャット',true,  'notYet'),
('jobcan', 'social_sharing',      'SNS・シェア',        false, 'partial'),
('jobcan', 'code_assistant',      'コード補助',         false, 'notYet'),
('jobcan', 'document_management', 'ドキュメント管理',   false, 'partial'),
('jobcan', 'collaboration',       'チームコラボ',       true,  'notYet'),
-- ================================================================
-- netkeiba
-- ================================================================
('netkeiba', 'notes',               'ノート・メモ',       false, 'done'),
('netkeiba', 'task_management',     'タスク管理',         false, 'done'),
('netkeiba', 'calendar',            'カレンダー',         true,  'notYet'),
('netkeiba', 'finance_tracking',    '家計・財務管理',     false, 'notYet'),
('netkeiba', 'ai_assistant',        'AIアシスタント',     false, 'done'),
('netkeiba', 'messaging',           'メッセージ・チャット',false, 'notYet'),
('netkeiba', 'social_sharing',      'SNS・シェア',        true,  'partial'),
('netkeiba', 'code_assistant',      'コード補助',         false, 'notYet'),
('netkeiba', 'document_management', 'ドキュメント管理',   false, 'partial'),
('netkeiba', 'collaboration',       'チームコラボ',       false, 'notYet'),
-- ================================================================
-- animaworks
-- ================================================================
('animaworks', 'notes',               'ノート・メモ',       false, 'done'),
('animaworks', 'task_management',     'タスク管理',         false, 'done'),
('animaworks', 'calendar',            'カレンダー',         false, 'notYet'),
('animaworks', 'finance_tracking',    '家計・財務管理',     false, 'notYet'),
('animaworks', 'ai_assistant',        'AIアシスタント',     true,  'done'),
('animaworks', 'messaging',           'メッセージ・チャット',false, 'notYet'),
('animaworks', 'social_sharing',      'SNS・シェア',        true,  'partial'),
('animaworks', 'code_assistant',      'コード補助',         false, 'notYet'),
('animaworks', 'document_management', 'ドキュメント管理',   true,  'partial'),
('animaworks', 'collaboration',       'チームコラボ',       true,  'notYet'),
-- ================================================================
-- liven
-- ================================================================
('liven', 'notes',               'ノート・メモ',       true,  'done'),
('liven', 'task_management',     'タスク管理',         true,  'done'),
('liven', 'calendar',            'カレンダー',         true,  'notYet'),
('liven', 'finance_tracking',    '家計・財務管理',     false, 'notYet'),
('liven', 'ai_assistant',        'AIアシスタント',     false, 'done'),
('liven', 'messaging',           'メッセージ・チャット',false, 'notYet'),
('liven', 'social_sharing',      'SNS・シェア',        true,  'partial'),
('liven', 'code_assistant',      'コード補助',         false, 'notYet'),
('liven', 'document_management', 'ドキュメント管理',   false, 'partial'),
('liven', 'collaboration',       'チームコラボ',       false, 'notYet')
ON CONFLICT (competitor_id, feature_key) DO UPDATE SET
  has_feature  = EXCLUDED.has_feature,
  jibun_status = EXCLUDED.jibun_status,
  updated_at   = now();

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'competitor_features seed Phase 1 (21社×10機能)',
  'PS#4 S55。21競合×10機能キー(notes/task_management/calendar/finance_tracking/ai_assistant/messaging/social_sharing/code_assistant/document_management/collaboration) を competitor_features テーブルに seed。jibun_status で自分株式会社の実装状況(done/partial/notYet)も記録。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
