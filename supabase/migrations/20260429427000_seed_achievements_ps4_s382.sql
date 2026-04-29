-- PS#4 S382: 競合3社追加 1017→1020社 (airbyte/stitch/talend)
-- SEO: "Airbyte代替"/"Stitch代替"/"Talend代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S382: 競合3社追加 1017→1020社 (airbyte/stitch/talend)',
  'comparison_page.dartにairbyte(OSS データ統合ELTパイプライン300+コネクタ/data-pipeline/615EF0)/stitch(シンプルクラウドETLデータウェアハウス連携/data-pipeline/3D99F5)/talend(エンタープライズデータ統合ETLデータ品質/data-integration/003B6F)の3社追加(1017→1020社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
