-- PS#4 S537: 競合3社追加 1431→1440社 (marvel-app/principle-app/origami-studio)
-- SEO: "Marvel App代替"/"Principle代替"/"Origami Studio代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S537: 競合3社追加 1431→1440社 (marvel-app/principle-app/origami-studio)',
  'comparison_page.dartにmarvel-app(シンプルプロトタイピング・ユーザーテスト・ハンドオフ・Sketch/Figma取込/FF4D5B)/principle-app(macOS高精度アニメーション・タイムライン・ドライバー・Sketch/Figma連携/007AFF)/origami-studio(Meta製無料・Patchエディタ・React Native出力・高精度インタラクション/F25B2A)の3社追加(1431→1440社)。sitemap 1534 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
