-- PS#4 S303: 競合3社追加 780→783社 (legalzoom/contractpodai/rocket-lawyer)
-- SEO: "LegalZoom代替"/"ContractPodAi代替"/"Rocket Lawyer代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S303: 競合3社追加 780→783社 (legalzoom/contractpodai/rocket-lawyer)',
  'comparison_page.dartにlegalzoom(オンライン法的書類法人設立/legaltech/1D4ED8)/contractpodai(AI契約ライフサイクル管理CLM/legaltech/6D28D9)/rocket-lawyer(オンライン法務中小企業/legaltech/DC2626)の3社追加(780→783社)。sitemap 832 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
