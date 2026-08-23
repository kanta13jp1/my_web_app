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
  'video_codex_customer_demo',
  'Codexで顧客課題を形にする｜レビュー分析から試作まで【日本語解説】',
  $content$## 学習ゴール

Codexを使って顧客の声を課題へ整理し、具体的な試作品と再利用可能なスキルへつなげる流れを理解します。

## この動画で学べること

- 顧客レビューから繰り返される不満・要望を抽出する
- 分析結果を説明資料ではなく、触れられる試作品に変える
- 顧客固有の課題を使ってAIの価値を自分ごと化する
- 成功した調査・分析・試作・確認の流れをCodexスキルとして保存する

## 視聴後の実践

1. 架空または公開サービスのレビューを5件選ぶ
2. 共通する課題を3つにまとめる
3. 最優先の課題を改善する画面案を1つ作る
4. 調査から確認までの手順を再利用チェックリストにする

参考: [OpenAI公式動画](https://www.youtube.com/watch?v=08hgAtg-P_8)

※この教材動画は公式動画の逐語翻訳ではなく、公開内容を参考に独自構成した日本語の要約・解説です。公式字幕が提供されていないため、自動生成字幕を調査用に使用しています。$content$,
  'https://www.youtube.com/watch?v=SEWi2zKhIN8',
  '2026-08-13',
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
