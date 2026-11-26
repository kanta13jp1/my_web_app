import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/prompt_cache_finops_service.dart';

void main() {
  group('PromptCacheFinopsService', () {
    test('buildPromptCachePrefix orders static blocks ahead of userInput', () {
      final service = PromptCacheFinopsService();

      final plan = service.buildPromptCachePrefix(
        const <PromptBlockInput>[
          PromptBlockInput(
            role: CacheBlockRole.userInput,
            content: 'User question',
            estimatedInputCount: 150,
          ),
          PromptBlockInput(
            role: CacheBlockRole.dbSchema,
            content: 'CREATE TABLE items (...);',
            estimatedInputCount: 800,
          ),
          PromptBlockInput(
            role: CacheBlockRole.systemPrompt,
            content: 'System instructions',
            estimatedInputCount: 400,
          ),
        ],
      );

      expect(plan.cacheEnabled, isTrue);
      expect(plan.staticPrefixCount, 1200);
      expect(plan.dynamicCount, 150);
      expect(plan.blocks[0].role, CacheBlockRole.systemPrompt);
      expect(plan.blocks[1].role, CacheBlockRole.dbSchema);
      expect(plan.blocks[1].cacheEphemeral, isTrue);
      expect(plan.blocks[2].role, CacheBlockRole.userInput);
      expect(plan.blocks[2].cacheEphemeral, isFalse);
    });

    test('selectDispatchMode routes non-urgent tasks to Message Batches API',
        () {
      final service = PromptCacheFinopsService();

      expect(
        service.selectDispatchMode(ExecutionUrgency.realtime),
        DispatchMode.messagesApi,
      );
      expect(
        service.selectDispatchMode(ExecutionUrgency.batchEligible),
        DispatchMode.messageBatchesApi,
      );
    });

    test('recordUsage and getSummary track cacheHitRate and batchOffloadRate',
        () {
      final service = PromptCacheFinopsService();

      service.recordUsage(
        const LlmUsageSample(
          feature: 'nightly_summary',
          dispatchMode: DispatchMode.messageBatchesApi,
          baseInputCount: 200,
          cacheReadCount: 1800,
          cacheCreationCount: 0,
          outputCount: 300,
        ),
      );
      service.recordUsage(
        const LlmUsageSample(
          feature: 'chat',
          dispatchMode: DispatchMode.messagesApi,
          baseInputCount: 500,
          cacheReadCount: 500,
          cacheCreationCount: 1000,
          outputCount: 200,
        ),
      );

      final summary = service.getSummary();
      expect(summary.totalRequests, 2);
      expect(summary.batchRequests, 1);
      expect(summary.batchOffloadRate, 0.5);
      expect(summary.totalBaseInputCount, 700);
      expect(summary.totalCacheReadCount, 2300);
      expect(summary.totalCacheCreationCount, 1000);
      expect(summary.totalOutputCount, 500);
      expect(summary.cacheHitRate, closeTo(0.575, 0.0001));
    });
  });
}
