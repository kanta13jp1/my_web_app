-- Session 11 (daily-development 2026-03-28): public memo share + reactions

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    '公開メモ SNS シェア OGP 強化 (public-memo-share Edge Function)',
    'SNSでの公開メモシェア時にOGPメタタグ付きHTMLを返すEdge Functionを新規作成。Twitter/LINE等でのシェアカードに実メモ内容を表示できるよう改善。buildPublicMemoUrl()をEdge Function URLに変更し、buildPublicMemoAppUrl()でアプリURLを提供。CI/CDに自動デプロイ追加。',
    '2026-03-28'
  ),
  (
    '公開メモ絵文字リアクション機能 (memo-reactions Edge Function)',
    '👍❤️🔥💡🎉の5種絵文字リアクションをログイン不要で実装。IP SHA-256ハッシュで重複防止・プライバシー保護。UNIQUE INDEX insertをtoggleオフに活用。Flutter側に_MemoReactionsBarウィジェット追加（AnimatedContainer付き）。memo_reactionsテーブル新設・RLS・CI/CD追加。',
    '2026-03-28'
  )
ON CONFLICT DO NOTHING;
