-- PS#4 S567: 競合3社追加 継続 (tanium/automox/ninjaone)
-- SEO: "Tanium代替"/"Automox代替"/"NinjaOne代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S567: 競合3社追加 (tanium/automox/ninjaone)',
  'comparison_page.dartにtanium(リアルタイムXEM・15秒可視化・パッチ・脅威インテリジェンス/00A0DC)/automox(クラウドパッチ自動化・Windows/Mac/Linux・コンプライアンス/0D6EFD)/ninjaone(クラウドRMM・パッチ・リモートアクセス・バックアップ・MSP/IT統合/00A3FF)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
