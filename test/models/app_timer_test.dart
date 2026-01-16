import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/app_timer.dart';

void main() {
  group('AppTimer', () {
    final fixedDate = DateTime(2024, 1, 1, 12, 0, 0);
    final updatedDate = DateTime(2024, 1, 2, 12, 0, 0);

    // テスト用の基本インスタンス
    final baseTimer = AppTimer(
      id: 1,
      userId: 'user_123',
      noteId: 10,
      name: 'Test Timer',
      durationSeconds: 1500,
      startedAt: fixedDate,
      completedAt: fixedDate.add(const Duration(minutes: 25)),
      status: TimerStatus.completed,
      soundNotification: true,
      browserNotification: true,
      autoSave: true,
      createdAt: fixedDate,
      updatedAt: updatedDate,
    );

    test('constructor creates instance with correct values', () {
      expect(baseTimer.id, 1);
      expect(baseTimer.userId, 'user_123');
      expect(baseTimer.status, TimerStatus.completed);
      // デフォルト値の確認（コンストラクタのデフォルト引数）
      final defaultTimer = AppTimer(
        id: 2,
        userId: 'user_2',
        name: 'Default',
        durationSeconds: 60,
        startedAt: fixedDate,
        status: TimerStatus.running,
        createdAt: fixedDate,
        updatedAt: fixedDate,
      );
      expect(defaultTimer.soundNotification, true);
      expect(defaultTimer.browserNotification, true);
      expect(defaultTimer.autoSave, false);
      expect(defaultTimer.noteId, null);
      expect(defaultTimer.completedAt, null);
    });

    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = {
          'id': 1,
          'user_id': 'user_123',
          'note_id': 10,
          'name': 'Test Timer',
          'duration_seconds': 1500,
          'started_at': fixedDate.toIso8601String(),
          'completed_at':
              fixedDate.add(const Duration(minutes: 25)).toIso8601String(),
          'status': 'completed',
          'sound_notification': true,
          'browser_notification': true,
          'auto_save': true,
          'created_at': fixedDate.toIso8601String(),
          'updated_at': updatedDate.toIso8601String(),
        };

        final timer = AppTimer.fromJson(json);

        expect(timer.id, 1);
        expect(timer.userId, 'user_123');
        expect(timer.noteId, 10);
        expect(timer.status, TimerStatus.completed);
        expect(timer.soundNotification, true);
        expect(timer.completedAt, isNotNull);
      });

      test('handles null nullable fields', () {
        final json = {
          'id': 1,
          'user_id': 'user_123',
          'note_id': null, // noteId is nullable
          'name': 'Test Timer',
          'duration_seconds': 1500,
          'started_at': fixedDate.toIso8601String(),
          'completed_at': null, // completedAt is nullable
          'status': 'running',
          'created_at': fixedDate.toIso8601String(),
          'updated_at': updatedDate.toIso8601String(),
        };

        final timer = AppTimer.fromJson(json);

        expect(timer.noteId, null);
        expect(timer.completedAt, null);
      });

      test('uses default values for missing optional booleans', () {
        final json = {
          'id': 1,
          'user_id': 'user_123',
          'name': 'Test Timer',
          'duration_seconds': 1500,
          'started_at': fixedDate.toIso8601String(),
          'status': 'running',
          'created_at': fixedDate.toIso8601String(),
          'updated_at': updatedDate.toIso8601String(),
          // sound_notification, browser_notification, auto_save are missing
        };

        final timer = AppTimer.fromJson(json);

        // ?? true / ?? false のロジック確認
        expect(timer.soundNotification, true);
        expect(timer.browserNotification, true);
        expect(timer.autoSave, false);
      });

      test('parses all enum statuses correctly', () {
        // Helper to create minimal JSON with specific status
        Map<String, dynamic> createJson(String status) => {
              'id': 1,
              'user_id': 'u',
              'name': 'n',
              'duration_seconds': 10,
              'started_at': fixedDate.toIso8601String(),
              'status': status,
              'created_at': fixedDate.toIso8601String(),
              'updated_at': fixedDate.toIso8601String(),
            };

        expect(AppTimer.fromJson(createJson('running')).status,
            TimerStatus.running);
        expect(
            AppTimer.fromJson(createJson('paused')).status, TimerStatus.paused);
        expect(AppTimer.fromJson(createJson('completed')).status,
            TimerStatus.completed);
        expect(AppTimer.fromJson(createJson('stopped')).status,
            TimerStatus.stopped);
      });

      test('fallbacks to stopped for unknown status string', () {
        final json = {
          'id': 1,
          'user_id': 'u',
          'name': 'n',
          'duration_seconds': 10,
          'started_at': fixedDate.toIso8601String(),
          'status': 'unknown_status_string', // Invalid status
          'created_at': fixedDate.toIso8601String(),
          'updated_at': fixedDate.toIso8601String(),
        };

        final timer = AppTimer.fromJson(json);
        // _statusFromString の default ケースを通る
        expect(timer.status, TimerStatus.stopped);
      });
    });

    group('toJson', () {
      test('converts all fields to map correctly', () {
        final json = baseTimer.toJson();

        expect(json['id'], 1);
        expect(json['status'], 'completed'); // _statusToString check
        expect(json['started_at'], fixedDate.toIso8601String());
        expect(json['completed_at'], isNotNull);
        expect(json['note_id'], 10);
      });

      test('handles null fields in toJson', () {
        final timer = AppTimer(
          id: 1,
          userId: 'u',
          name: 'n',
          durationSeconds: 10,
          startedAt: fixedDate,
          completedAt: null, // Null
          noteId: null, // Null
          status: TimerStatus.stopped,
          createdAt: fixedDate,
          updatedAt: fixedDate,
        );

        final json = timer.toJson();

        expect(json['completed_at'], null);
        expect(json['note_id'], null);
        expect(json['status'], 'stopped');
      });

      test('converts all enum statuses correctly', () {
        // Helper to check status string
        String getStatusString(TimerStatus status) {
          final t = baseTimer.copyWith(status: status);
          return t.toJson()['status'] as String;
        }

        expect(getStatusString(TimerStatus.running), 'running');
        expect(getStatusString(TimerStatus.paused), 'paused');
        expect(getStatusString(TimerStatus.completed), 'completed');
        expect(getStatusString(TimerStatus.stopped), 'stopped');
      });
    });

    group('copyWith', () {
      test('updates specified fields', () {
        final updated = baseTimer.copyWith(
          name: 'New Name',
          status: TimerStatus.paused,
          durationSeconds: 3000,
        );

        expect(updated.name, 'New Name');
        expect(updated.status, TimerStatus.paused);
        expect(updated.durationSeconds, 3000);
        // 他のフィールドが変わっていないことを確認
        expect(updated.id, baseTimer.id);
        expect(updated.userId, baseTimer.userId);
      });

      test('keeps original values when arguments are null', () {
        final updated = baseTimer.copyWith(
          id: null, // Should keep original
          userId: null,
          noteId: null,
          name: null,
          durationSeconds: null,
          startedAt: null,
          completedAt: null,
          status: null,
          soundNotification: null,
          browserNotification: null,
          autoSave: null,
          createdAt: null,
          updatedAt: null,
        );

        // 全てのフィールドが元の値と同じであることを確認
        expect(updated.id, baseTimer.id);
        expect(updated.userId, baseTimer.userId);
        expect(updated.noteId, baseTimer.noteId);
        expect(updated.name, baseTimer.name);
        expect(updated.durationSeconds, baseTimer.durationSeconds);
        expect(updated.startedAt, baseTimer.startedAt);
        expect(updated.completedAt, baseTimer.completedAt);
        expect(updated.status, baseTimer.status);
        expect(updated.soundNotification, baseTimer.soundNotification);
        expect(updated.browserNotification, baseTimer.browserNotification);
        expect(updated.autoSave, baseTimer.autoSave);
        expect(updated.createdAt, baseTimer.createdAt);
        expect(updated.updatedAt, baseTimer.updatedAt);
      });
    });
  });
}
