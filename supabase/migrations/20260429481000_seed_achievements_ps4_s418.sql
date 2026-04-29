-- PS#4 S418: 競合3社追加 1078→1081社 (hostaway/lodgify/teladoc)
-- SEO: "Hostaway代替"/"Lodgify代替"/"Teladoc代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S418: 競合3社追加 1078→1081社 (hostaway/lodgify/teladoc)',
  'comparison_page.dartにhostaway(Airbnb/Vrbo短期賃貸管理自動化チャンネルマネージャー/str-mgmt/26A17B)/lodgify(民泊向けウェブサイトビルダー予約システムチャンネル管理/str-mgmt/36B37E)/teladoc(バーチャル医療遠隔診療メンタルヘルスケア/telehealth/00A3E0)の3社追加(1078→1081社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
