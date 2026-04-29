-- PS#4 S656: 競合3社追加 JVM フレームワーク (micronaut/ktor/vertx)
-- SEO: "Micronaut代替"/"Ktor代替"/"Vert.x代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S656: 競合3社追加 (micronaut/ktor/vertx)',
  'comparison_page.dartにmicronaut(JVM マイクロサービスFW・コンパイル時DI・GraalVM/2DA44E)/ktor(Kotlin非同期Webフレームワーク・JetBrains製・コルーチン/7F52FF)/vertx(Eclipse JVM リアクティブツールキット・マルチ言語/7B2FBE)の3社追加(1789社)。sitemap 1885 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
