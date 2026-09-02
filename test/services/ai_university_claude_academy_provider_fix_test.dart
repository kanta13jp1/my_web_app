import 'dart:io';

import 'package:test/test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260828225730_fix_claude_academy_video_provider.sql';

  test('Claude Academy video is reassigned from OpenAI to Anthropic', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains("'anthropic'"));
    expect(sql, contains("provider = 'openai'"));
    expect(sql, contains("category = 'video_claude_academy_overview'"));
    expect(sql, contains('ON CONFLICT (provider, category) DO UPDATE'));
    expect(sql, contains('SET is_active = false'));
  });
}
