-- PS#4 S481: 競合3社追加 1264→1267社 (credit-karma/copilot-money/empower)
-- SEO: "Credit Karma代替"/"Copilot Money代替"/"Empower代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S481: 競合3社追加 1264→1267社 (credit-karma/copilot-money/empower)',
  'comparison_page.dartにcredit-karma(Intuit傘下無料クレジットスコアTransUnion/Equifax ID保護/3DBA5E)/copilot-money(iOS向けプレミアム家計管理AI分類投資追跡/2E6BE5)/empower(旧Personal Capital資産管理401k分析手数料チェッカー/00B09C)の3社追加(1264→1267社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
