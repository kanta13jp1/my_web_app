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
  'anthropic',
  'video_claude_code_in_action_verification_skills_20261126',
  'Claude Codeの検証スキル｜テスト弱体化まで見抜く自動検査と3層分担【実践Claude Code #3】',
  $content$# Claude Codeの検証スキル（実践Claude Code #3）

## 学習目標
「変更後のテスト実行と差分確認を毎回人間が指示する」運用をやめ、`SKILL.md`＋参照ドキュメント＋実行スクリプトによる自動検証スキルと、`CLAUDE.md` / `Skills` / `Hooks` の 3 層分担を構築できるようになる。

## ポイント
- **最初に検証スキルを作る（2 回ルール）**: 同じ複数ステップの指示を 2 回入力したらスキル化する。変更内容が `description` に合致すると自動発動し、テスト実行・diff 閲覧・**テストを通すための弱体化がないかの確認**・証拠付き報告までを一貫して行う。
- **「完了」の基準**: 差分を読んだ印象で「問題なさそう」と終えるのではなく、必要な検査ゲートを実行・観察し、その結果を根拠とともに明示して初めて完了とする。
- **スキルフォルダの構成最適化**: 長い解説は同フォルダ内の `reference.md` へ逃がして必要時だけ読ませ、検査スクリプトはコンテキストへ読み込まずに直接実行させることで、`SKILL.md` と初期コンテキストを軽量に保つ（待機中は各スキルの説明文のみが読み込まれる）。
- **3 つの指示置き場の分担とチーム共有**: 常時適用の慣習は `CLAUDE.md`、タスク特化の手順と道具は `.claude/skills/`（チーム共有）、絶対にスキップを許さない制約は実行コードである `Hooks` へ配置する。

## 練習
直近の作業で毎回確認している項目（テスト実行・型検査・差分チェック・アサーション改変有無など）を 1 セット選び、① どのトリガー `description` で発動させるか、② どのスクリプトやコマンドをゲートとして実行するか、③ どこから先を `Hooks` で強制するかをメモに整理してみてください。

## 動画と出典
- 動画：https://www.youtube.com/watch?v=84ySwJkjKQc
- 参考：Claude Academy「Verification skills」（EN / JA）
  - https://academy.claude.com/courses/claude-code-in-action/verification-skills
  - https://academy.claude.com/ja/courses/claude-code-in-action/verification-skills

公開概要を参考にした独自の日本語解説であり、公式翻訳ではありません。請求書出力改修例、図解、練習例は独自制作です。参考講座の映像・音楽は使用していません。ナレーションはAI生成音声です。$content$,
  'https://www.youtube.com/watch?v=84ySwJkjKQc',
  '2026-11-26',
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
