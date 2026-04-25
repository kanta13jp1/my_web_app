-- Fix Arcee AI news content that was overwritten by a failed RSS fetch.
-- Arcee's public blog is available as HTML, but /blog/rss.xml currently does not
-- return a usable feed for the AI University updater.

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
  'arcee_ai',
  'news',
  'Arcee AI Trinity 最新情報 (2026-04-26)',
  $$
## Arcee AI Trinity 最新情報 (2026-04-26)

### 公式ブログ確認済み

- **Trinity Builders Program**: 2026-04-14 に公開。Trinity モデルで開発・研究・OSS を進めるビルダー向けに、Arcee API の無料推論クレジットを提供するコミュニティ助成プログラム。
- **Trinity-Large-Thinking**: 2026-04-01 に公開。複雑な長期エージェント、多段ツール呼び出し、推論用途に向けた open-weight reasoning model。Arcee API と Hugging Face で提供され、Apache 2.0 ライセンスで利用可能。
- **Trinity Manifesto**: 2025-12-01 に公開。Trinity Nano / Mini から始まる、米国で end-to-end に学習された open-weight MoE モデルファミリーの方針を説明。

### AI大学での見方

Arcee AI Trinity は「企業や開発者が重みを所有し、検証し、自己ホストや追加学習を行える open-weight モデル」という位置づけです。AI大学では、OpenAI 互換 API だけでなく、Hugging Face での重み公開、Apache 2.0、エージェント用途でのコスト効率を重点的に追跡します。

### 更新メモ

`https://www.arcee.ai/blog/rss.xml` は現在 RSS として取得できないため、定期更新では RSS 失敗時に既存ニュースをエラー文で上書きしないようにしました。最新確認は公式ブログ HTML を基準にします。

> 出典: https://www.arcee.ai/blog
> Trinity Builders Program: https://www.arcee.ai/blog/introducing-the-trinity-builders-program
> Trinity-Large-Thinking: https://www.arcee.ai/blog/trinity-large-thinking
$$,
  'https://www.arcee.ai/blog',
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
