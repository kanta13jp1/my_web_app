-- PS#4 S628: 競合3社追加 Gitフック/高速リンター (lefthook/biome/pylint)
-- SEO: "Lefthook代替"/"Biome代替"/"Pylint代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S628: 競合3社追加 (lefthook/biome/pylint)',
  'comparison_page.dartにlefthook(高速Gitフック・Go製・言語非依存・並行実行・YAML/FF5400)/biome(高速JS/TSリンター+フォーマッター・Rust製・ESLint/Prettier代替・Zero config/60A5FA)/pylint(Python静的解析・コードスタイル・エラー検出・複雑度分析/3776AB)の3社追加(1708社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
