-- PS#4 S60: competitor_features Phase 2 Batch 1 — productivity (24社)
-- jibun_status: done=実装済 / partial=部分実装 / notYet=未実装

INSERT INTO public.competitor_features
  (competitor_id, feature_key, feature_name_ja, has_feature, jibun_status)
VALUES
-- ================================================================
-- airtable (productivity / database + project management)
-- ================================================================
('airtable', 'notes',               'ノート・メモ',         true,  'done'),
('airtable', 'task_management',     'タスク管理',           true,  'done'),
('airtable', 'calendar',            'カレンダー',           true,  'notYet'),
('airtable', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('airtable', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('airtable', 'messaging',           'メッセージ・チャット', false, 'done'),
('airtable', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('airtable', 'code_assistant',      'コード補助',           false, 'notYet'),
('airtable', 'document_management', 'ドキュメント管理',     true,  'partial'),
('airtable', 'collaboration',       'チームコラボ',         true,  'notYet'),
-- ================================================================
-- anytype (local-first knowledge management)
-- ================================================================
('anytype', 'notes',               'ノート・メモ',         true,  'done'),
('anytype', 'task_management',     'タスク管理',           true,  'done'),
('anytype', 'calendar',            'カレンダー',           false, 'notYet'),
('anytype', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('anytype', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('anytype', 'messaging',           'メッセージ・チャット', false, 'done'),
('anytype', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('anytype', 'code_assistant',      'コード補助',           false, 'notYet'),
('anytype', 'document_management', 'ドキュメント管理',     true,  'partial'),
('anytype', 'collaboration',       'チームコラボ',         true,  'notYet'),
-- ================================================================
-- bear-app (iOS/Mac markdown notes)
-- ================================================================
('bear-app', 'notes',               'ノート・メモ',         true,  'done'),
('bear-app', 'task_management',     'タスク管理',           true,  'done'),
('bear-app', 'calendar',            'カレンダー',           false, 'notYet'),
('bear-app', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('bear-app', 'ai_assistant',        'AIアシスタント',       false, 'done'),
('bear-app', 'messaging',           'メッセージ・チャット', false, 'done'),
('bear-app', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('bear-app', 'code_assistant',      'コード補助',           false, 'notYet'),
('bear-app', 'document_management', 'ドキュメント管理',     true,  'partial'),
('bear-app', 'collaboration',       'チームコラボ',         false, 'notYet'),
-- ================================================================
-- calendly (scheduling / calendar booking)
-- ================================================================
('calendly', 'notes',               'ノート・メモ',         false, 'done'),
('calendly', 'task_management',     'タスク管理',           false, 'done'),
('calendly', 'calendar',            'カレンダー',           true,  'notYet'),
('calendly', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('calendly', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('calendly', 'messaging',           'メッセージ・チャット', false, 'done'),
('calendly', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('calendly', 'code_assistant',      'コード補助',           false, 'notYet'),
('calendly', 'document_management', 'ドキュメント管理',     false, 'partial'),
('calendly', 'collaboration',       'チームコラボ',         true,  'notYet'),
-- ================================================================
-- clickup (all-in-one project management)
-- ================================================================
('clickup', 'notes',               'ノート・メモ',         true,  'done'),
('clickup', 'task_management',     'タスク管理',           true,  'done'),
('clickup', 'calendar',            'カレンダー',           true,  'notYet'),
('clickup', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('clickup', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('clickup', 'messaging',           'メッセージ・チャット', true,  'done'),
('clickup', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('clickup', 'code_assistant',      'コード補助',           false, 'notYet'),
('clickup', 'document_management', 'ドキュメント管理',     true,  'partial'),
('clickup', 'collaboration',       'チームコラボ',         true,  'notYet'),
-- ================================================================
-- coda (collaborative doc + database)
-- ================================================================
('coda', 'notes',               'ノート・メモ',         true,  'done'),
('coda', 'task_management',     'タスク管理',           true,  'done'),
('coda', 'calendar',            'カレンダー',           true,  'notYet'),
('coda', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('coda', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('coda', 'messaging',           'メッセージ・チャット', false, 'done'),
('coda', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('coda', 'code_assistant',      'コード補助',           false, 'notYet'),
('coda', 'document_management', 'ドキュメント管理',     true,  'partial'),
('coda', 'collaboration',       'チームコラボ',         true,  'notYet'),
-- ================================================================
-- craft-docs (structured docs for Mac/iOS)
-- ================================================================
('craft-docs', 'notes',               'ノート・メモ',         true,  'done'),
('craft-docs', 'task_management',     'タスク管理',           true,  'done'),
('craft-docs', 'calendar',            'カレンダー',           false, 'notYet'),
('craft-docs', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('craft-docs', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('craft-docs', 'messaging',           'メッセージ・チャット', false, 'done'),
('craft-docs', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('craft-docs', 'code_assistant',      'コード補助',           false, 'notYet'),
('craft-docs', 'document_management', 'ドキュメント管理',     true,  'partial'),
('craft-docs', 'collaboration',       'チームコラボ',         true,  'notYet'),
-- ================================================================
-- cybozu-kintone (JP business platform)
-- ================================================================
('cybozu-kintone', 'notes',               'ノート・メモ',         true,  'done'),
('cybozu-kintone', 'task_management',     'タスク管理',           true,  'done'),
('cybozu-kintone', 'calendar',            'カレンダー',           true,  'notYet'),
('cybozu-kintone', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('cybozu-kintone', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('cybozu-kintone', 'messaging',           'メッセージ・チャット', true,  'done'),
('cybozu-kintone', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('cybozu-kintone', 'code_assistant',      'コード補助',           false, 'notYet'),
('cybozu-kintone', 'document_management', 'ドキュメント管理',     true,  'partial'),
('cybozu-kintone', 'collaboration',       'チームコラボ',         true,  'notYet'),
-- ================================================================
-- grammarly (AI writing assistant)
-- ================================================================
('grammarly', 'notes',               'ノート・メモ',         false, 'done'),
('grammarly', 'task_management',     'タスク管理',           false, 'done'),
('grammarly', 'calendar',            'カレンダー',           false, 'notYet'),
('grammarly', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('grammarly', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('grammarly', 'messaging',           'メッセージ・チャット', false, 'done'),
('grammarly', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('grammarly', 'code_assistant',      'コード補助',           false, 'notYet'),
('grammarly', 'document_management', 'ドキュメント管理',     false, 'partial'),
('grammarly', 'collaboration',       'チームコラボ',         false, 'notYet'),
-- ================================================================
-- hubspot (CRM + marketing)
-- ================================================================
('hubspot', 'notes',               'ノート・メモ',         true,  'done'),
('hubspot', 'task_management',     'タスク管理',           true,  'done'),
('hubspot', 'calendar',            'カレンダー',           true,  'notYet'),
('hubspot', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('hubspot', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('hubspot', 'messaging',           'メッセージ・チャット', true,  'done'),
('hubspot', 'social_sharing',      'SNS・シェア',          true,  'partial'),
('hubspot', 'code_assistant',      'コード補助',           false, 'notYet'),
('hubspot', 'document_management', 'ドキュメント管理',     true,  'partial'),
('hubspot', 'collaboration',       'チームコラボ',         true,  'notYet'),
-- ================================================================
-- hubspot-crm (HubSpot CRM)
-- ================================================================
('hubspot-crm', 'notes',               'ノート・メモ',         true,  'done'),
('hubspot-crm', 'task_management',     'タスク管理',           true,  'done'),
('hubspot-crm', 'calendar',            'カレンダー',           true,  'notYet'),
('hubspot-crm', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('hubspot-crm', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('hubspot-crm', 'messaging',           'メッセージ・チャット', true,  'done'),
('hubspot-crm', 'social_sharing',      'SNS・シェア',          true,  'partial'),
('hubspot-crm', 'code_assistant',      'コード補助',           false, 'notYet'),
('hubspot-crm', 'document_management', 'ドキュメント管理',     true,  'partial'),
('hubspot-crm', 'collaboration',       'チームコラボ',         true,  'notYet'),
-- ================================================================
-- linear (engineering project management)
-- ================================================================
('linear', 'notes',               'ノート・メモ',         false, 'done'),
('linear', 'task_management',     'タスク管理',           true,  'done'),
('linear', 'calendar',            'カレンダー',           true,  'notYet'),
('linear', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('linear', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('linear', 'messaging',           'メッセージ・チャット', true,  'done'),
('linear', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('linear', 'code_assistant',      'コード補助',           false, 'notYet'),
('linear', 'document_management', 'ドキュメント管理',     false, 'partial'),
('linear', 'collaboration',       'チームコラボ',         true,  'notYet'),
-- ================================================================
-- logseq (local-first outliner)
-- ================================================================
('logseq', 'notes',               'ノート・メモ',         true,  'done'),
('logseq', 'task_management',     'タスク管理',           true,  'done'),
('logseq', 'calendar',            'カレンダー',           false, 'notYet'),
('logseq', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('logseq', 'ai_assistant',        'AIアシスタント',       false, 'done'),
('logseq', 'messaging',           'メッセージ・チャット', false, 'done'),
('logseq', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('logseq', 'code_assistant',      'コード補助',           false, 'notYet'),
('logseq', 'document_management', 'ドキュメント管理',     true,  'partial'),
('logseq', 'collaboration',       'チームコラボ',         false, 'notYet'),
-- ================================================================
-- make-integromat (workflow automation)
-- ================================================================
('make-integromat', 'notes',               'ノート・メモ',         false, 'done'),
('make-integromat', 'task_management',     'タスク管理',           true,  'done'),
('make-integromat', 'calendar',            'カレンダー',           false, 'notYet'),
('make-integromat', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('make-integromat', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('make-integromat', 'messaging',           'メッセージ・チャット', true,  'done'),
('make-integromat', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('make-integromat', 'code_assistant',      'コード補助',           false, 'notYet'),
('make-integromat', 'document_management', 'ドキュメント管理',     false, 'partial'),
('make-integromat', 'collaboration',       'チームコラボ',         true,  'notYet'),
-- ================================================================
-- mem-ai (AI-powered notes)
-- ================================================================
('mem-ai', 'notes',               'ノート・メモ',         true,  'done'),
('mem-ai', 'task_management',     'タスク管理',           true,  'done'),
('mem-ai', 'calendar',            'カレンダー',           true,  'notYet'),
('mem-ai', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('mem-ai', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('mem-ai', 'messaging',           'メッセージ・チャット', false, 'done'),
('mem-ai', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('mem-ai', 'code_assistant',      'コード補助',           false, 'notYet'),
('mem-ai', 'document_management', 'ドキュメント管理',     true,  'partial'),
('mem-ai', 'collaboration',       'チームコラボ',         false, 'notYet'),
-- ================================================================
-- miro (online whiteboard / collaboration)
-- ================================================================
('miro', 'notes',               'ノート・メモ',         true,  'done'),
('miro', 'task_management',     'タスク管理',           true,  'done'),
('miro', 'calendar',            'カレンダー',           false, 'notYet'),
('miro', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('miro', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('miro', 'messaging',           'メッセージ・チャット', true,  'done'),
('miro', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('miro', 'code_assistant',      'コード補助',           false, 'notYet'),
('miro', 'document_management', 'ドキュメント管理',     true,  'partial'),
('miro', 'collaboration',       'チームコラボ',         true,  'notYet'),
-- ================================================================
-- notion-ai (Notion AI layer on top of Notion)
-- ================================================================
('notion-ai', 'notes',               'ノート・メモ',         true,  'done'),
('notion-ai', 'task_management',     'タスク管理',           true,  'done'),
('notion-ai', 'calendar',            'カレンダー',           true,  'notYet'),
('notion-ai', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('notion-ai', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('notion-ai', 'messaging',           'メッセージ・チャット', false, 'done'),
('notion-ai', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('notion-ai', 'code_assistant',      'コード補助',           true,  'notYet'),
('notion-ai', 'document_management', 'ドキュメント管理',     true,  'partial'),
('notion-ai', 'collaboration',       'チームコラボ',         true,  'notYet'),
-- ================================================================
-- obsidian (local markdown knowledge base)
-- ================================================================
('obsidian', 'notes',               'ノート・メモ',         true,  'done'),
('obsidian', 'task_management',     'タスク管理',           true,  'done'),
('obsidian', 'calendar',            'カレンダー',           true,  'notYet'),
('obsidian', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('obsidian', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('obsidian', 'messaging',           'メッセージ・チャット', false, 'done'),
('obsidian', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('obsidian', 'code_assistant',      'コード補助',           false, 'notYet'),
('obsidian', 'document_management', 'ドキュメント管理',     true,  'partial'),
('obsidian', 'collaboration',       'チームコラボ',         false, 'notYet'),
-- ================================================================
-- salesforce (CRM / enterprise cloud)
-- ================================================================
('salesforce', 'notes',               'ノート・メモ',         true,  'done'),
('salesforce', 'task_management',     'タスク管理',           true,  'done'),
('salesforce', 'calendar',            'カレンダー',           true,  'notYet'),
('salesforce', 'finance_tracking',    '家計・財務管理',       true,  'done'),
('salesforce', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('salesforce', 'messaging',           'メッセージ・チャット', true,  'done'),
('salesforce', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('salesforce', 'code_assistant',      'コード補助',           false, 'notYet'),
('salesforce', 'document_management', 'ドキュメント管理',     true,  'partial'),
('salesforce', 'collaboration',       'チームコラボ',         true,  'notYet'),
-- ================================================================
-- sansan (business card management / CRM)
-- ================================================================
('sansan', 'notes',               'ノート・メモ',         false, 'done'),
('sansan', 'task_management',     'タスク管理',           true,  'done'),
('sansan', 'calendar',            'カレンダー',           true,  'notYet'),
('sansan', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('sansan', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('sansan', 'messaging',           'メッセージ・チャット', true,  'done'),
('sansan', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('sansan', 'code_assistant',      'コード補助',           false, 'notYet'),
('sansan', 'document_management', 'ドキュメント管理',     true,  'partial'),
('sansan', 'collaboration',       'チームコラボ',         true,  'notYet'),
-- ================================================================
-- typeform (form / survey builder)
-- ================================================================
('typeform', 'notes',               'ノート・メモ',         false, 'done'),
('typeform', 'task_management',     'タスク管理',           false, 'done'),
('typeform', 'calendar',            'カレンダー',           false, 'notYet'),
('typeform', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('typeform', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('typeform', 'messaging',           'メッセージ・チャット', false, 'done'),
('typeform', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('typeform', 'code_assistant',      'コード補助',           false, 'notYet'),
('typeform', 'document_management', 'ドキュメント管理',     false, 'partial'),
('typeform', 'collaboration',       'チームコラボ',         false, 'notYet'),
-- ================================================================
-- wix (website builder)
-- ================================================================
('wix', 'notes',               'ノート・メモ',         false, 'done'),
('wix', 'task_management',     'タスク管理',           false, 'done'),
('wix', 'calendar',            'カレンダー',           false, 'notYet'),
('wix', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('wix', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('wix', 'messaging',           'メッセージ・チャット', false, 'done'),
('wix', 'social_sharing',      'SNS・シェア',          true,  'partial'),
('wix', 'code_assistant',      'コード補助',           false, 'notYet'),
('wix', 'document_management', 'ドキュメント管理',     true,  'partial'),
('wix', 'collaboration',       'チームコラボ',         false, 'notYet'),
-- ================================================================
-- wordpress (CMS / blog platform)
-- ================================================================
('wordpress', 'notes',               'ノート・メモ',         true,  'done'),
('wordpress', 'task_management',     'タスク管理',           false, 'done'),
('wordpress', 'calendar',            'カレンダー',           false, 'notYet'),
('wordpress', 'finance_tracking',    '家計・財務管理',       false, 'done'),
('wordpress', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('wordpress', 'messaging',           'メッセージ・チャット', false, 'done'),
('wordpress', 'social_sharing',      'SNS・シェア',          true,  'partial'),
('wordpress', 'code_assistant',      'コード補助',           false, 'notYet'),
('wordpress', 'document_management', 'ドキュメント管理',     true,  'partial'),
('wordpress', 'collaboration',       'チームコラボ',         false, 'notYet'),
-- ================================================================
-- zoho-crm (Zoho CRM)
-- ================================================================
('zoho-crm', 'notes',               'ノート・メモ',         true,  'done'),
('zoho-crm', 'task_management',     'タスク管理',           true,  'done'),
('zoho-crm', 'calendar',            'カレンダー',           true,  'notYet'),
('zoho-crm', 'finance_tracking',    '家計・財務管理',       true,  'done'),
('zoho-crm', 'ai_assistant',        'AIアシスタント',       true,  'done'),
('zoho-crm', 'messaging',           'メッセージ・チャット', true,  'done'),
('zoho-crm', 'social_sharing',      'SNS・シェア',          false, 'partial'),
('zoho-crm', 'code_assistant',      'コード補助',           false, 'notYet'),
('zoho-crm', 'document_management', 'ドキュメント管理',     true,  'partial'),
('zoho-crm', 'collaboration',       'チームコラボ',         true,  'notYet')
ON CONFLICT (competitor_id, feature_key) DO UPDATE SET
  has_feature     = EXCLUDED.has_feature,
  feature_name_ja = EXCLUDED.feature_name_ja,
  jibun_status    = EXCLUDED.jibun_status,
  updated_at      = now();

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'competitor_features Phase 2 Batch 1 — productivity 24社',
  'PS#4 S60。競合190社化 Phase 2: productivity カテゴリ 24社 × 10機能 = 240行 seed。airtable/anytype/bear-app/calendly/clickup/coda/craft-docs/cybozu-kintone/grammarly/hubspot/hubspot-crm/linear/logseq/make-integromat/mem-ai/miro/notion-ai/obsidian/salesforce/sansan/typeform/wix/wordpress/zoho-crm',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
