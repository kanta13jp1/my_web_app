-- AI大学: YouTube 公開動画を埋め込み学習コンテンツとして登録する。

INSERT INTO ai_university_content (
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
  'openai',
  'video_codex_custom_code_review_rules',
  'Codexのカスタムコードレビュー規則｜AGENTS.mdで暗黙知を自動レビューへ',
  $content$## 学習ゴール

Codex Code Reviewのカスタム規則を使い、チーム内にある重要な暗黙知を、再現可能でノイズの少ないレビュー基準としてAGENTS.mdへ整理できるようになります。

## 学べること

1. 互換性や顧客データ境界など、壊した場合の影響が大きく、経験者が繰り返し説明している不変条件を優先して規則化します。
2. リポジトリ全体の規則はルートのAGENTS.mdへ、特定サービスだけの規則は対象ディレクトリ内のAGENTS.mdへ配置します。
3. 規則には「何を守るか」だけでなく、互換性を維持する代替案など、安全な修正経路も記載します。
4. 書式や静的解析のような決定的な検査はCIへ残し、判断を伴う互換性・データ境界の確認をCodexのレビュー規則へ分けます。
5. 違反する変更、安全な例外、無関係な変更の三種類で試し、必要な指摘を保ちながら誤検知を減らします。

## 実践課題

自分のリポジトリで、熟練レビュー担当者が過去に二回以上説明した注意点を一つ選んでください。その注意点について、対象範囲、守るべき不変条件、安全な修正方法、適用しない例外を短い規則としてAGENTS.mdへ書き、違反例・安全な例外・無関係な変更で結果を比較します。

## 出典

- 参考記事: [Custom Code Review rules for Codex](https://learn.chatgpt.com/blog/custom-code-review-rules-for-codex)
- 公開動画: [Codexのカスタムコードレビュー規則｜AGENTS.mdで暗黙知を自動レビューへ](https://www.youtube.com/watch?v=rmaPMyKYZXQ)

本教材は参考記事を基に独自に構成した日本語の要約・解説であり、OpenAIによる公式翻訳ではありません。$content$,
  'https://www.youtube.com/watch?v=rmaPMyKYZXQ',
  '2026-08-14',
  0,
  true
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  source_url = EXCLUDED.source_url,
  published_at = EXCLUDED.published_at,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active;
