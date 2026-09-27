-- Add the September revision without replacing the existing September 1 lesson.
INSERT INTO public.ai_university_content
  (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES (
  'anthropic',
  'video_claude_code_101_installing_claude_code_20260921',
  'Claude Codeをインストールする方法｜ターミナル・IDE・Desktop・Web｜Claude Code 101 #3【日本語解説】',
  $lesson$# 学習ゴール

Claude Codeの利用環境を選び、インストール後の確認と安全な作業開始の流れを説明できるようになります。

## この動画で学べること

- ターミナル・IDE・Desktop・Webという入口の違いと、自分の作業に合う選び方
- OSに対応した公式の導入手順を確認し、インストール方法による更新方法の違いに注意すること
- `claude --version` や `claude doctor` による導入後の確認
- 対象プロジェクトのフォルダーから開始し、アクセス範囲は権限・設定にも依存すること
- AIの変更差分とテスト結果を人が確認する習慣

## 実践してみよう

1. 自分のOSと普段の編集環境を書き出し、使いたい入口を一つ選びます。
2. 下記の公式セットアップ文書で最新の前提条件・導入方法を確認します。
3. 導入後は小さな練習用プロジェクトを開き、バージョンと診断結果を確認します。
4. 機密情報を含まない範囲で質問し、操作権限と変更差分を確認します。

## 出典・注記

- 2026年9月版。旧教材を削除せず、新しい図解・字幕の動画として追加しています。
- [Claude Academy: Installing Claude Code](https://academy.claude.com/ja/courses/claude-code-101/installing-claude-code)
- [公式セットアップ文書](https://code.claude.com/docs/en/setup)
- 公式教材を参考にした独自の要約・解説であり、公式翻訳ではありません。参考動画の自動字幕は補助的に使用しています。仕様確認日：2026年9月21日。
- 動画の画面は説明用の図解です。実際のインストーラー操作を録画したものではありません。$lesson$,
  'https://www.youtube.com/watch?v=ZZeIR1xZYg4',
  '2026-09-21',
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
