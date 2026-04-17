-- daily-development: 2026-04-17 — FSRS UI + blog_corrections RLS fix
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 FSRS復習カウンター — ホームカード統合',
    'ai_university_home_card.dart に FSRS due card 数をリアルタイム表示。Supabase直クエリ（RLS保護済み）で今日の復習カード数を取得し、> 0 の場合にバッジと「復習する」ボタンを表示。スペース反復学習のリテンション向上に直結。',
    '2026-04-17'
  ),
  (
    'blog_corrections RLS バグ修正 — user_id カラム誤用',
    '20260417130000_create_blog_corrections.sql の admin RLS ポリシーで user_profiles.id を使用していたバグを user_profiles.user_id に修正。管理者がブログ修正提案を承認できない問題を解消。',
    '2026-04-17'
  )
ON CONFLICT DO NOTHING;
