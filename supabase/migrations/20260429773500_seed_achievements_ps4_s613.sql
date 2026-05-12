-- PS#4 S613: 競合3社追加 継続 (spacelift/env0/atlantis)
-- SEO: "Spacelift代替"/"env0代替"/"Atlantis代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S613: 競合3社追加 (spacelift/env0/atlantis)',
  'comparison_page.dartにspacelift(Terraform/Pulumi/Ansible管理・ポリシーゲート・GitOps/1B5EFF)/env0(セルフサービスクラウド・Terraform管理・コスト可視化・RBAC/00C9A7)/atlantis(Terraform PR自動化・GitOps・セルフホスト・OSS/3C82F6)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
