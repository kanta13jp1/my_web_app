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
  'video_google_antigravity_2_overview',
  'Google Antigravity 2.0とは？AIエージェントの4つの使い方【日本語解説】',
  $content$# 学習ゴール

Google Antigravityの4つの利用形態を理解し、Project・Worktree・権限設定を使ってAIエージェントへ安全に作業を任せる基本を説明できるようになります。

## この動画で学ぶこと

- Antigravity 2.0は、複数のAIエージェントを起動・監視・調整するデスクトップ版の司令塔として使えること
- Antigravity CLIは、ターミナルやSSH環境で素早く操作したい場面に向き、Antigravity SDKはPythonから独自ツールや処理フローを組み込みたい場面に向くこと
- Antigravity for IDEsは、エディター内のコードや変更差分を確認しながら日常の開発作業を進めたい場面に向くこと
- Projectに対象フォルダー、設定、権限をまとめ、Git Worktreeで作業場所を分離すると、複数の作業を安全に並行しやすくなること
- AIエージェントの成果はそのまま採用せず、実行計画、コード差分、画面記録などの成果物を人が確認してから反映すること

## 実践

自分が繰り返している小さな開発作業を一つ選び、次の項目を短く書き出してください。

1. AIエージェントに任せる作業と、変更を許可するフォルダー
2. Desktop、CLI、SDK、IDEのうち、その作業に最も合う利用形態と理由
3. Worktreeを使って分離すべきかどうか
4. 実行前に承認する操作と、完了後に人が確認する成果物

最後に「どの条件を満たしたら本番へ反映してよいか」を一文で決めます。

## 出典

- [公開動画：Google Antigravity 2.0とは？AIエージェントの4つの使い方【日本語解説】](https://www.youtube.com/watch?v=pKfb0oox3_8)
- [Google Antigravity Docs — Home](https://antigravity.google/docs/home/)
- [Google Antigravity Docs — Overview](https://antigravity.google/docs/overview/)
- [Google Antigravity Docs — Feature overview](https://antigravity.google/docs/features/)

本教材はGoogle Antigravity公式ドキュメントを参考に、公開動画の内容を独自に要約・再構成した日本語解説です。Googleによる公式翻訳・公式教材ではありません。機能、提供状況、料金、利用条件は変更される場合があるため、最新情報は公式資料をご確認ください。$content$,
  'https://www.youtube.com/watch?v=pKfb0oox3_8',
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
