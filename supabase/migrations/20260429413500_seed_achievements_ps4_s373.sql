-- PS#4 S373: 競合3社追加 990→993社 (toast-pos/lightspeed/clover)
-- SEO: "Toast POS代替"/"Lightspeed代替"/"Clover代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S373: 競合3社追加 990→993社 (toast-pos/lightspeed/clover)',
  'comparison_page.dartにtoast-pos(レストラン特化POS注文管理デリバリー/pos/FF4C00)/lightspeed(小売飲食クラウドPOS在庫EC/pos/E01E5A)/clover(中小企業カスタマイズPOS決済/pos/09A85E)の3社追加(990→993社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
