-- PS#6 S171: prevWinVenueReturnsBonus — 前走勝利×同一会場再訪補正 confidence 87 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S171: 競馬予測EF confidence 87 terms — prevWinVenueReturnsBonus追加',
  '前走勝利×同一会場再訪補正(prevWinVenueReturnsBonus)を追加。prev_venue(前走開催場所)とrace.venue(今走開催場所)が一致する場合に前走着順で評価。①prev_finish=1(前走1着) × 同一会場=+1%(同コースでの勝利実証済み: 最強のコース適性証明)。②prev_finish≥9(前走9着以下大敗) × 同一会場=-1%(同コースで大敗: 苦手コース継続シグナル)。prevVenueMatchBonus(S148:同一会場単純一致+1%)が着順に関わらず同会場に+1%を付与するのに対し、本補正は勝利(1着)と大敗(9着以下)を区別する質的評価を追加。コース勝利馬の再訪では合計+2%(prevVenueMatch+prevWinVenueReturns)となり、会場適性の最強シグナルを反映。confidence formula 87 terms体制確立。',
  '2026-05-04'
) ON CONFLICT DO NOTHING;
