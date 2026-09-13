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
  'google',
  'video_google_antigravity_command_center',
  'Google Antigravity 2.0は何ができる？AIエージェントの中央司令塔【日本語解説】',
  $content$# 学習ゴール

Google Antigravity 2.0を複数のAIエージェントを管理する中央司令塔として捉え、安全に小さな作業から活用する基本を説明できるようになります。

## この動画で学ぶこと

- Antigravity 2.0はIDEから独立したデスクトップアプリとして、複数のAIエージェントの起動、進行確認、作業分担の調整を一つの画面から行えること
- すぐに結果を受け取る同期作業だけでなく、時間のかかる処理を任せる非同期作業にも対応すること
- システムコマンド、ファイル操作、Web検索、Chrome操作を組み合わせ、調査から画面確認までを一つの作業フローにまとめられること
- SkillsやMCPサーバーを接続し、外部ツールや定型業務へエージェントの役割を拡張できること
- 大きな仕事はサブエージェントへ分割し、計画、途中経過、成果物を人が確認することで安全性を高められること

## 実践

普段繰り返している小さな作業を一つ選び、次の四点を書き出してください。

1. エージェントに任せる具体的な作業
2. 操作を許可するフォルダー、コマンド、外部サービスの範囲
3. 同期で進める部分と、非同期で任せる部分
4. 人が途中と完了時に確認する計画、差分、画面、成果物

最初の実行では権限と対象範囲を狭くし、結果を確認してから少しずつ広げます。

## 出典

- [公開動画：Google Antigravity 2.0は何ができる？AIエージェントの中央司令塔【日本語解説】](https://www.youtube.com/watch?v=4rxcDyniuNw)
- [Google Antigravity 2.0 — Overview](https://antigravity.google/docs/overview/)

本教材はGoogle Antigravity公式資料を参考に、内容を独自に要約・再構成した日本語解説です。Googleによる公式翻訳・公式教材ではありません。機能、提供状況、料金、利用条件は変更される場合があるため、最新情報は公式資料をご確認ください。$content$,
  'https://www.youtube.com/watch?v=4rxcDyniuNw',
  '2026-08-26',
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
