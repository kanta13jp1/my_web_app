-- PS#4 S424: 競合3社追加 1096→1099社 (navan/tripadvisor/expedia)
-- SEO: "Navan代替"/"Tripadvisor代替"/"Expedia代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S424: 競合3社追加 1096→1099社 (navan/tripadvisor/expedia)',
  'comparison_page.dartにnavan(企業出張管理経費出張ポリシー自動化/travel-mgmt/0C27FE)/tripadvisor(旅行レビューホテル比較観光スポット発見/travel/34E0A1)/expedia(ホテルフライトレンタカーパッケージ旅行予約/ota/1B3C87)の3社追加(1096→1099社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
