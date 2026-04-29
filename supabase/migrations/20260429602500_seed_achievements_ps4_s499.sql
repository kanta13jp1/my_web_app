-- PS#4 S499: 競合3社追加 継続 (macrofactor/carb-manager/garmin-connect)
-- SEO: "MacroFactor代替"/"Carb Manager代替"/"Garmin Connect代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S499: 競合3社追加 (macrofactor/carb-manager/garmin-connect)',
  'comparison_page.dartにmacrofactor(AIコーチ適応型カロリー計算マクロ追跡科学的アルゴリズム/512DA8)/carb-manager(ケト低炭水化物追跡ケトカリキュレーターレシピ/00796B)/garmin-connect(GPS VO2Max Body Battery Training Load/007DC3)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
