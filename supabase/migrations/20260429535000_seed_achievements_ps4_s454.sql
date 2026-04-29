-- PS#4 S454: 競合3社追加 1183→1186社 (wyze/trezor/trust-wallet)
-- SEO: "Wyze代替"/"Trezor代替"/"Trust Wallet代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S454: 競合3社追加 1183→1186社 (wyze/trezor/trust-wallet)',
  'comparison_page.dartにwyze(低価格スマートカメラWyze Cam スマートプラグ月額不要/home-security/00C2E0)/trezor(OSSハードウェアウォレットModel T 8000+通貨Shamir Backup/crypto-wallet/1DC22D)/trust-wallet(Binance傘下モバイルウォレット100+チェーンDeFi/NFT統合/crypto-wallet/3375BB)の3社追加(1183→1186社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
