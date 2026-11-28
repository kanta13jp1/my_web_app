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
  'video_claude_code_in_action_permission_modes_20261126',
  'Claude Codeのパーミッションモード｜6種の権限とAuto＋Stopフックの安全な使い分け【実践Claude Code #4】',
  $content$# Claude Codeのパーミッションモード（実践Claude Code #4）

## 学習目標
6 種類のパーミッションモードの境界線を理解し、日常の `Shift+Tab` 運用・`Auto` モードと `Stop` フックの二段ガード・無人環境向け `--permission-mode dontAsk` を安全に使い分けられるようになる。

## ポイント
- **6 つのモードと `Shift+Tab` 切替**: 日常利用の `Manual`（読取のみ）・`Accept edits`（編集・FS 系コマンド無確認）・`Plan`（無編集調査＋Auto 利用時は探索審査）・`Auto`（分類器審査付き自動実行）を `Shift+Tab` で循環し、ステータスバーで確認する。
- **`Auto` 分類器の役割と限界**: 別モデルの分類器が実行前に「意図のエスカレート（本番反映・強制プッシュ・機密外部送信・既存ファイル破壊・デプロイ先ブランチへのプッシュ等）」をブロックする一方、コードの正しさは判定しない。必ずテストを実行する **`Stop` フック** と併用し、「事前＝意図 / 事後＝正しさ」を二段で守る。
- **無人パイプラインの `Don't ask`**: `Shift+Tab` には含まれないため `claude --permission-mode dontAsk` で明示起動する。作業ディレクトリ内読取と事前承認済みツールのみ許可し、その他は自動拒否して承認待ちハングを防ぐ。
- **隔離環境限定の `Bypass permissions`**: ごく一部の例外を除く権限確認をスキップするため、隔離されたコンテナまたは仮想マシン（VM）内でのみ利用する。最新のブロック/許可一覧は公式ドキュメントを随時参照する。

## 練習
手元のプロジェクトや CI 用途を 1 つ思い浮かべ、① 対話開発で `Auto` に任せる範囲、② 実行後に自動検証させる `Stop` フックのコマンド、③ 無人バッチで `dontAsk` に事前許可する最小ツール一覧の 3 点をメモに整理してみてください。

## 動画と出典
- 動画：https://www.youtube.com/watch?v=0KblBiUH3h8
- 参考：Claude Academy「Permission modes」（EN / JA）
  - https://academy.claude.com/courses/claude-code-in-action/permission-modes
  - https://academy.claude.com/ja/courses/claude-code-in-action/permission-modes

公開概要を参考にした独自の日本語解説であり、公式翻訳ではありません。決済計算改修例、図解、練習例は独自制作です。参考講座の映像・音楽は使用していません。ナレーションはAI生成音声です。$content$,
  'https://www.youtube.com/watch?v=0KblBiUH3h8',
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
