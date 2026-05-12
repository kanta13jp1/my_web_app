-- PS#4 S279: 競合3社追加 708→711社 (feishu/dingtalk/height-app)
-- SEO: "Feishu代替"/"DingTalk代替"/"Height代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S279: 競合3社追加 708→711社 (feishu/dingtalk/height-app)',
  'comparison_page.dartにfeishu(ByteDance統合コラボLark/collab/1456F0)/dingtalk(Alibaba中国企業向けコミュニケーション/collab/1677FF)/height-app(AI統合プロジェクト管理/project/6C5CE7)の3社追加(708→711社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
