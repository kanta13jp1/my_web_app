-- Session daily-development 2026-04-11: パーソナルダッシュボード実装 + LP 52→56のこと
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'パーソナルダッシュボード実装 (Notion 3.4 対抗)',
    'personal_dashboard_page.dart を新規作成。ノート数・タスク完了・習慣ストリーク・集中時間を KPI カードグリッドで表示。FractionallySizedBox による棒グラフ (ライブラリ不使用) で週次推移を可視化。習慣トラッキングタブで全習慣のストリーク一覧を表示。personal-dashboard Edge Function と連携 (フォールバック付き)。/personal-dashboard ルート追加・home_tool_catalog.dart に knowledge セクションとして登録。Notion 3.4 ダッシュボードビュー対抗機能。flutter analyze 0件維持。',
    '2026-04-11'
  ),
  (
    'LP 52→56のこと 拡張 (アクセス制御・在庫・テンプレート・ダッシュボード)',
    'landing_page.dart の _buildUniqueValueSection() に4機能を追加: アクセス制御・権限管理 (ジョブカン対抗)・在庫・バーコード管理 (Amazon対抗)・テンプレート広場 (Notionマーケットプレイス対抗)・パーソナルダッシュボード (Notion 3.4対抗)。LP タイトルを「52のこと」から「56のこと」に更新。訴求ページ数が増加し CVR 改善を狙う。',
    '2026-04-11'
  )
ON CONFLICT DO NOTHING;
