-- PS#4 S632: 競合3社追加 ビルドツール/モノレポ (maven/bazel/lerna)
-- SEO: "Apache Maven代替"/"Bazel代替"/"Lerna代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S632: 競合3社追加 (maven/bazel/lerna)',
  'comparison_page.dartにmaven(Java標準ビルド・POM.xml・依存管理・ライフサイクル・Central Repository/C71A36)/bazel(Google製ビルド・リモートキャッシュ・多言語・大規模モノレポ・再現可能/43A047)/lerna(JSモノレポ管理・バージョン管理・パブリッシュ・Nx統合/9333EA)の3社追加(1717社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
