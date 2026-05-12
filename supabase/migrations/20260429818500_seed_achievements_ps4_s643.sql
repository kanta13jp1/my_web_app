-- PS#4 S643: 競合3社追加 ReactUIコンポーネント (shadcn/chakra-ui/mantine)
-- SEO: "shadcn/ui代替"/"Chakra UI代替"/"Mantine代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S643: 競合3社追加 (shadcn/chakra-ui/mantine)',
  'comparison_page.dartにshadcn(コピペReactコンポーネント・Radix UI基盤・Tailwind CSS・アクセシビリティ/09090B)/chakra-ui(アクセシブルReact・テーマ・ダークモード・Emotion/319795)/mantine(Reactコンポーネント・120+・フック・フォーム・通知・TypeScript/339AF0)の3社追加(1753社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
