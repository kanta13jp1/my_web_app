-- PS#4 S565: 競合3社追加 継続 (workspace-one/ivanti/soti)
-- SEO: "Workspace ONE代替"/"Ivanti代替"/"SOTI代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S565: 競合3社追加 (workspace-one/ivanti/soti)',
  'comparison_page.dartにworkspace-one(VMware UEM・ゼロトラスト・デジタルワークスペース・AIops管理/607078)/ivanti(UEM・ITSM・ゼロトラスト・パッチ管理・エンドポイント統合/00A3E0)/soti(MobiControl・IoT/ルーギッド・Android/iOS・BYOD/001F5B)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
