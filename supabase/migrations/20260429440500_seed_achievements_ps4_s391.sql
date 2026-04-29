-- PS#4 S391: 競合3社追加 1044→1047社 (oyster/papaya-global/mparticle)
-- SEO: "Oyster代替"/"Papaya Global代替"/"mParticle代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S391: 競合3社追加 1044→1047社 (oyster/papaya-global/mparticle)',
  'comparison_page.dartにoyster(グローバル雇用EOR海外給与コンプライアンス/global-hr/1E66F5)/papaya-global(グローバル給与EORワークフォース管理/global-hr/00C7B7)/mparticle(CDP データ統合オーディエンス管理/cdp/4B3FF7)の3社追加(1044→1047社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
