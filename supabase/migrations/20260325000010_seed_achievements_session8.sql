-- ============================================================
-- Session 8 開発実績シード (2026-03-25)
-- ランディングページ強化・CI/CD Edge Function 追加
-- ============================================================

insert into public.development_achievements
  (title, description, category, achieved_at, impact_level)
values
  (
    'ランディングページに価格比較セクションを追加',
    '競合6社（Notion/Evernote/MoneyForward/Slack/Chatwork/ジョブカン）との月額料金を比較表示。「他社は有料、自分株式会社は完全無料」を訴求するコンバージョン強化施策。',
    'marketing',
    '2026-03-25',
    'high'
  ),
  (
    'ランディングページに3ステップ導入ガイドを追加',
    '「無料トライアル→登録して保存→既存データ移行」の3ステップをビジュアルで表示。登録ボタンを常時表示してCTA強化。',
    'marketing',
    '2026-03-25',
    'medium'
  ),
  (
    'CI/CD に growth-import-preview / growth-import-commit を追加',
    'deploy-prod.yml に2つのEdge Functionデプロイステップを追加。NotionCSV・EvernoteENEXインポートのバックエンド処理が自動デプロイされるように修正。',
    'infrastructure',
    '2026-03-25',
    'medium'
  );
