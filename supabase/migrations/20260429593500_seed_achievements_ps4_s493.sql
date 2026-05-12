-- PS#4 S493: 競合3社追加 継続 (flow-app/activecollab/freedcamp)
-- SEO: "Flow代替"/"ActiveCollab代替"/"Freedcamp代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S493: 競合3社追加 (flow-app/activecollab/freedcamp)',
  'comparison_page.dartにflow-app(シンプルチームタスクプロジェクトSlack統合/5E35B1)/activecollab(セルフホスト可タイムシート請求チームコラボエージェンシー向け/D32F2F)/freedcamp(無料PMタスクGanttカレンダーDiscussions/388E3C)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
