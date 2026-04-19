-- PS版#6: horse_entries に前走情報取得済みフラグを追加
-- 問題: 404 を返す NAR 馬が毎時間リトライされ前走情報取得ステップが 26 分かかる
-- 修正: prev_history_fetched = true で「試みた」を記録し、次回スキップ

ALTER TABLE horse_entries
  ADD COLUMN IF NOT EXISTS prev_history_fetched boolean NOT NULL DEFAULT false;

-- 既存エントリは全て「試行済み」とみなしてフラグを立てる
-- (prev_finish IS NULL のものも 404 失敗済みの可能性が高いため再試行しない)
UPDATE horse_entries
SET prev_history_fetched = true;

COMMENT ON COLUMN horse_entries.prev_history_fetched IS
  '前走情報取得試行済みフラグ。成功・404失敗問わず true にして毎時リトライを防止';
