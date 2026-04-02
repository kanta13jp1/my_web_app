-- Session: daily-development 2026-04-03
-- 旅行プランナー・バーチャルホワイトボード・レシピ食事プランナー UI 実装

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    '旅行プランナー実装 (daily-development 2026-04-03)',
    'travel-itinerary-planner Edge Function と連携した旅行管理UI。旅行プラン作成・日程管理(アクティビティ)・予約情報(ホテル/フライト等)・パッキングリスト・予算管理の4タブ構成。Google Travel/TripAdvisor競合。/travel-itineraryルート追加・業務メニューcatalogに登録。flutter analyze 0件維持。',
    '2026-04-03'
  ),
  (
    'バーチャルホワイトボード実装 (daily-development 2026-04-03)',
    'virtual-whiteboard Edge Function と連携したホワイトボードUI。マイボード一覧・テンプレート選択(ブレインストーミング/カンバン/振り返り/マインドマップ)・付箋追加・図形要素表示の機能を実装。Miro/Microsoft Whiteboard/FigJam競合。deprecated RadioListTileをIcon+ListTileパターンに移行。/virtual-whiteboardルート追加。flutter analyze 0件維持。',
    '2026-04-03'
  ),
  (
    'レシピ・食事プランナー実装 (daily-development 2026-04-03)',
    'recipe-meal-planner Edge Function と連携したレシピ管理UI。カテゴリフィルタ付きレシピ一覧(GridView)・週間献立計画・買い物リスト自動生成の3タブ構成。Amazon Fresh/クックパッド/Liven競合。/recipe-meal-plannerルート追加・業務メニューcatalogに登録。flutter analyze 0件維持。',
    '2026-04-03'
  )
ON CONFLICT DO NOTHING;
