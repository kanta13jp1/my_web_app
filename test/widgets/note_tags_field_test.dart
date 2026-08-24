import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/note_tags_field.dart';

void main() {
  testWidgets('タグを追加・削除できる', (tester) async {
    var tags = <String>['既存'];

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: NoteTagsField(
              tags: tags,
              onChanged: (nextTags) {
                setState(() {
                  tags = nextTags;
                });
              },
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('note_tags_input')), '  新規  ');
    await tester.tap(find.byKey(const Key('note_tags_add_button')));
    await tester.pump();

    expect(tags, <String>['既存', '新規']);
    expect(find.text('新規'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey<String>('note_tag_chip_既存')),
        matching: find.byKey(const Key('note_tag_delete_icon')),
      ),
    );
    await tester.pump();

    expect(tags, <String>['新規']);
  });

  testWidgets('大文字小文字だけが違う重複タグは追加しない', (tester) async {
    var tags = <String>['Evernote'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteTagsField(
            tags: tags,
            onChanged: (nextTags) => tags = nextTags,
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('note_tags_input')),
      'evernote',
    );
    await tester.tap(find.byKey(const Key('note_tags_add_button')));
    await tester.pump();

    expect(tags, <String>['Evernote']);
  });
}
