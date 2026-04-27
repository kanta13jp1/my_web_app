-- PS#6 S69: dqs_recalc 週次GHA + tools-hub 死コード削除 + cross-instance-pr
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'PS#6 S69 — GHA dqs_recalc 週次スケジュール + tools-hub 死コード削除',
    'horse-racing-update.yml に dqs_recalc ステップ追加 (日曜 JST 01:00 自動実行 or dispatch)。tools-hub から UrgentHorseEntrySeed / UrgentHorseRaceSeed / URGENT_HORSE_RACES_20260426 / urgentHorseRacesForDate / upsertUrgentHorseRaces (247行) を完全削除。horseracing.today と horseracing.predict_all の呼び出し箇所も除去。cross-instance-pr: 複勝コンセンサス UI (place_consensus) + 複勝/ワイド命中率サマリーカードを VSCode に依頼。',
    '2026-04-27'
  )
ON CONFLICT DO NOTHING;
