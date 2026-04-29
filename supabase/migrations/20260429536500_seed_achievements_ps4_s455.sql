-- PS#4 S455: 競合3社追加 1186→1189社 (exodus-wallet/kraken/kucoin)
-- SEO: "Exodus代替"/"Kraken代替"/"KuCoin代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S455: 競合3社追加 1186→1189社 (exodus-wallet/kraken/kucoin)',
  'comparison_page.dartにexodus-wallet(デスクトップ/モバイル暗号ウォレット300+資産DeFi/Trezor連携/crypto-wallet/0B47EF)/kraken(セキュリティ重視暗号取引所Kraken Pro先物ステーキング/crypto-exchange/5741D9)/kucoin(700+通貨ボット取引KCS優遇P2P/crypto-exchange/24AE8F)の3社追加(1186→1189社)。sitemap 1282 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
