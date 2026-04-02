-- Session daily-development 2026-04-02: ガントチャート・タイムライン機能実装
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'ガントチャート・タイムライン実装 (Notion Timeline/Microsoft Project競合)',
  'GanttTimelinePage を新規作成。gantt-timeline-manager Edge Function と連携し、プロジェクト管理・タスク依存・マイルストーン・クリティカルパス分析を実装。/gantt-timeline ルート追加。業務メニューカタログ growth セクションに追加。EdgeFunctionSummaryCard で gantt-timeline-manager と video-meeting-manager を UI実装済みにマーク。growth_roadmap_progress_card でガントチャートを notYet→done に更新。Notion 機能カバー率向上。flutter analyze 0件維持。',
  '2026-04-02'
)
ON CONFLICT DO NOTHING;
