import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/evernote_cloud_stage_service.dart';
import 'package:my_web_app/services/evernote_migration_commit_service.dart';
import 'package:my_web_app/widgets/evernote_cloud_migration_controls.dart';

void main() {
  testWidgets('shows cloud stage and transfer progress', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              EvernoteCloudStageStatus(
                progress: EvernoteCloudStageProgress(
                  state: EvernoteCloudStageState.verifying,
                  processedBytes: 50,
                  totalBytes: 100,
                ),
              ),
              EvernoteCloudTransferStatus(
                progress: EvernoteMigrationTransferProgress(
                  state: EvernoteMigrationTransferState.completed,
                  stageLabel: 'Recovery archive',
                  objectIndex: 1,
                  objectCount: 3,
                  transferredBytes: 100,
                  totalBytes: 200,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Private cloud archive: 50% · verifying'), findsOneWidget);
    expect(
      find.text(
        'Cloud transfer: 50% · Completed · Recovery archive · object 1/3',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'stacks source hierarchy fields at narrow width',
    (tester) async {
      final notebook = TextEditingController(text: 'Notebook');
      final stack = TextEditingController();
      final space = TextEditingController();
      addTearDown(notebook.dispose);
      addTearDown(stack.dispose);
      addTearDown(space.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: EvernoteSourceContextFields(
                notebookController: notebook,
                stackController: stack,
                spaceController: space,
                onChanged: () {},
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('evernote-source-context-narrow')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('evernote-source-context-wide')),
        findsNothing,
      );
      expect(find.byType(TextField), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'places optional hierarchy fields in a row at wide width',
    (tester) async {
      final notebook = TextEditingController(text: 'Notebook');
      final stack = TextEditingController();
      final space = TextEditingController();
      addTearDown(notebook.dispose);
      addTearDown(stack.dispose);
      addTearDown(space.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              child: EvernoteSourceContextFields(
                notebookController: notebook,
                stackController: stack,
                spaceController: space,
                onChanged: () {},
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('evernote-source-context-wide')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('evernote-source-context-narrow')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
