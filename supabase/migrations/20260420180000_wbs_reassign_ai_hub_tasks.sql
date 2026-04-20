-- WBS 残 'ALL' タスク追加 reassign — ai-hub / provider.chat 系 (Win版#131 part 19)

-- 本番 UI で 'ALL' 残存していた ai-hub 系を Win に集約 (アーキテクチャ判断は Win 担当)
UPDATE wbs_tasks SET instance = 'win', owner_instance = 'win'
  WHERE instance = 'all' AND (
    title LIKE '%ai-hub%' OR
    title LIKE '%provider.chat%' OR
    title LIKE '%provider chat%' OR
    title LIKE '%プロバイダー%' OR
    title LIKE '%マルチモーダルAI%' OR
    title LIKE '%画像生成統合%' OR
    title LIKE '%課金機能%' OR
    title LIKE '%Stripe%'
  );

-- AIアシスタント Opus/Sonnet 系 → win
UPDATE wbs_tasks SET instance = 'win', owner_instance = 'win'
  WHERE instance = 'all' AND (
    title LIKE '%AIアシスタント%' OR
    title LIKE '%Opus%' OR
    title LIKE '%Sonnet%' OR
    title LIKE '%Haiku%'
  );

-- 残った 'all' は ユーザー数達成 (50/500/5000) のみ — 全 instance 共同責任なので OK
-- (UI で red 'ALL' chip 表示 → 全員注目)

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  $md$WBS 残 ALL タスク追加 reassign (ai-hub/provider.chat/AIアシスタント)$md$,
  $md$本番 UI で 'ALL' 残存していた ai-hub provider.chat 全対応 / 画像系3社 / 残65社段階実装 / マルチモーダルAI / 画像生成統合 / 課金機能 / AIアシスタント Opus/Sonnet 等を Win に集約。残 ALL = ユーザー数達成のみ (全 instance 共同責任)。Win版#131 part 19。$md$,
  '2026-04-20'
)
ON CONFLICT DO NOTHING;
