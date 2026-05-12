-- PS#4 S508: 競合3社追加 継続 (vagrant/packer/nomad)
-- SEO: "Vagrant代替"/"Packer代替"/"Nomad代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S508: 競合3社追加 (vagrant/packer/nomad)',
  'comparison_page.dartにvagrant(VagrantBox仮想環境自動化プロビジョニングチーム統一/1563FF)/packer(マシンイメージ自動構築AMI/VMware/DockerマルチプラットフォームCI統合/02A8EF)/nomad(シンプルオーケストレーションコンテナVM/バイナリConsul統合/00CA8E)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
