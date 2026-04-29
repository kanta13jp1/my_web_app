-- PS#4 S607: 競合3社追加 継続 (coralogix/logz-io/mezmo)
-- SEO: "Coralogix代替"/"Logz.io代替"/"Mezmo代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S607: 競合3社追加 (coralogix/logz-io/mezmo)',
  'comparison_page.dartにcoralogix(ログ管理・APM・ML異常検知・コスト最適化/FF6B6B)/logz-io(マネージドELK・ログ管理・Kibana互換・AI異常検知/004C97)/mezmo(パイプライン型ログ管理・ストリーミングETL・データ制御/0F62FE)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
