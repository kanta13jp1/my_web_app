-- PS#4 S423: 競合3社追加 1093→1096社 (doordash/instacart/deliveroo)
-- SEO: "DoorDash代替"/"Instacart代替"/"Deliveroo代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S423: 競合3社追加 1093→1096社 (doordash/instacart/deliveroo)',
  'comparison_page.dartにdoordash(食事デリバリーDashPassWolt買収フードテック/food-delivery/FF3008)/instacart(スーパー即時配達Caper Cart AI広告/grocery-delivery/43B02A)/deliveroo(欧州アジア食事デリバリーDeliveroo Plus/food-delivery/00CCBC)の3社追加(1093→1096社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
