-- PS#4 S351: 競合3社追加 924→927社 (leonardoai/playgroundai/krea-ai)
-- SEO: "Leonardo.Ai代替"/"Playground AI代替"/"Krea AI代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S351: 競合3社追加 924→927社 (leonardoai/playgroundai/krea-ai)',
  'comparison_page.dartにleonardoai(AIゲームアセットキャラクターテクスチャ/image-gen/F59E0B)/playgroundai(AIフォトリアリスティック画像グラフィックデザイン/image-gen/6D28D9)/krea-ai(AIリアルタイム画像生成強化クリエイティブ/image-gen/EC4899)の3社追加(924→927社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
