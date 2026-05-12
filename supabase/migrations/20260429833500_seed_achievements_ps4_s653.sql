-- PS#4 S653: 競合3社追加 Ruby/PHP/Java Webフレームワーク (rails/laravel/spring-boot)
-- SEO: "Ruby on Rails代替"/"Laravel代替"/"Spring Boot代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S653: 競合3社追加 (rails/laravel/spring-boot)',
  'comparison_page.dartにrails(Ruby フルスタックWebFW・CoC・DRY・ActiveRecord・Generator/CC0000)/laravel(PHP Webフレームワーク・Eloquent ORM・Blade・Queue・スケジューラー/FF2D20)/spring-boot(Java/Kotlin Webフレームワーク・自動設定・エンタープライズ・マイクロサービス/6DB33F)の3社追加(1780社)。sitemap 1876 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
