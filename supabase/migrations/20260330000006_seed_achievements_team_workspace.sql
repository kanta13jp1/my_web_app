-- Session: daily-development 2026-03-30 #3
-- チームワークスペース実装・比較ページOGP対応・flutter analyze修正

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'チームワークスペース基盤実装',
    'teams / team_memberships / team_shared_notes テーブルをRLS付きで新設。招待コード方式でメンバー招待が可能なチーム共有機能を実装。TeamWorkspacePage（タブ構成・作成・参加・退出・削除）、/team-workspace ルート追加、業務メニューカタログに追加。B2Bエンタープライズ対応の第一歩として中期ロードマップのTeam workspace基盤を構築。',
    '2026-03-30'
  ),
  (
    '比較ページ個別OGPメタタグ対応',
    '14社の競合比較ページ（/vs-notion 〜 /vs-amazon）に対してそれぞれ固有の og:title / og:description / twitter:title / twitter:description を設定するJSを index.html SEOシェルに追加。SNSシェア時のカードがより訴求力の高い内容になり、比較キーワードからの有機流入改善を狙う。sitemap.xml に /team-workspace を追加（合計24URL）。',
    '2026-03-30'
  ),
  (
    'local_election_share_service.dart flutter analyze 修正',
    'require_trailing_commas エラー2件（line 168, 203）を修正。flutter analyze 0件を維持。',
    '2026-03-30'
  )
ON CONFLICT DO NOTHING;
