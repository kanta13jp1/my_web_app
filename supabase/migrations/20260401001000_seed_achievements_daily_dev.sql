-- daily-development 2026-04-01: 集中タイマー・AI文章アシスタント・浪費耐性トレーニング統合
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    '集中タイマーページ実装 (Forest/Focusmate競合)',
    'focus_timer_page.dart を新規作成。focus-timer Edge Function と連携し、ポモドーロ式タイマー (5/15/25/50分プリセット)・セッション開始/完了/キャンセル・週次統計 (完了数/集中分数/連続日数/集中スコア) を実装。業務メニュー growth セクションに追加。/focus-timer ルートを main.dart に追加。',
    '2026-04-01'
  ),
  (
    'AI文章アシスタントページ実装 (Grammarly/Notion AI競合)',
    'ai_writing_assistant_page.dart を新規作成。ai-writing-assistant Edge Function と連携し、6機能 (文章改善/要約/続きを書く/翻訳/トーン変換/タイトル提案) をタブレスUIで提供。Dart 3 レコード構文でアクション定義を圧縮。コピーボタン付き結果表示。業務メニュー growth セクションに追加。/ai-writing-assistant ルートを追加。',
    '2026-04-01'
  ),
  (
    '浪費耐性トレーニングカードをホーム画面に統合',
    'AbstinenceDisciplineSnapshot の5プロパティ (repCount/moneySaved/timeSavedMinutes/streakDays/stageLabel) を HomeSnapshot に追加。ホーム禁欲ガードパネルに「浪費耐性トレーニング」カード (我慢回数・防いだ出費・取り戻した時間・連続日数・ステージラベル表示) を実装。テストケース2件追加。',
    '2026-04-01'
  ),
  (
    '新規Edge Function 5本をCI/CDに追加 (focus-timer/ai-writing-assistant/bookmark-sync/task-dependency/note-sharing-enhanced)',
    'supabase/config.toml に 5 関数の enabled/verify_jwt 設定を追加。deploy-prod.yml の supabase functions deploy ステップに 5 関数を追加し、本番自動デプロイを整備。flutter analyze 0件・deno lint 0件を維持。',
    '2026-04-01'
  ),
  (
    'ユーザーマニュアル更新: 集中タイマー・AI文章アシスタント手順追加',
    'user_manual_page.dart の独自機能セクションに集中タイマーとAI文章アシスタントの詳細操作手順 (各機能の使い方・プリセット・6アクション説明) を追記。',
    '2026-04-01'
  )
ON CONFLICT DO NOTHING;
