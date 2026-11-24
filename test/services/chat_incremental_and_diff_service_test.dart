import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/chat_incremental_rendering_config.dart';
import 'package:my_web_app/services/inline_text_diff_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ChatIncrementalRenderingConfig & splitter (#1359)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('persists animation style and buffer unit in SharedPreferences',
        () async {
      const config = ChatIncrementalRenderingConfig(
        enabled: false,
        animationStyle: ChatIncrementalAnimationStyle.blur,
        bufferUnit: ChatIncrementalBufferUnit.paragraph,
        chunkDelayMs: 60,
      );
      await ChatIncrementalRenderingConfig.saveToPrefs(config);
      final loaded = await ChatIncrementalRenderingConfig.loadFromPrefs();

      expect(loaded.enabled, isFalse);
      expect(loaded.animationStyle, ChatIncrementalAnimationStyle.blur);
      expect(loaded.bufferUnit, ChatIncrementalBufferUnit.paragraph);
      expect(loaded.chunkDelayMs, 60);
    });

    test('splits text by word chunks or paragraphs deterministically', () {
      const sample = 'First line\nSecond paragraph\n\nThird paragraph';
      final paragraphs = splitIncrementalBlocks(
        sample,
        ChatIncrementalBufferUnit.paragraph,
      );
      expect(paragraphs.length, 3);
      expect(paragraphs.join(), sample);

      const mixed = 'AIチャット応答テスト hello world';
      final words = splitIncrementalBlocks(
        mixed,
        ChatIncrementalBufferUnit.word,
      );
      expect(words.length, greaterThan(3));
      expect(words.join(), mixed);
    });
  });

  group('InlineTextDiffService (#2802)', () {
    test('computes inline added, deleted, and unchanged segments', () {
      final proposal = InlineTextDiffService.buildProposal(
        originalText: 'Budget 10000 yen',
        proposedText: 'Budget 12000 yen revised',
      );

      expect(proposal.hasChanges, isTrue);
      expect(proposal.deletedSegmentCount, 1);
      expect(proposal.addedSegmentCount, greaterThanOrEqualTo(1));
      expect(
        proposal.segments.any(
          (seg) =>
              seg.type == InlineDiffSegmentType.deleted &&
              seg.text.contains('10000'),
        ),
        isTrue,
      );
      expect(
        proposal.segments.any(
          (seg) =>
              seg.type == InlineDiffSegmentType.added &&
              seg.text.contains('12000'),
        ),
        isTrue,
      );
    });

    test('extracts marker and fenced diff blocks cleanly', () {
      const markerReply = '提案します:\n'
          '<<<ORIGINAL\n'
          '旧プラン: 月1回レビュー\n'
          '===\n'
          '新プラン: 週1回レビュー\n'
          '>>>PROPOSED';
      final markerProposal = InlineTextDiffService.extractProposal(markerReply);
      expect(markerProposal, isNotNull);
      expect(markerProposal!.originalText, '旧プラン: 月1回レビュー');
      expect(markerProposal.proposedText, '新プラン: 週1回レビュー');

      const fenceReply = '```diff\n'
          '-古い目標\n'
          '+新しい目標\n'
          ' 共通行\n'
          '```';
      final fenceProposal = InlineTextDiffService.extractProposal(fenceReply);
      expect(fenceProposal, isNotNull);
      expect(fenceProposal!.originalText, '古い目標\n共通行');
      expect(fenceProposal.proposedText, '新しい目標\n共通行');
    });
  });
}
