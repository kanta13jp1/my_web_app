-- PS#4 S393: 競合3社追加 1003→1006社 (walkme/chameleon/userguiding)
-- SEO: "WalkMe代替"/"Chameleon代替"/"UserGuiding代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S393: 競合3社追加 1003→1006社 (walkme/chameleon/userguiding)',
  'comparison_page.dartにwalkme(デジタルアダプションプラットフォームアプリ内ガイダンスDAP/dap/008EAA)/chameleon(プロダクトツアーオンボーディングインアプリサーベイ/product-adoption/FF5722)/userguiding(ノーコードユーザーオンボーディングプロダクトツアー/product-adoption/7C4DFF)の3社追加(1003→1006社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
