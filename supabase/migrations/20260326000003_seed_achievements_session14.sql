-- ============================================================
-- Session 14 開発実績シード (2026-03-26)
-- LP ソーシャルプルーフ強化・移行ガイドセクション追加
-- ============================================================

insert into public.development_achievements
  (title, description, category, achieved_at, impact_level)
values
  (
    'LP: リアルタイム実績カードを追加',
    'ランディングページに _buildSocialProofStatsSection() を新規追加。登録ユーザー数・公開メモ数・実装済み機能数をリアルタイムで取得してLIVEバッジ付きで表示。Supabase から countクエリで実データを取得。',
    'marketing',
    '2026-03-26',
    'high'
  ),
  (
    'LP: Notion/Evernote 移行ガイドセクションを追加',
    'ランディングページに _buildMigrationGuideSection() を新規追加。NotionとEvernoteからの3ステップ移行手順を番号付きで可視化。インポート画面への直接CTAボタン付き。移行障壁を下げてコンバージョン向上を狙う。',
    'marketing',
    '2026-03-26',
    'high'
  );
