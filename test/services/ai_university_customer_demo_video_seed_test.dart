import 'dart:io';

import 'package:test/test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260813222846_seed_video-codex-customer-demo_ai_university.sql';

  test(
    'Codex customer demo video is seeded as active AI university content',
    () {
      final sql = File(migrationPath).readAsStringSync();

      expect(sql, contains("'openai'"));
      expect(sql, contains("'video_codex_customer_demo'"));
      expect(sql, contains('https://www.youtube.com/watch?v=SEWi2zKhIN8'));
      expect(sql, contains('ON CONFLICT (provider, category) DO UPDATE'));
      expect(sql, contains('is_active = EXCLUDED.is_active'));
    },
  );
}
