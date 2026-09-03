import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('client and both Hedra audio paths forward the validated offset', () {
    final page =
        File('lib/pages/viral_ad_generator_page.dart').readAsStringSync();
    final backend = File(
      'supabase/functions/viral-video-ad-generator/index.ts',
    ).readAsStringSync();

    expect(page, contains("'audioStartMs': hedraAudioStartMs"));
    expect(backend, contains('parseHedraAudioStartMs(body.audioStartMs)'));
    expect(backend, contains('audio_generation: media.audioGeneration'));
    expect(backend, contains('audio_id: audioAssetId'));
    expect(
      RegExp(r'withHedraAudioStartMs\(').allMatches(backend).length,
      2,
    );
  });
}
