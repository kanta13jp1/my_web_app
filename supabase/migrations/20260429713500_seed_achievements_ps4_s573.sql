-- PS#4 S573: 競合3社追加 継続 (bmc-helix/cherwell/topdesk)
-- SEO: "BMC Helix代替"/"Cherwell代替"/"TOPdesk代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S573: 競合3社追加 (bmc-helix/cherwell/topdesk)',
  'comparison_page.dartにbmc-helix(Helix ITSM・AIops・CMDB・クラウドネイティブ・コグニティブサービス管理/E31837)/cherwell(ノーコードITSM・柔軟カスタマイズ・ITSM/ITOM・Ivanti統合/D01F34)/topdesk(ITSM/CAFM/SSP・セルフサービス・中規模・ヨーロッパ発/0C8E4F)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
