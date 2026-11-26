import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/markdown_block_service.dart';

void main() {
  group('MarkdownBlockService inline slash detection & templates', () {
    test(
      'detectInlineSlashTrigger matches at start, newline, and after space',
      () {
        final m1 = MarkdownBlockService.detectInlineSlashTrigger('/to', 3);
        expect(m1, isNotNull);
        expect(m1!.startOffset, 0);
        expect(m1.endOffset, 3);
        expect(m1.query, 'to');

        final m2 = MarkdownBlockService.detectInlineSlashTrigger('段落\n/', 4);
        expect(m2, isNotNull);
        expect(m2!.startOffset, 3);
        expect(m2.query, '');

        final m3 = MarkdownBlockService.detectInlineSlashTrigger('メモ /cal', 8);
        expect(m3, isNotNull);
        expect(m3!.query, 'cal');
      },
    );

    test('detectInlineSlashTrigger ignores URLs and mid-word slashes', () {
      expect(
        MarkdownBlockService.detectInlineSlashTrigger(
          'https://example.com/path',
          24,
        ),
        isNull,
      );
      expect(
        MarkdownBlockService.detectInlineSlashTrigger('foo/bar', 7),
        isNull,
      );
      expect(
        MarkdownBlockService.detectInlineSlashTrigger('/todo done', 10),
        isNull,
      );
    });

    test(
      'filterTemplates and applySlashTemplate replace command accurately',
      () {
        final filtered = MarkdownBlockService.filterTemplates('トグル');
        expect(filtered.map((t) => t.id), contains('toggle'));

        final todo = MarkdownBlockService.blockTemplates.firstWhere(
          (t) => t.id == 'todo',
        );
        const current = TextEditingValue(
          text: '今日のタスク\n/to',
          selection: TextSelection.collapsed(offset: 10),
        );
        final match = MarkdownBlockService.detectInlineSlashTrigger(
          current.text,
          current.selection.baseOffset,
        )!;
        final updated = MarkdownBlockService.applySlashTemplate(
          current,
          match,
          todo,
        );
        expect(updated.text, '今日のタスク\n- [ ] ');
        expect(updated.selection.baseOffset, updated.text.length);
      },
    );
  });

  group('MarkdownBlockService block parsing & reordering', () {
    test(
      'parseBlocks splits headings, checklists, code blocks, toggles, callouts',
      () {
        const md = '# タイトル\n\n'
            '> [!NOTE]\n'
            '> 重要なメモ\n\n'
            '<details>\n<summary>詳細</summary>\n\n隠し内容\n</details>\n\n'
            '```dart\nfinal a = 1;\n\nfinal b = 2;\n```\n\n'
            '- [ ] タスク1\n- [x] タスク2';

        final blocks = MarkdownBlockService.parseBlocks(md);
        expect(blocks.map((b) => b.type).toList(), <MarkdownBlockType>[
          MarkdownBlockType.heading1,
          MarkdownBlockType.callout,
          MarkdownBlockType.toggle,
          MarkdownBlockType.codeBlock,
          MarkdownBlockType.checklist,
        ]);
      },
    );

    test('reorderBlock preserves lossless block content across moves', () {
      const md = '# First\n\nSecond paragraph\n\n---';
      final moved = MarkdownBlockService.reorderBlock(md, 2, 0);
      expect(moved, '---\n\n# First\n\nSecond paragraph');

      final movedDown = MarkdownBlockService.reorderBlock(md, 0, 3);
      expect(movedDown, 'Second paragraph\n\n---\n\n# First');
    });

    test('splitPreviewSegments extracts callout and toggle outside fences', () {
      const md = 'Intro\n\n'
          '> [!TIP] ヒント\n'
          '> 便利な使い方\n\n'
          '<details>\n<summary>折りたたみ</summary>\n\n中身\n</details>\n\n'
          '```md\n> [!NOTE]\n> fenced\n```';

      final segments = MarkdownBlockService.splitPreviewSegments(md);
      expect(segments.map((s) => s.kind).toList(), <PreviewSegmentKind>[
        PreviewSegmentKind.markdown,
        PreviewSegmentKind.callout,
        PreviewSegmentKind.toggle,
        PreviewSegmentKind.markdown,
      ]);
      expect(segments[1].title, 'TIP');
      expect(segments[1].body, 'ヒント\n便利な使い方');
      expect(segments[2].title, '折りたたみ');
      expect(segments[2].body, '中身');
    });
  });
}
