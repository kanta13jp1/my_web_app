-- Session 20: Amazon 第14競合追加・ユーザーマニュアル全面刷新

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'Amazon を第14競合に追加: /vs-amazon 比較ページ実装',
    'ComparisonPage に amazon エントリ追加 (Alexa/Kindle/購買管理 vs 自分株式会社)。/vs-amazon ルート追加。sitemap.xml に Amazon URL 追加 (合計22URL)。LP比較リンク・index.html キーワードに Amazon代替/Alexa代替/Kindle代替 を追加',
    '2026-03-26'
  ),
  (
    'ユーザーマニュアル全面刷新: 実際の UI ナビゲーションに準拠・インポート手順詳細化',
    'Notion/Evernote/Markdown のエクスポート手順をステップ形式で詳細化 (競合アプリの操作方法を含む)。プロフィール設定・技術ブログ投稿管理・機能リクエスト手順を追加。競合14社の記述に更新。存在しないナビゲーション表記を削除',
    '2026-03-26'
  )
ON CONFLICT DO NOTHING;

-- Amazon を growth_plans テーブルに追加
INSERT INTO growth_plans (name, target_label, current_value, target_value, deadline, plan_type, sort_order)
VALUES (
  'vs Amazon',
  'Amazon (3.1億アクティブユーザー)',
  21,
  310000000,
  '2035-12-31',
  'competitor',
  17
)
ON CONFLICT DO NOTHING;
