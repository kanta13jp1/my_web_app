-- PS#4 S132: 競合3社追加 267→270社 (lastpass/bitwarden/premiere-pro)
-- SEO: "LastPass代替"/"Bitwarden代替"/"Premiere Pro代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S132: 競合3社追加 267→270社 (lastpass/bitwarden/premiere-pro)',
  'comparison_page.dartにlastpass(パスワード管理・データ漏洩リスク/security/CC0000)/bitwarden(OSSパスワード管理/security/175DDC)/premiere-pro(Adobe動画編集/video-editing/9999FF)の3社追加(267→270社)。sitemap319URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
