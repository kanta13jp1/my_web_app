-- PS#2 S102: T-1 Phase51 (#231-#234) + 既存未投稿2件 dispatch + bc58b50b適用確認
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('T-1 Phase51 #231: Flutter CustomPaint Advanced dispatch',
   'CustomPaint / Canvas API / Animation / Fragment Shader 実践パターン dev.to投稿完了',
   '2026-05-03'),
  ('T-1 Phase51 #232: Supabase Webhooks Advanced dispatch',
   'Database Trigger / pg_net / pg_cron / Edge Function連携 実践パターン dev.to投稿完了',
   '2026-05-03'),
  ('T-1 Phase51 #233: Indie Dev Pricing Strategy dispatch',
   '心理的価格設定 / フリーミアム設計 / 年払い転換率改善 実践ガイド dev.to投稿完了',
   '2026-05-03'),
  ('T-1 Phase51 #234: Dart Records & Patterns Advanced dispatch',
   'Dart 3.0 Records / Patterns / Sealed Class / パターンマッチング完全ガイド dev.to投稿完了',
   '2026-05-03'),
  ('MCP AuthKit metadata blog dispatch',
   'RFC 9728 Protected Resource Metadata + WorkOS AuthKit 実装ガイド dev.to投稿完了',
   '2026-05-03'),
  ('agent-tool-policy server gate blog dispatch',
   'deny-by-default scope gate + CEO approval workflow dev.to投稿完了',
   '2026-05-03'),
  ('bc58b50b適用確認 + AI tool 2026-05 fleet新機能整理',
   'Claude Code / Codex / Gemini / Copilot 2026-05新機能を AI_FALLBACK_RUNBOOK + fleet設計に反映',
   '2026-05-03')
ON CONFLICT DO NOTHING;
