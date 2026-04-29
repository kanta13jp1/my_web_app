-- PS#4 S474: 競合3社追加 1243→1246社 (garageband/logic-pro/pro-tools)
-- SEO: "GarageBand代替"/"Logic Pro代替"/"Pro Tools代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S474: 競合3社追加 1243→1246社 (garageband/logic-pro/pro-tools)',
  'comparison_page.dartにgarageband(Apple無料DAW MIDI Drummer Live Loops/555555)/logic-pro(Appleプロ向けDAW 200GB+サウンド空間オーディオStem Splitter/1B1B1B)/pro-tools(Avid業界標準128トラックHDX DSP/333333)の3社追加(1243→1246社)。sitemap 1345 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
