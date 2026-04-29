-- PS#4 S535: 競合3社追加 継続 (coggle/mindnode/ayoa)
-- SEO: "Coggle代替"/"MindNode代替"/"Ayoa代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S535: 競合3社追加 (coggle/mindnode/ayoa)',
  'comparison_page.dartにcoggle(マインドマップ・フローチャート・シンプルコラボ・無制限共有・Googleログイン無料/00BCD4)/mindnode(Apple向けマインドマップ・macOS/iOS/iPadOS・ショートカット統合・iCloud同期/30B0C7)/ayoa(有機的マインドマップ+タスク+ホワイトボード統合・AI機能・視覚的PM/F5A623)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
