import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_management_ai_provider_router.dart';

void main() {
  group('AssetManagementAiProviderRouter', () {
    test('defines the four asset-management routing use cases', () {
      const router = AssetManagementAiProviderRouter(routingEnabled: true);

      for (final useCase in AssetManagementAiProviderUseCase.values) {
        final route = router.routeFor(useCase: useCase);

        expect(route.routingEnabled, true);
        expect(route.candidates.map((candidate) => candidate.providerId), [
          'anthropic',
          'openai',
          'google',
        ]);
        expect(route.candidates.map((candidate) => candidate.modelId), [
          'claude-opus-4-7',
          'gpt-5',
          'gemini-3.1-pro',
        ]);
        expect(route.providerChoiceReason, contains(useCase.id));
        expect(route.providerChoiceReason, contains('local-deterministic'));
      }
    });

    test('keeps explicit provider overrides auditable', () {
      const router = AssetManagementAiProviderRouter(routingEnabled: true);

      final route = router.routeFor(
        useCase: AssetManagementAiProviderUseCase.reconciliationHelp,
        explicitProvider: 'openai',
      );

      expect(route.candidates, hasLength(1));
      expect(route.candidates.single.providerId, 'openai');
      expect(route.candidates.single.modelId, 'gpt-5');
      expect(route.reason, contains('explicit provider override'));
    });
  });
}
