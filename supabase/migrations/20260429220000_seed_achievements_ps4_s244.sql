-- PS#4 S244: 競合3社追加 603→606社 (chroma/milvus/lancedb)
-- SEO: "Chroma代替"/"Milvus代替"/"LanceDB代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S244: 競合3社追加 603→606社 (chroma/milvus/lancedb)',
  'comparison_page.dartにchroma(Python/JS OSS埋め込みDB/LangChain標準/vector-db/FF6B2B)/milvus(OSSスケーラブルベクターDB/Zilliz/vector-db/00B4F0)/lancedb(サーバーレスOSS/Lance形式/vector-db/8B5CF6)の3社追加(603→606社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
