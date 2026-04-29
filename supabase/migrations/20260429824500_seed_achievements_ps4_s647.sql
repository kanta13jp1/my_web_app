-- PS#4 S647: 競合3社追加 Vue/高度状態管理 (pinia/xstate/nanostores)
-- SEO: "Pinia代替"/"XState代替"/"Nano Stores代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S647: 競合3社追加 (pinia/xstate/nanostores)',
  'comparison_page.dartにpinia(Vue公式状態管理・Vuex後継・Vue 3対応・TypeScript・DevTools/FFD859)/xstate(有限状態機械・ステートチャート・ビジュアライザー・React/Vue/Svelte/2B1B67)/nanostores(超軽量状態管理・フレームワーク非依存・React/Vue/Svelte/Solid/44B4A6)の3社追加(1762社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
