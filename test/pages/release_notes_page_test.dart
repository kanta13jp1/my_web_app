import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/release_notes_page.dart';

void main() {
  testWidgets('ReleaseNotesPage shows current version and filters by query', (
    tester,
  ) async {
    const current = ReleaseNoteVersion(
      version: '1.2.3',
      build: '456',
      date: '2026-05-02',
      category: 'feature',
      summary: 'Feature rollout',
      links: [
        ReleaseNoteLink(
          type: 'pull_request',
          title: 'PR #1694',
          url: 'https://github.com/kanta13jp1/my_web_app/pull/1694',
        ),
      ],
      changes: [
        ReleaseNoteChange(
          category: 'feature',
          summary: 'Added release note data generation',
          links: [
            ReleaseNoteLink(
              type: 'pull_request',
              title: 'PR #1694',
              url: 'https://github.com/kanta13jp1/my_web_app/pull/1694',
            ),
          ],
        ),
      ],
    );
    const bugfix = ReleaseNoteVersion(
      version: '1.2.2',
      build: '455',
      date: '2026-05-01',
      category: 'fix',
      summary: 'Bug fix release',
      changes: [
        ReleaseNoteChange(
          category: 'fix',
          summary: 'Fixed WBS sync timeout',
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ReleaseNotesPage(
          initialDocument: ReleaseNotesDocument(
            generatedAt: '2026-05-02T00:00:00Z',
            current: current,
            versions: [current, bugfix],
          ),
        ),
      ),
    );

    expect(find.text('Release Notes'), findsOneWidget);
    expect(find.text('v1.2.3 (build 456)'), findsAtLeastNWidgets(1));
    expect(find.text('Feature rollout'), findsAtLeastNWidgets(1));
    expect(find.text('PR #1694'), findsAtLeastNWidgets(1));

    await tester.enterText(
      find.byKey(const Key('release_notes_search_field')),
      'bug',
    );
    await tester.pump();

    expect(find.text('Bug fix release'), findsOneWidget);
    expect(find.text('Fixed WBS sync timeout'), findsOneWidget);
    expect(find.text('v1.2.2 (build 455)'), findsAtLeastNWidgets(1));
  });
}
