import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/evernote_migration_ledger_service.dart';

void main() {
  EvernoteMigrationProgress progress(
    int source,
    int imported,
    int verified,
    int deleted,
  ) =>
      EvernoteMigrationProgress(
        batchCount: 1,
        sourceNoteCount: source,
        importedNoteCount: imported,
        verifiedNoteCount: verified,
        sourceDeletedNoteCount: deleted,
        sourceResourceCount: 0,
      );

  test('empty and partial inventories do not mark aggregate stages complete',
      () {
    for (final value in [progress(0, 0, 0, 0), progress(100, 1, 1, 1)]) {
      expect(value.importCompleted, isFalse);
      expect(value.verificationCompleted, isFalse);
      expect(value.sourceDeletionCompleted, isFalse);
    }
  });

  test('each stage completes only after all source notes and prior stages', () {
    final imported = progress(100, 100, 1, 0);
    expect(imported.importCompleted, isTrue);
    expect(imported.verificationCompleted, isFalse);
    final verified = progress(100, 100, 100, 1);
    expect(verified.verificationCompleted, isTrue);
    expect(verified.sourceDeletionCompleted, isFalse);
    expect(progress(100, 100, 100, 100).sourceDeletionCompleted, isTrue);
  });

  test('inconsistent counters cannot claim completion', () {
    expect(progress(100, 101, 100, 100).importCompleted, isFalse);
    expect(progress(100, 99, 100, 100).verificationCompleted, isFalse);
    expect(progress(100, 100, 99, 100).sourceDeletionCompleted, isFalse);
  });
}
