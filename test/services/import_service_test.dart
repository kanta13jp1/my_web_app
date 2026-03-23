import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/gamification_service.dart';
import 'package:my_web_app/services/import_service.dart';

void main() {
  late ImportService service;

  setUp(() {
    service = ImportService(GamificationService());
  });

  group('ImportService', () {
    test('parseNotionCsvText reads title content and tags', () {
      const csv = 'Title,Content,Tags\n'
          '"読書メモ","Notion から持ってきた本文","books,import"\n';

      final drafts = service.parseNotionCsvText(csv);

      expect(drafts, hasLength(1));
      expect(drafts.first.title, '読書メモ');
      expect(drafts.first.content, 'Notion から持ってきた本文');
      expect(drafts.first.tags, <String>['books', 'import']);
      expect(drafts.first.source, 'notion');
    });

    test('parseEvernoteEnexText strips markup and extracts tags', () {
      const enex = '''
<?xml version="1.0" encoding="UTF-8"?>
<en-export>
  <note>
    <title>Evernote メモ</title>
    <content><![CDATA[
      <en-note>
        <div>最初の行</div>
        <div><b>次の行</b></div>
      </en-note>
    ]]></content>
    <tag>archive</tag>
    <tag>ideas</tag>
  </note>
</en-export>
''';

      final drafts = service.parseEvernoteEnexText(enex);

      expect(drafts, hasLength(1));
      expect(drafts.first.title, 'Evernote メモ');
      expect(drafts.first.content, '最初の行\n次の行');
      expect(drafts.first.tags, <String>['archive', 'ideas']);
      expect(drafts.first.source, 'evernote');
    });
  });
}
