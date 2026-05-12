-- PS#4 S604: 競合3社追加 継続 (victoriametrics/questdb/tdengine)
-- SEO: "VictoriaMetrics代替"/"QuestDB代替"/"TDengine代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S604: 競合3社追加 (victoriametrics/questdb/tdengine)',
  'comparison_page.dartにvictoriametrics(高性能時系列DB・Prometheus互換・低コスト・高圧縮/621FE6)/questdb(高速時系列DB・SQL・PostgreSQLワイヤ互換・ゼロコピー/9DB7D9)/tdengine(IoT時系列DB・超高書き込み・SQL・組み込みキャッシュ/3B7DD8)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
