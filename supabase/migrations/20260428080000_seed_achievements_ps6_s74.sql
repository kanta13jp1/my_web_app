-- PS#6 S74: GHA double-exec fix + force backfill 504 timeout 修正
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬AI: GHA二重実行バグ修正 + force backfill 504タイムアウト修正',
  'horse-racing-update.yml の "all mode" ステップに SKIP_MODES ガード追加。history/evaluate/backfill/stats/dqs_recalc を dispatch した際に専用ステップと二重実行されていたバグを解消。tools-hub EFのbackfill_learning_data: force=true時のlimitをmax 60に制限(Supabase 150s idle timeout内で完結)。defaultLimitもforce時は60に設定。通常backfillはmax 500/default 160を維持。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
