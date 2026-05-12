-- PS#4 S97: カテゴリ対応「他の比較ページも見る」セクション
-- 同カテゴリ競合を優先表示し、関連性を向上

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S97: _relatedCompetitorsカテゴリ対応 (174社→15カテゴリ分類)',
  'comparison_page.dartに_categoryOf静的マップ(15カテゴリ/174社対応)を追加。_relatedCompetitorsゲッターを同カテゴリ優先に改修: 1)同カテゴリ最大3社→2)featured10社→3)その他で6社埋め。notes/chat/ai-dev/ai-platform/finance/hr/project/design/video-ai/learning/ecommerce/automation/entertainment/crm/social/dev/cloud/health/transport/japan-svc/b2bの21グループ。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
