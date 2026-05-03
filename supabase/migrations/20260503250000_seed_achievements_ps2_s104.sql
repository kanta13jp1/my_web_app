-- PS#2 S104 2026-05-03: T-1 Phase53全4弾作成+dispatch (dev.to累計243本)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'T-1 Phase53 #239: Flutter Web Performance dispatch',
    'Flutter Web Performance Optimization (CanvasKit/lazy loading/image best practices) — dev.to: https://dev.to/kanta13jp1/flutter-web-performance-optimization-canvaskit-lazy-loading-and-image-best-practices-304e',
    '2026-05-03'
  ),
  (
    'T-1 Phase53 #240: Supabase Realtime dispatch',
    'Supabase Realtime with Flutter (Postgres Changes/Presence/Broadcast) — dev.to: https://dev.to/kanta13jp1/supabase-realtime-with-flutter-postgres-changes-presence-and-broadcast-in-practice-44ko',
    '2026-05-03'
  ),
  (
    'T-1 Phase53 #241: Indie Dev Growth dispatch',
    'Indie Dev Growth Loops (Referral/Analytics/Viral Coefficient in Flutter) — dev.to: https://dev.to/kanta13jp1/indie-dev-growth-loops-referral-mechanics-analytics-and-viral-coefficient-in-flutter-38k',
    '2026-05-03'
  ),
  (
    'T-1 Phase53 #242: Dart Package Publishing dispatch',
    'Publishing a Dart Package to pub.dev (pubspec/dartdoc/Automated CI) — dev.to: https://dev.to/kanta13jp1/publishing-a-dart-package-to-pubdev-pubspec-dartdoc-and-automated-ci-3fig / dev.to累計243本',
    '2026-05-03'
  )
ON CONFLICT DO NOTHING;
