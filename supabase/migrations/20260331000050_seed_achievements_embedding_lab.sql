-- daily-development 2026-03-31 実績シード: Embedding Lab 類似度比較機能

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'Embedding Lab テキスト類似度比較機能追加',
    'embedding_lab_page.dart を全面刷新。gemini-embedding-001 を使ったコサイン類似度比較タブを追加。2テキストを並列fetchして類似度スコア(−1.0〜1.0)をLinearProgressIndicatorとカラーラベルで可視化。将来のセマンティックノート検索の実験基盤として整備。flutter analyze 0件維持。',
    '2026-03-31'
  ),
  (
    'サイトマップ40URL・選挙スケジュール管理室ルート追加',
    'web/sitemap.xml に /public-memos・/local-election-700・/local-election-schedule・/referral を追加し36→40URLに拡充。main.dart に /local-election-schedule・/embedding-lab ルートを追加。home_tool_catalog.dart に対応エントリを登録。flutter analyze 0件維持。',
    '2026-03-31'
  )
ON CONFLICT DO NOTHING;
