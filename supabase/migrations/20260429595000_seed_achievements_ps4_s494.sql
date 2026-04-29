-- PS#4 S494: 競合3社追加 継続 (teamgantt/meistertask/taskworld)
-- SEO: "TeamGantt代替"/"MeisterTask代替"/"Taskworld代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S494: 競合3社追加 (teamgantt/meistertask/taskworld)',
  'comparison_page.dartにteamgantt(Ganttチャート専門ドラッグDrop依存関係リソース管理/1976D2)/meistertask(Kanban特化MindMeister統合自動化GDPR準拠/27AE60)/taskworld(タスク管理×分析×チャット統合進捗自動分析/00BCD4)の3社追加。sitemap 1399 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
