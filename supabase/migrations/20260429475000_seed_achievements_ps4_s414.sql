-- PS#4 S414: 競合3社追加 1066→1069社 (zenbusiness/incfile/clerky)
-- SEO: "ZenBusiness代替"/"Incfile代替"/"Clerky代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S414: 競合3社追加 1066→1069社 (zenbusiness/incfile/clerky)',
  'comparison_page.dartにzenbusiness(LLC設立法人設立代行コンプライアンス管理/legal/8B6FFF)/incfile(格安LLC/Corp設立法人登記代行法務テンプレート/legal/00875A)/clerky(スタートアップ向け法務書類自動化Delaware C-Corp設立/legal/2D4A8A)の3社追加(1066→1069社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
