-- Session: daily-development 2026-03-31 #4
-- app_feedback テーブル実装・FeedbackListPage 管理統合

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'app_feedbackテーブル実装・フィードバック管理システム完成',
  'app_feedbackテーブル (bigserial PK, RLS付き) を新設。FeedbackPageからの機能要望/バグ報告/ご意見をSupabaseに保存。FeedbackListPageをAdminAnalyticsPageに統合し管理者UIから直接アクセス可能に。/admin-feedbackルートも追加。SECURITY DEFINERを活用したRLS無限再帰回避の実装例としてブログ下書きも作成。',
  '2026-03-31'
)
ON CONFLICT DO NOTHING;
