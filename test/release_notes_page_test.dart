import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/release_notes_page.dart';

void main() {
  testWidgets('ReleaseNotesPage renders version-specific notes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReleaseNotesPage(
          initialDocument: ReleaseNotesDocument(
            generatedAt: '2026-05-03T00:00:00Z',
            current: ReleaseNoteVersion(
              version: '1.0.1453',
              build: '3986',
              date: '2026-05-03',
              category: 'feature',
              summary: 'バージョンごとの変更点を確認できます。',
            ),
            versions: <ReleaseNoteVersion>[
              ReleaseNoteVersion(
                version: '1.0.1453',
                build: '3986',
                date: '2026-05-03',
                category: 'feature',
                summary: 'バージョンごとの変更点を確認できます。',
                changes: <ReleaseNoteChange>[
                  ReleaseNoteChange(
                    category: 'feature',
                    summary: 'Release Notesページ追加',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('release_notes_current_version')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('release_notes_version_1.0.1453')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('release_notes_detail_card')), findsOneWidget);
    expect(find.text('v1.0.1453 (build 3986)'), findsWidgets);
    expect(find.text('Release Notesページ追加'), findsOneWidget);
  });
}
