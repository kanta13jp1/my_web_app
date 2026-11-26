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
  'video_claude_code_in_action_steering_20261126',
  '長時間セッションの操縦術｜Plan・/compact・巻き戻し・Worktreeを使い分ける【実践Claude Code #1】',
  $content$# 長時間セッションを操縦する（実践Claude Code #1）

## 学習目標
プランモードによる事前設計、焦点付き `/compact`、巻き戻しメニュー、`/goal`・`Loop`、および `worktree` による隔離を組み合わせ、複数ファイルにまたがる長時間セッションを破綻なく操縦できるようになる。

## ポイント
- **プランモード（事前スコープ定義）**: 1行も編集させずに調査と変更計画を作成させ、出力計画を精読して実装前に修正・反復する。
- **指示付き `/compact`**: 単独実行による重要文脈の欠落を防ぐため、`/compact 検索フィルタ改修に絞る` のように保持すべき軸を明示して圧縮する。
- **巻き戻し（空欄で `Escape × 2`）**: プロンプト毎のチェックポイントを使い、「コードと会話 / 会話のみ / コードのみ」の復元や「ここから要約」「ここまで要約」で不要文脈を切り落とす。
- **自律実行（`/goal` と `Loop`）**: `/goal` の評価器は会話ログのみを参照するため、テスト合格や型エラー0件など出力結果で判定できる条件を指定する（解除は `/goal clear`）。CI・デプロイ待機は `Loop` を使い、自己ペース待機中の停止は `Escape`、固定間隔はキャンセル指示または7日経過で終了する。
- **Worktrees（並行分離）**: `claude --worktree <名前>` でセッション毎に独立したファイルツリーを割り当て、`.worktreeinclude` に Git 管理外の環境設定を記載して引き継ぐ（クリーンな状態での終了時は自動削除、名前付きセッションは削除前に確認が入る）。

## 練習
自分が直近で取り組む予定の「複数ファイル改修」を1つ選び、① プランモードで最初に確認したい影響範囲、② 途中で `/compact` に添える焦点指示、③ `/goal` に書く「テストや型検査の出力から判定できる完了条件」の3点をメモに書き出してみてください。

## 動画と出典
- 動画：https://www.youtube.com/watch?v=ueOtNf4gMdU
- 参考：Claude Academy「Steering long sessions」（EN / JA）
  - https://academy.claude.com/courses/claude-code-in-action/steering-long-sessions
  - https://academy.claude.com/ja/courses/claude-code-in-action/steering-long-sessions

公開概要を参考にした独自の日本語解説であり、公式翻訳ではありません。検索フィルタ改修例、図解、練習例は独自制作です。参考講座の映像・音楽は使用していません。ナレーションはAI生成音声です。$content$,
  'https://www.youtube.com/watch?v=ueOtNf4gMdU',
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
