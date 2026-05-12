-- PS#4 S133: 競合3社追加 270→273社 (final-cut-pro/google-analytics/microsoft-clarity)
-- SEO: "Final Cut Pro代替"/"Google Analytics代替"/"Microsoft Clarity代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S133: 競合3社追加 270→273社 (final-cut-pro/google-analytics/microsoft-clarity)',
  'comparison_page.dartにfinal-cut-pro(Mac専用動画編集/video-editing/2D2D2D)/google-analytics(Webアクセス解析/analytics/E37400)/microsoft-clarity(ヒートマップUX分析/analytics/0078D7)の3社追加(270→273社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
