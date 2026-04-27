-- PS#6 S70: evaluate 即時実行 (JST 17-23時) + cleanup_stale_races limit追加
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'PS#6 S70 — 精度再評価即時化 (JST 17-23時) + cleanup limit=200',
    'horse-racing-update.yml の精度再評価ステップを JST 23:00 限定から JST 17:00〜23:00 に拡張。レース結果は通常 17時以降に確定するため、最大 6 時間あった評価ラグを 0 時間に短縮。evaluate は冪等設計のため同一レースの二重実行はスキップされる。あわせて cleanup_stale_races に limit=200 パラメータを追加し、大量の stale レースがある場合の一括 PATCH を防止。',
    '2026-04-27'
  )
ON CONFLICT DO NOTHING;
