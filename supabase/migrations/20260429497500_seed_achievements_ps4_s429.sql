-- PS#4 S429: 競合3社追加 1111→1114社 (lyft/didi/ola)
-- SEO: "Lyft代替"/"DiDi代替"/"Ola代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S429: 競合3社追加 1111→1114社 (lyft/didi/ola)',
  'comparison_page.dartにlyft(米国配車ライドシェアLyftPink自転車シェア/ride-hailing/FF00BF)/didi(中国グローバル配車DiDi Express/99Brazil/Bolt中東/ride-hailing/FF6600)/ola(インド最大配車Ola Electric EV/オートリクシャ/ride-hailing/27AE60)の3社追加(1111→1114社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
