-- Session: daily-development #3 2026-04-03
-- 習慣ゲーミフィケーション・コードプレイグラウンド・不動産管理 UI実装

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    '習慣ゲーミフィケーション実装',
    'Duolingo/Forest/Habitica競合。habit-gamification Edge Function と連携。デイリーチャレンジ (5種)・XP/レベルシステム・12種バッジ・ストリーク管理・ランキングの3タブ構成。TabController + Future.wait 並列取得。flutter analyze 0件維持。',
    '2026-04-03'
  ),
  (
    'コードプレイグラウンド実装',
    'GitHub Gist/CodePen/Codex競合。code-playground Edge Function と連携。20言語対応スニペット保存・言語テンプレート・共有リンク生成・コレクション管理・言語別統計の3タブ構成。deprecated withOpacity→withValues / value→initialValue 対応。flutter analyze 0件維持。',
    '2026-04-03'
  ),
  (
    '不動産管理実装',
    'MoneyForward/Suumo競合。real-estate-tracker Edge Function と連携。物件登録 (7種別)・収支記録 (8種別)・ROI計算・億/万単位フォーマット表示の3タブ構成。flutter analyze 0件維持。',
    '2026-04-03'
  )
ON CONFLICT DO NOTHING;
