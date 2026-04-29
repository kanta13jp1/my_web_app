-- PS#4 S250: 競合3社追加 621→624社 (protonmail/tutanota/hey-email)
-- SEO: "Proton Mail代替"/"Tutanota代替"/"HEY Email代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S250: 競合3社追加 621→624社 (protonmail/tutanota/hey-email)',
  'comparison_page.dartにprotonmail(E2E暗号化メール/privacy-email/8B5CF6)/tutanota(ドイツ発暗号化メール/privacy-email/C62828)/hey-email(Basecamp メール再発明/email/FF2600)の3社追加(621→624社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
