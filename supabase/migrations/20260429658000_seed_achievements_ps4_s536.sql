-- PS#4 S536: 競合3社追加 継続 (moqups/overflow-io/stormboard)
-- SEO: "Moqups代替"/"Overflow代替"/"Stormboard代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S536: 競合3社追加 (moqups/overflow-io/stormboard)',
  'comparison_page.dartにmoqups(ブラウザUI設計・ワイヤーフレーム・モックアップ・フローチャート・チーム共有/E74C3C)/overflow-io(ユーザーフロー図・Figma/Sketch/XD連携・インタラクティブプレゼン・UXドキュメント/17C3B2)/stormboard(デジタルホワイトボード・付箋・投票・テンプレート・ビジネスミーティング効率化/2196F3)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
