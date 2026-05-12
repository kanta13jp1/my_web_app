-- PS#4 S441: 競合3社追加 1147→1150社 (signal-app/viber/kakao)
-- SEO: "Signal代替"/"Viber代替"/"KakaoTalk代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S441: 競合3社追加 1147→1150社 (signal-app/viber/kakao)',
  'comparison_page.dartにsignal-app(最強暗号化メッセージングOSSメタデータ最小化/messaging/2592E9)/viber(Rakuten傘下無料通話Communities Viber Out/messaging/7360F2)/kakao(韓国最大スーパーアプリKakaoPay/KakaoMap/KakaoTaxi/superapp/FFE300)の3社追加(1147→1150社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
