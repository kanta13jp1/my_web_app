-- PS#4 S321: 競合3社追加 834→837社 (back4app/ionic-framework/tauri)
-- SEO: "Back4App代替"/"Ionic代替"/"Tauri代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S321: 競合3社追加 834→837社 (back4app/ionic-framework/tauri)',
  'comparison_page.dartにback4app(Parse BaaSクラウドバックエンド/baas/0052CD)/ionic-framework(Web技術ハイブリッドiOS/Android/mobile/3880FF)/tauri(Rust製軽量デスクトップElectron代替/desktop/FFC131)の3社追加(834→837社)。sitemap 886 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
