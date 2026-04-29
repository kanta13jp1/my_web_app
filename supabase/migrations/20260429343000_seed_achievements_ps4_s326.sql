-- PS#4 S326: 競合3社追加 849→852社 (novu/knock-app/courier)
-- SEO: "Novu代替"/"Knock代替"/"Courier代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S326: 競合3社追加 849→852社 (novu/knock-app/courier)',
  'comparison_page.dartにnovu(OSS通知インフラマルチチャネル/notification/7B61FF)/knock-app(エンタープライズ通知インフラAPI/notification/E84C89)/courier(マルチチャネル通知APIデザイナー/notification/9F55FF)の3社追加(849→852社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
