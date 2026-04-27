-- PS#6 S63: data quality score sync — scraper ⇔ EF 15フィールド統一
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'PS#6 S63 — データ品質スコア Scraper⇔EF 同期修正',
    'fetch_horse_racing.py _data_quality_score と tools-hub horseRaceDataQualityScore を15フィールドに統一。prev_last_3f と horse_weight_change を両方に追加 (旧13 → 新15)。スクレーパーが書き込む data_quality_score がソートタイブレーカーとして正確に機能するように修正。',
    '2026-04-27'
  )
ON CONFLICT DO NOTHING;
