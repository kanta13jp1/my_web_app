-- PS#4 S425: 競合3社追加 1099→1102社 (booking-com/airbnb/hopper)
-- SEO: "Booking.com代替"/"Airbnb代替"/"Hopper代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S425: 競合3社追加 1099→1102社 (booking-com/airbnb/hopper)',
  'comparison_page.dartにbooking-com(世界最大ホテル宿泊予約Genius割引/ota/003580)/airbnb(民泊体験予約ホストコミュニティ旅行体験/travel/FF5A5F)/hopper(AIフライト価格予測ホテルレンタカー最安値/travel/800080)の3社追加(1099→1102社)。sitemap 1192 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
