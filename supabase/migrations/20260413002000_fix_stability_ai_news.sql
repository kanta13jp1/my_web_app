-- Stability AI の news カテゴリを正しいコンテンツに修復
-- (ai-university-update.yml が RSS 失敗のフォールバックで上書きしたため)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES (
  'stability',
  'news',
  'Stability AI 最新情報',
  E'## Stability AI 最新情報\n\nStability AI は Stable Diffusion シリーズの開発元。2024年に CEO 交代・再建を経て、画像/動画/音声生成 AI に注力中。\n\n### 主なリリース (2025-2026)\n- **Stable Diffusion 3.5** — テキスト生成品質大幅改善\n- **Stable Video Diffusion 2** — 高品質動画生成\n- **Stable Audio 2** — 音楽・効果音生成\n- **Stable LM 2** — 軽量LLMシリーズ\n\n> 公式サイト: https://stability.ai/',
  'https://stability.ai/news',
  '2026-04-13',
  1,
  true
)
ON CONFLICT (provider, category) DO UPDATE
  SET title      = EXCLUDED.title,
      content    = EXCLUDED.content,
      source_url = EXCLUDED.source_url,
      published_at = EXCLUDED.published_at,
      updated_at = now();
