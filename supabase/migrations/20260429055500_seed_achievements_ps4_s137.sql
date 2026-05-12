-- PS#4 S137: 競合3社追加 282→285社 (gimp/krita/inkscape)
-- SEO: "GIMP代替"/"Krita代替"/"Inkscape代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S137: 競合3社追加 282→285社 (gimp/krita/inkscape)',
  'comparison_page.dartにgimp(無料OSS画像編集/design/918A6E)/krita(OSSデジタルペインティング/design/3DAEE9)/inkscape(無料OSSベクター編集/design/000000)の3社追加(282→285社)。全ファイル285統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
