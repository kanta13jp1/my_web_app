import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/note_tag_service.dart';

void main() {
  group('NoteTagService', () {
    test('表記を保持しつつ空タグと大文字小文字違いの重複を除く', () {
      expect(
        NoteTagService.normalize(<Object?>[
          '  Project Alpha  ',
          '',
          'project alpha',
          '日本語 タグ',
          null,
        ]),
        <String>['Project Alpha', '日本語 タグ'],
      );
    });

    test('null は空配列として扱う', () {
      expect(NoteTagService.normalize(null), isEmpty);
    });

    test('完全一致のタグ絞り込みと部分一致検索を区別する', () {
      const tags = <String>['Client/Acme', '重要'];

      expect(NoteTagService.containsTag(tags, 'client/acme'), isTrue);
      expect(NoteTagService.containsTag(tags, 'client'), isFalse);
      expect(NoteTagService.containsSearch(tags, 'acm'), isTrue);
    });

    test('複数行からタグを大文字小文字無視で収集して並べる', () {
      final rows = <Map<String, dynamic>>[
        <String, dynamic>{
          'tags': <String>['Work', '重要'],
        },
        <String, dynamic>{
          'tags': <String>['work', 'Archive'],
        },
      ];

      expect(NoteTagService.collectFromRows(rows), <String>[
        'Archive',
        'Work',
        '重要',
      ]);
    });
  });
}
