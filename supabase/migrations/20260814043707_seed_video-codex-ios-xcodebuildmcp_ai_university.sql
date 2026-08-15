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
  'video_codex_ios_xcodebuildmcp',
  'CodexでiOSアプリをビルド・テストする方法【日本語解説】',
  $content$## 学習ゴール

CodexとXcodeBuildMCPを組み合わせ、SwiftUI／iOSアプリの実装からビルド、テスト、シミュレータ確認までを一貫して進める基本の流れを理解します。

## 学習ポイント

1. Codexでプロジェクトを開いたら、最初に対象スキームと使用するシミュレータを確認します。
2. XcodeBuildMCPを使うと、Codexの作業フローからビルドとテストを実行し、結果を次の修正へつなげられます。
3. 修正後はアプリをシミュレータで起動し、画面表示と操作結果まで確認します。
4. 変更を小さく分け、変更ごとにビルドとテストを繰り返すことで、不具合の原因を特定しやすくできます。

## 実践

手元のSwiftUIプロジェクトで小さな表示変更を一つ選び、対象スキームの確認、ビルド、テスト、シミュレータ起動、画面確認の順に実行して結果を記録してください。

## 参考・出典

- 参考動画: [Build and test iOS apps without leaving Codex](https://www.youtube.com/watch?v=u9zLlcsCDiQ)（OpenAI）
- 学習動画: [CodexでiOSアプリをビルド・テストする方法【日本語解説】](https://www.youtube.com/watch?v=--J3_miAmGU)

本教材と学習動画は、参考動画をもとに制作した独自の要約・解説であり、OpenAIによる公式翻訳ではありません。$content$,
  'https://www.youtube.com/watch?v=--J3_miAmGU',
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
