-- PS#4 S497: 競合3社追加 継続 (less-annoying/vcita/act-crm)
-- SEO: "Less Annoying CRM代替"/"vcita代替"/"Act! CRM代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S497: 競合3社追加 (less-annoying/vcita/act-crm)',
  'comparison_page.dartにless-annoying(月15ドル均一シンプルCRMパイプライン30日無料/66BB6A)/vcita(CRM+スケジューリング+請求統合オンライン予約/8E24AA)/act-crm(1987年創業老舗CRMコンタクト管理MAデスクトップ版/BF360C)の3社追加。sitemap 1408 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
