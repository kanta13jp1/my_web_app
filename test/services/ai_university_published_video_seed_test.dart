import 'dart:io';

import 'package:test/test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260813173500_seed_codex_record_replay_video.sql';

  test(
    'Codex Record & Replay video is seeded as active AI university content',
    () {
      final sql = File(migrationPath).readAsStringSync();

      expect(sql, contains("'openai'"));
      expect(sql, contains("'video_codex_record_replay'"));
      expect(sql, contains('https://www.youtube.com/watch?v=-ZxiEPqxKRY'));
      expect(sql, contains('ON CONFLICT (provider, category) DO UPDATE'));
      expect(sql, contains('is_active = EXCLUDED.is_active'));
    },
  );
}
