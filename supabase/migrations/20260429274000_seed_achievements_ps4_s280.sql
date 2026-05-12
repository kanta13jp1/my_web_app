-- PS#4 S280: 競合3社追加 711→714社 (plane-so/teamwork/talent-lms)
-- SEO: "Plane代替"/"Teamwork代替"/"TalentLMS代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S280: 競合3社追加 711→714社 (plane-so/teamwork/talent-lms)',
  'comparison_page.dartにplane-so(OSS Jira代替プロジェクト管理/project/3E63DD)/teamwork(クライアントワーク特化PM/project/01B8EF)/talent-lms(中小企業向けクラウドLMS/education/11A9E2)の3社追加(711→714社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
