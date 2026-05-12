-- VSCode版 S23: AI大学 4層 drill-down UI Phase 5
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 4層 drill-down UI (学部/学科選択ページ)',
  'AiUniversityFacultySelectPage (10学部) + AiUniversityDepartmentSelectPage + breadcrumb/検索付きコンテンツページ / Supabase DB + fallback pattern / home card → /ai-university-faculty 遷移変更',
  '2026-05-01'
)
ON CONFLICT DO NOTHING;
