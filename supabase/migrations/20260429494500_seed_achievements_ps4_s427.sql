-- PS#4 S427: 競合3社追加 1105→1108社 (zomato/swiggy/grab)
-- SEO: "Zomato代替"/"Swiggy代替"/"Grab代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S427: 競合3社追加 1105→1108社 (zomato/swiggy/grab)',
  'comparison_page.dartにzomato(インドフードデリバリーレストラン発見Blinkit食料品Zomato Gold/food-delivery/E23744)/swiggy(インドフードデリバリーInstamart即時食料品Dineout予約/food-delivery/FC8019)/grab(東南アジアスーパーアプリ配車フードデリバリーGrabPayフィンテック/superapp/00B14F)の3社追加(1105→1108社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
