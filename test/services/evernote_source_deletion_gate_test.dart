import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/evernote_migration_ledger_service.dart';

void main() {
  EvernoteMigrationItem item({
    required String status,
    int? targetNoteId = 10,
    String history = 'verified',
    String tasks = 'verified',
  }) =>
      EvernoteMigrationItem(
        id: 1,
        batchId: 1,
        sourceItemKey: 'fixture',
        targetNoteId: targetNoteId,
        status: status,
        historyStatus: history,
        sourceHistoryVersionCount: 1,
        importedHistoryVersionCount: 1,
        verifiedHistoryVersionCount: 1,
        taskStatus: tasks,
      );

  for (final status in <String>[
    'previewed',
    'importing',
    'imported',
    'failed',
    'unknown',
  ]) {
    test('$status cannot pass source deletion with verified features alone',
        () {
      expect(item(status: status).sourceDeletionGatePassed, isFalse);
    });
  }
  for (final status in <String>[
    'verified',
    'source_deleting',
    'source_deleted',
  ]) {
    test('$status requires a persisted target and both feature gates', () {
      expect(item(status: status).sourceDeletionGatePassed, isTrue);
      expect(
        item(status: status, targetNoteId: null).sourceDeletionGatePassed,
        isFalse,
      );
      expect(
        item(status: status, history: 'importing').sourceDeletionGatePassed,
        isFalse,
      );
      expect(
        item(status: status, tasks: 'pending').sourceDeletionGatePassed,
        isFalse,
      );
    });
  }
}
