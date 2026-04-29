-- PS#4 S541: 競合3社追加 継続 (draftbit/bravo-studio/appgyver)
-- SEO: "Draftbit代替"/"Bravo Studio代替"/"SAP Build Apps代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S541: 競合3社追加 (draftbit/bravo-studio/appgyver)',
  'comparison_page.dartにdraftbit(React Nativeノーコード・ネイティブアプリ・Figma連携・カスタムコード混在/0EA5E9)/bravo-studio(Figma/XD→ネイティブiOS/Android・ノーコード・API接続/4CAF50)/appgyver(SAP Build Apps エンタープライズローコード・SAP BTP統合・モバイル/Web/0070F2)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
