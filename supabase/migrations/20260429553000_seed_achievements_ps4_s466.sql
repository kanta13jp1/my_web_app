-- PS#4 S466: 競合3社追加 1219→1222社 (matomo/moz/screaming-frog)
-- SEO: "Matomo代替"/"Moz代替"/"Screaming Frog代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S466: 競合3社追加 1219→1222社 (matomo/moz/screaming-frog)',
  'comparison_page.dartにmatomo(OSS分析クッキーフリーGDPR自己ホスト/3152A0)/moz(DA/PA発明者Moz Proキーワード調査リンク分析/0078D4)/screaming-frog(SEO Spider壊れたリンク技術SEO監査/7ED321)の3社追加(1219→1222社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
