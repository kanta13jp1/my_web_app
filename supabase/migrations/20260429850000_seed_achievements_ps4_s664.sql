-- PS#4 S664: 競合3社追加 GitOps/イメージビルド/VM (argo-cd/packer/vagrant)
-- SEO: "Argo CD代替"/"Packer代替"/"Vagrant代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S664: 競合3社追加 (argo-cd/packer/vagrant)',
  'comparison_page.dartにargo-cd(Kubernetes GitOps CD・宣言的・Git自動同期・UIダッシュボード/EF7B4D)/packer(HashiCorp マシンイメージビルダー・AMI/Docker/VMware/1DAEFF)/vagrant(HashiCorp 仮想マシン管理・開発環境再現・VirtualBox/1563FF)の3社追加(1816社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
