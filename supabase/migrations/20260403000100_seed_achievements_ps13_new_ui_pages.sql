-- Session PS#13: 新規 UI ページ 5件追加 + EdgeFunctionSummaryCard 7件更新
-- LanguageLearningPage / RecipeMealPlannerPage / TravelItineraryPlannerPage
-- PetCareManagerPage / PhotoGalleryManagerPage

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    '語学学習・レシピ・旅行・ペット・フォトギャラリー UI 追加 (PS#13)',
    'LanguageLearningPage (/language-learning): フラッシュカード学習・レッスン一覧・進捗管理の3タブ。RecipeMealPlannerPage (/recipe-meal-planner): レシピ一覧・週間食事プラン・買い物リストの3タブ。TravelItineraryPlannerPage (/travel-planner): 旅行一覧→行程詳細の2段階UI。PetCareManagerPage (/pet-care): ペット情報・健康記録・ワクチンの3タブ。PhotoGalleryManagerPage (/photo-gallery): アルバムグリッド→写真グリッドの2段階UI。EdgeFunctionSummaryCard 7件を「実装済み」に更新 (crm-sales-pipeline/horse-racing-predictor/language-learning/pet-care-manager/photo-gallery-manager/recipe-meal-planner/travel-itinerary-planner)。flutter analyze 0エラー確認済み。',
    '2026-04-03'
  )
ON CONFLICT DO NOTHING;
