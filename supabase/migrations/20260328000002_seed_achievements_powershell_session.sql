-- Session 2026-03-28: PowerShell全体管理セッション
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('Claude Code Schedule統合強化', 'daily-reportにScheduleヘルスモニター追加、blog-draftに11プラットフォーム投稿準備追加', '2026-03-28'),
  ('12部署20人 仮想AI組織', '5エージェントから12部署19エージェントに拡張（企画部・開発部・営業部・CS部・法務部・広報部・調達部を追加）', '2026-03-28'),
  ('AI ノート検索ページ追加', 'ai-search Edge Functionと連携する自然語検索UIを新規実装', '2026-03-28'),
  ('get-home-dashboard統合', 'ホーム画面にtotalUsers表示と7日間LPスパークライン追加', '2026-03-28'),
  ('進捗バー21社完全対応', 'Discord・LINE・Facebook・Liven・GitHub・Google・Microsoftの7社を追加', '2026-03-28'),
  ('管理者ユーザー詳細ダイアログ', '全プロフィールフィールド表示・未設定項目の明示・githubHandle/isPublic追加', '2026-03-28'),
  ('プロフィール更新促進UI改善', 'ProfileCompletionBannerに具体的な未設定フィールド名を表示', '2026-03-28'),
  ('Scheduleタスクモニター拡張', '14タスク対応（blog-auto-post・schedule-health-monitor・edge-function-ui-sync追加）', '2026-03-28'),
  ('ブログ投稿管理Schedule連携', 'TechBlogTrackerPageにSchedule自動生成ドラフト表示セクション追加', '2026-03-28')
ON CONFLICT DO NOTHING;
