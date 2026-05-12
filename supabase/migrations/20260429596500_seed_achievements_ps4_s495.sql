-- PS#4 S495: 競合3社追加 1305→1314社 (salesflare/apptivo/bigin)
-- SEO: "Salesflare代替"/"Apptivo代替"/"Bigin代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S495: 競合3社追加 1305→1314社 (salesflare/apptivo/bigin)',
  'comparison_page.dartにsalesflare(自動データ入力CRMLinkedIn取込メール追跡/FF5722)/apptivo(CRM+請求+PM+50ビジネスアプリ統合低コスト/0D47A1)/bigin(Zoho製小規模ビジネス向けシンプルCRMパイプラインモバイル/E64A19)の3社追加(1305→1314社)。sitemap 1408 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
