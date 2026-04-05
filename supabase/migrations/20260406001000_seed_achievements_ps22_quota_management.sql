-- Session PS#22: Quota管理・ドキュメント整理・cs-check強化
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'Supabase Quota管理・local-election-intelligence デプロイ',
    'Edge Function 上限 402 エラーを解消。不要な8関数（social-proof-generator, user-growth-analytics, edge-function-test-runner, schedule-result-tracker, schedule-execution-logger, code-review-issues, generate-quote-image, share-quote）を削除してスロット確保。local-election-intelligence を正常デプロイ (ACTIVE v1)。edge_function_summary_card.dart の未デプロイ6関数を hasUi:false に更新。cs-check Schedule Step 0 に QUOTA GUARD を追加して将来の超過を防止。古い設計ドキュメント13件を docs/archive/ へ移動。flutter analyze 0エラー維持。',
    '2026-04-06 00:00:00+00'
  )
ON CONFLICT DO NOTHING;
