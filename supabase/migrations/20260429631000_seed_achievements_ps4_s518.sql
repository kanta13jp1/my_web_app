-- PS#4 S518: 競合3社追加 継続 (nifi/flink/singer)
-- SEO: "Apache NiFi代替"/"Apache Flink代替"/"Singer代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S518: 競合3社追加 (nifi/flink/singer)',
  'comparison_page.dartにnifi(Apache NiFi OSS データフロー・ビジュアルパイプライン・300+プロセッサ・NSA開発・エンタープライズ/728E45)/flink(Apache Flink リアルタイムストリーム処理・状態管理・CEP・SQL・Kafka統合・大規模/E6522C)/singer(Stitch発OSS ETL標準・Tap/Target仕様・100+コネクタ・コミュニティ駆動・任意組み合わせ/17A589)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
