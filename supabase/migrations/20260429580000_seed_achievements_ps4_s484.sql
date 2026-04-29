-- PS#4 S484: 競合3社追加 1278社継続 (flipboard/reeder/proton-pass)
-- SEO: "Flipboard代替"/"Reeder代替"/"Proton Pass代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S484: 競合3社追加 (flipboard/reeder/proton-pass)',
  'comparison_page.dartにflipboard(ニュースキュレーションソーシャルマガジンFlipFed分散型Storyboard自分のFeed/E12828)/reeder(Apple向けプレミアムRSSリーダーiCloud同期ReadabilityオフラインMac/iPhone統合/6CB33F)/proton-pass(E2E暗号化パスワードマネージャーProtonエコシステムalias.com統合OSS無料/6D4AFF)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
