-- AI大学: 公開済みの Codex Record & Replay 日本語解説動画を教材化する。
-- source_url が YouTube の場合、Flutter Web UI は教材カード内に動画を埋め込む。

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
  'video_codex_record_replay',
  'Codex Record & Replay｜一度見せれば、次から任せられる【日本語解説】',
  $content$## 学習ゴール

Codex の **Record & Replay** を使い、一度実演した定型作業を再利用可能なスキルとして保存・実行する流れを理解します。

## この動画で学べること

- 作業の記録を開始・終了する基本操作
- 記録した手順や好みをスキルとして再利用する考え方
- 動画公開、プルリクエスト、カレンダー設定などの定型作業への応用
- 自動化後も人が内容と公開範囲を確認する運用

## 視聴後の実践

1. 繰り返している小さな作業を1つ選ぶ
2. Codex に最初の手順を見せる
3. 保存されたスキルを確認する
4. 次回の実行結果を検証し、必要なら手順を改善する

参考: [OpenAI公式動画](https://www.youtube.com/watch?v=ZK3JhU73W18)

※この教材動画は公式動画の逐語翻訳ではなく、内容をもとに独自構成した日本語要約・解説です。$content$,
  'https://www.youtube.com/watch?v=-ZxiEPqxKRY',
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
