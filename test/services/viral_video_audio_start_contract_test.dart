import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('client and every Hedra audio path forward the validated offset', () {
    final page =
        File('lib/pages/viral_ad_generator_page.dart').readAsStringSync();
    final backend = File(
      'supabase/functions/viral-video-ad-generator/index.ts',
    ).readAsStringSync();

    expect(page, contains("'audioStartMs': hedraAudioStartMs"));
    expect(backend, contains('parseHedraAudioStartMs(body.audioStartMs)'));
    expect(
      backend,
      contains('{ audioGeneration: media.audioGeneration }'),
    );
    expect(backend, contains('{ audioId: audioAssetId }'));
    expect(backend, contains('{ audioId: media.audioAssetId }'));
    expect(
      RegExp(r'withHedraAudioStartMs\(').allMatches(backend).length,
      3,
    );
  });
}
