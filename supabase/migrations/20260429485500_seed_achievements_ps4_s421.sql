-- PS#4 S421: 競合3社追加 1087→1090社 (hinge/bumble/coinbase)
-- SEO: "Hinge代替"/"Bumble代替"/"Coinbase代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S421: 競合3社追加 1087→1090社 (hinge/bumble/coinbase)',
  'comparison_page.dartにhinge(削除されるよう設計されたマッチングアプリ真剣な出会い/dating/E5264A)/bumble(女性主導マッチングアプリ友達ビジネスネットワーク/dating/FFD521)/coinbase(暗号資産取引所ステーキングウォレットWeb3/crypto/0052FF)の3社追加(1087→1090社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
