-- PowerShell 全体管理セッション #4 追加実績シード 2026-03-31

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'business_intelligenceテーブル新規作成・21競合シードデータ投入',
    '競合・参入市場トラッキングテーブルを新規作成。category/competitor/source/market_size/our_feature/gap_analysis/priority/statusカラムで競合情報を構造化管理。21競合のシードデータを投入。RLS: 認証ユーザー読み取り可/管理者全操作可/service_role全操作可。',
    '2026-03-31'
  ),
  (
    'GitHub Actions CI に wasm build リグレッション検出ステップ追加',
    '.github/workflows/ci.yml のlint-and-testジョブにflutter build web --wasmステップを追加 (continue-on-error: true)。本番ビルドをブロックせず毎CI実行でwasmビルドの健全性を自動検出。',
    '2026-03-31'
  ),
  (
    'categoriesテーブル新規作成 (ノート/タスクカテゴリ管理)',
    'ユーザーごとのカスタムカテゴリ管理テーブルを追加。uuid PK・user_id外部キー・name/colorカラム・RLS4ポリシー・idx_categories_user_idインデックス。CategoriesPage・MedicalNotesPageルートも追加済み。',
    '2026-03-31'
  )
ON CONFLICT DO NOTHING;
