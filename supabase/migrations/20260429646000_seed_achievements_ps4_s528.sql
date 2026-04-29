-- PS#4 S528: 競合3社追加 1404→1413社 (bugherd/marker-io/gleap)
-- SEO: "BugHerd代替"/"marker.io代替"/"Gleap代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S528: 競合3社追加 1404→1413社 (bugherd/marker-io/gleap)',
  'comparison_page.dartにbugherd(ウェブサイトバグ報告・ピンポイントフィードバック・Kanban管理・クライアント対応/FFC107)/marker-io(ビジュアルバグ報告・スクリーンショット自動添付・Jira/Trello連携/4834D4)/gleap(インアップフィードバック・AI Kaiチャットボット・ロードマップ・バグ報告・SDK/7C4DFF)の3社追加(1404→1413社)。sitemap 1507 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
