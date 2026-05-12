-- PS#4 S213: 競合3社追加 510→513社 (docebo/talentlms/absorb-lms)
-- SEO: "Docebo代替"/"TalentLMS代替"/"Absorb LMS代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S213: 競合3社追加 510→513社 (docebo/talentlms/absorb-lms)',
  'comparison_page.dartにdocebo(AI-LMS/lms/43A8E8)/talentlms(シンプルLMS/lms/407BFF)/absorb-lms(直感UI-LMS/lms/5B21B6)の3社追加(510→513社)。sitemap 562 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
