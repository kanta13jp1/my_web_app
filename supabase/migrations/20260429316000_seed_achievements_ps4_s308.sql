-- PS#4 S308: 競合3社追加 795→798社 (opendoor/yardi/costar)
-- SEO: "Opendoor代替"/"Yardi代替"/"CoStar代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S308: 競合3社追加 795→798社 (opendoor/yardi/costar)',
  'comparison_page.dartにopendoor(iBuying即時住宅売買/proptech/00B4A0)/yardi(不動産管理賃貸プロパティマネジメント/proptech/2D5F8A)/costar(商業不動産データ調査/proptech/003D73)の3社追加(795→798社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
