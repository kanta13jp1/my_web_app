-- PS#4 S336: 競合3社追加 879→882社 (vectara/zilliz/marqo)
-- SEO: "Vectara代替"/"Zilliz代替"/"Marqo代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S336: 競合3社追加 879→882社 (vectara/zilliz/marqo)',
  'comparison_page.dartにvectara(エンタープライズRAGベクター検索API/vector-db/4A90E2)/zilliz(MilvusフルマネージドクラウドベクターDB/vector-db/00A1EA)/marqo(テンソル検索マルチモーダルベクターDB/vector-db/8B5CF6)の3社追加(879→882社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
