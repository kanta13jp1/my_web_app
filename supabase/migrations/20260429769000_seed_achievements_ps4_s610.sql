-- PS#4 S610: 競合3社追加 継続 (codefresh/semaphore/buddy)
-- SEO: "Codefresh代替"/"Semaphore CI代替"/"Buddy代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S610: 競合3社追加 (codefresh/semaphore/buddy)',
  'comparison_page.dartにcodefresh(GitOps CI/CD・ArgoCD統合・Kubernetes・高速パイプライン/1CC0C0)/semaphore(高速CI/CD・並列実行・Dockerキャッシュ・クラウドネイティブ/19A974)/buddy(ビジュアルCI/CD・250+アクション・マルチクラウド/1A82FB)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
