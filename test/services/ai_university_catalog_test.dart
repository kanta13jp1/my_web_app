import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_university_catalog.dart';

void main() {
  test('normalizes and deduplicates provider ids', () {
    final ids = normalizedAiUniversityProviderIds([
      {'provider': ' OpenAI '},
      {'provider': 'openai'},
      {'provider': 'ANTHROPIC'},
      {'provider': ''},
      {'provider': null},
      {'provider_id': ' Google '},
    ]);

    expect(ids, ['openai', 'anthropic', 'google']);
  });

  test('live count wins and build count is a safe fallback', () {
    expect(
      aiUniversityProviderCountForDisplay(
        liveProviderCount: 351,
        buildProviderCount: 352,
      ),
      351,
    );
    expect(
      aiUniversityProviderCountForDisplay(
        liveProviderCount: 0,
        buildProviderCount: 352,
      ),
      352,
    );
    expect(
      aiUniversityProviderCountForDisplay(
        liveProviderCount: 0,
        buildProviderCount: 0,
      ),
      0,
    );
  });
}