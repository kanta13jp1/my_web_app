-- PS版#6: 競馬バッチパイプライン最適化 (Sessions 1-5)
-- 36分 → ~5分 (86%削減) の最適化内容を記録

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS版#6: 競馬バッチパイプライン 36分→5分最適化',
  '競馬自動更新ワークフローを5段階で最適化:
(1) horse_entries に prev_history_fetched フラグ追加 (404馬の毎時リトライ防止)
(2) _fetch_entries_for_source をN回DBクエリ→1回バッチ取得 (出走表取得を高速化)
(3) cleanup_stale_races() 追加 (前日以前のscheduled→cancelled一括更新)
(4) time.sleep(1) を404失敗時スキップ+失敗IDバッチPATCH (前走情報29分→5分)
(5) http_get でNAR URL (nar.netkeiba.com) をEUC-JP確定デコード (文字化けループ根本修正)
また fetch_results() 後に horseracing.evaluate_accuracy を自動呼び出してアンサンブル予想の的中率を自動スコアリング。
horse_race_predictions_ensemble + horse_prediction_accuracy + horse_provider_leaderboard viewで
Gemini/OpenAI/Anthropic/xAIの予想精度をプロバイダー別に追跡する基盤も完成。',
  '2026-04-19'
)
ON CONFLICT DO NOTHING;
