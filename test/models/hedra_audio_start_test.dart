import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/hedra_audio_start.dart';

void main() {
  test('parses the supported silence and crop offsets', () {
    expect(parseHedraAudioStartMs('-1000'), -1000);
    expect(parseHedraAudioStartMs('2000'), 2000);
    expect(parseHedraAudioStartMs('-30000'), hedraAudioStartMinMs);
    expect(parseHedraAudioStartMs('30000'), hedraAudioStartMaxMs);
  });

  test('rejects invalid or out-of-range values', () {
    expect(parseHedraAudioStartMs(''), isNull);
    expect(parseHedraAudioStartMs('1.5'), isNull);
    expect(parseHedraAudioStartMs('-30001'), isNull);
    expect(parseHedraAudioStartMs('30001'), isNull);
    expect(validateHedraAudioStartMs('not-a-number'), isNotNull);
  });
}
