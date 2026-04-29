-- PS#4 S364: 競合3社追加 963→966社 (balsamiq/proofhub/nifty)
-- SEO: "Balsamiq代替"/"ProofHub代替"/"Nifty代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S364: 競合3社追加 963→966社 (balsamiq/proofhub/nifty)',
  'comparison_page.dartにbalsamiq(ローファイワイヤフレームUI設計スケッチ/wireframe/CC2900)/proofhub(オールインワンPM・ガントチャート/project-mgmt/F25628)/nifty(マイルストーン連動PM・スプリント/project-mgmt/5469D4)の3社追加(963→966社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
