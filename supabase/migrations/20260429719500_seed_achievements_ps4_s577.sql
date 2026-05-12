-- PS#4 S577: 競合3社追加 継続 (kayako/deskpro/dixa)
-- SEO: "Kayako代替"/"Deskpro代替"/"Dixa代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S577: 競合3社追加 (kayako/deskpro/dixa)',
  'comparison_page.dartにkayako(顧客コンテキスト型CS・SingleView・ライブチャット・ソーシャル統合/363B64)/deskpro(オンプレ/クラウドCSP・ITSM・マルチチャネル・セルフホスト可/0062FF)/dixa(カンバセーショナルCS・AIエージェント・オムニチャネル・エンタープライズCX/5B21B6)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
