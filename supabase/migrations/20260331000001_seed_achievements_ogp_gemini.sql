-- Session 2026-03-31: 全21社OGP対応 + Gemini選挙分析Edge Function
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    '21社比較ページ全社OGP対応完了',
    'Google・Microsoft・Discord・LINE・Facebook・Liven・GitHubの7社分のSEO OGPメタタグをindex.htmlのSEOシェルに追加。全21競合の比較ページでSNSシェア時に個別タイトル・説明が表示される。',
    '2026-03-31'
  ),
  (
    'gemini-election-analysis Edge Function新規作成',
    'Gemini 2.5 Flash APIを使用した選挙データAI分析Edge Function。国民民主党700人必達目標の月次KPI管理・都道府県別配分シミュレーション・現職議員リストをJSON構造化出力。supabase/config.tomlとdeploy-prod.yml CI/CDに追加。',
    '2026-03-31'
  ),
  (
    'ユーザーマニュアルホーム画面ナビゲーション更新',
    'user_manual_page.dartのホーム画面説明をQUICK ACCESSベースの実際のUIナビゲーションに更新。OFFICE KPI SNAPSHOT・KPI SUMMARY・OPERATIONS CALENDAR・SPECIAL PROJECT・RECENT TOOLSの各セクション説明を正確化。',
    '2026-03-31'
  )
ON CONFLICT DO NOTHING;
