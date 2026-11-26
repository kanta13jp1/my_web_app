import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/note_wiki_link_service.dart';

void main() {
  group('NoteWikiLinkService extraction and resolution', () {
    test('extractWikiLinks ignores code blocks and inline code and deduplicates', () {
      const md = '''
参照: [[ロードマップ]] と [[戦略メモ|戦略]] と [[  ロードマップ  ]]。
インラインコード `[[無視されるリンク]]`
```
[[コード内も無視]]
```
''';
      final links = NoteWikiLinkService.extractWikiLinks(md);
      expect(links.length, 2);
      expect(links[0].targetTitle, 'ロードマップ');
      expect(links[0].displayLabel, 'ロードマップ');
      expect(links[1].targetTitle, '戦略メモ');
      expect(links[1].alias, '戦略');
      expect(links[1].displayLabel, '戦略');
    });

    test('resolveLink matches normalized titles and excludes current note', () {
      const notes = <NoteSummary>[
        NoteSummary(id: '1', title: ' 週間レビュー ', content: ''),
        NoteSummary(id: '2', title: '設計メモ', content: '[[週間レビュー]]'),
      ];
      final hit = NoteWikiLinkService.resolveLink('週間レビュー', notes);
      expect(hit?.id, '1');
      expect(
        NoteWikiLinkService.resolveLink('週間レビュー', notes, excludeNoteId: '1'),
        isNull,
      );
    });

    test('findBacklinks discovers referencing notes and snippets', () {
      const notes = <NoteSummary>[
        NoteSummary(id: '1', title: '設計メモ', content: '親ページ'),
        NoteSummary(
          id: '2',
          title: '会議録',
          content: '前提として [[設計メモ|設計]] を確認する。',
        ),
        NoteSummary(id: '3', title: '日記', content: '無関係な内容'),
      ];

      final backlinks = NoteWikiLinkService.findBacklinks(
        currentNoteTitle: '設計メモ',
        allNotes: notes,
        currentNoteId: '1',
      );
      expect(backlinks.length, 1);
      expect(backlinks.first.sourceNoteId, '2');
      expect(backlinks.first.sourceTitle, '会議録');
      expect(backlinks.first.snippet, contains('[[設計メモ|設計]]'));
    });

    test('replaceWikiLinksWithMarkdownLinks preserves code spans', () {
      const md = '詳細は [[設計メモ|こちら]] と `[[そのまま]]`';
      final replaced = NoteWikiLinkService.replaceWikiLinksWithMarkdownLinks(
        md,
      );
      expect(
        replaced,
        '詳細は [こちら](wikilink://%E8%A8%AD%E8%A8%88%E3%83%A1%E3%83%A2) と `[[そのまま]]`',
      );
    });
  });
}
