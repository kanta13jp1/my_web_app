-- PS#4 S655: 競合3社追加 Rust Webフレームワーク (actix/axum) + Quarkus
-- SEO: "Actix Web代替"/"Axum代替"/"Quarkus代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S655: 競合3社追加 (actix/axum/quarkus)',
  'comparison_page.dartにactix(Rust Webフレームワーク・アクターモデル・型安全・TechEmpower上位/DEA584)/axum(Rust・Tokio/Tower統合・型安全・非同期・モジュラー/CE422A)/quarkus(Kubernetes Native Java・GraalVM・超高速起動・低メモリ/4695EB)の3社追加(1789社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
