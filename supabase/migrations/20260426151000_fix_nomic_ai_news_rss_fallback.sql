-- Fix Nomic AI news content that was overwritten by a failed RSS fetch.
-- Nomic's public blog/news pages are available as HTML, but /blog/rss.xml
-- currently returns 404 and should not be shown to users as news content.

INSERT INTO public.ai_university_content (
  provider,
  category,
  title,
  content,
  source_url,
  published_at,
  sort_order,
  is_active
)
VALUES (
  'nomic_ai',
  'news',
  'Nomic AI 最新情報 (2026-04-26)',
  $$
## Nomic AI 最新情報 (2026-04-26)

### 公式ブログ確認済み

- **Nomic Layout Meets Muna**: 2026-04-08 に公開。`nomic-layout` を Muna と連携し、低リソース・オンデバイス用途向けに調整したレイアウト理解モデルの research preview を発表。PDFや図面などの構造をローカルで解析し、エージェントが引用可能な形で文書を扱えるようにする方向性。
- **BuiltWorlds 40 AI-Driven AEC Solutions**: 2026-01-27 に公開。Nomic は AEC 領域向けの domain-specific AI platform として、図面・仕様書・コード・契約書・スキャン文書を扱う実務AI基盤として評価されています。
- **Nomic Embed Multimodal**: 2025-04-02 に公開。テキスト、画像、PDF、チャートを対象にした open source multimodal embedding models を発表。RAG がテキスト抽出だけでは拾えない視覚情報やレイアウト情報を扱える点が重要です。

### AI大学での見方

Nomic AI は単なる embedding provider ではなく、PDF・図面・チャート・スクリーンショットのような「視覚的で構造を持つドキュメント」を、検索・引用・エージェント実行へ接続するインフラとして追跡します。本プロジェクトでは、NotebookLMメモ、PDF資料、スクリーンショット相談、WBS/GitHub Issues横断RAGの基盤候補として重要です。

### 更新メモ

`https://www.nomic.ai/blog/rss.xml` は現在 RSS として取得できないため、定期更新では RSS 失敗時に既存ニュースをエラー文で上書きしません。最新確認は公式ブログ/ニュース HTML を基準にします。

> 出典: https://www.nomic.ai/blog/nomic-layout-muna-on-device
> 出典: https://www.nomic.ai/news/nomic-named-one-of-builtworlds-40-ai-driven-aec-solutions
> 出典: https://www.nomic.ai/news/nomic-embed-multimodal
$$,
  'https://www.nomic.ai/blog/nomic-layout-muna-on-device',
  '2026-04-26',
  1,
  true
)
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      source_url = EXCLUDED.source_url,
      published_at = EXCLUDED.published_at,
      sort_order = EXCLUDED.sort_order,
      is_active = EXCLUDED.is_active,
      updated_at = now();
