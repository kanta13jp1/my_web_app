import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/note.dart';

void main() {
  group('Note Model Tests', () {
    final now = DateTime.now();
    final sampleJson = {
      'id': 1,
      'user_id': 'user123',
      'title': 'Test Title',
      'content': 'Test content.',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'category_id': 'cat1',
      'is_favorite': true,
      'reminder_date': now.add(const Duration(days: 1)).toIso8601String(),
      'is_archived': false,
      'archived_at': null,
      'is_pinned': true,
      'capture_status': 'inbox',
      'capture_source': 'quick_inbox',
      'inbox_saved_at': now.toIso8601String(),
      'tags': <String>['Evernote', '移行済み'],
    };

    test('Note can be created from JSON', () {
      final note = Note.fromJson(sampleJson);

      expect(note.id, 1);
      expect(note.userId, 'user123');
      expect(note.title, 'Test Title');
      expect(note.content, 'Test content.');
      expect(note.isFavorite, isTrue);
      expect(note.isPinned, isTrue);
      expect(note.categoryId, 'cat1');
      expect(note.reminderDate, isNotNull);
      expect(note.isInbox, isTrue);
      expect(note.captureSource, 'quick_inbox');
      expect(note.inboxSavedAt, isNotNull);
      expect(note.tags, <String>['Evernote', '移行済み']);
    });

    test('Note can be converted to JSON', () {
      final note = Note.fromJson(sampleJson);
      final json = note.toJson();

      expect(json['id'], sampleJson['id']);
      expect(json['user_id'], sampleJson['user_id']);
      expect(json['title'], sampleJson['title']);
      expect(json['is_favorite'], sampleJson['is_favorite']);
      expect(json['is_pinned'], sampleJson['is_pinned']);
      expect(json['reminder_date'], sampleJson['reminder_date']);
      expect(json['capture_status'], sampleJson['capture_status']);
      expect(json['capture_source'], sampleJson['capture_source']);
      expect(json['inbox_saved_at'], sampleJson['inbox_saved_at']);
      expect(json['tags'], sampleJson['tags']);
    });

    test('isOverdue getter works correctly', () {
      final overdueNote = Note(
        id: 1,
        userId: 'test',
        title: 't',
        content: 'c',
        createdAt: now,
        updatedAt: now,
        reminderDate: now.subtract(const Duration(days: 1)),
      );
      final notOverdueNote = Note(
        id: 1,
        userId: 'test',
        title: 't',
        content: 'c',
        createdAt: now,
        updatedAt: now,
        reminderDate: now.add(const Duration(days: 1)),
      );
      final noReminderNote = Note(
        id: 1,
        userId: 'test',
        title: 't',
        content: 'c',
        createdAt: now,
        updatedAt: now,
      );

      expect(overdueNote.isOverdue, isTrue);
      expect(notOverdueNote.isOverdue, isFalse);
      expect(noReminderNote.isOverdue, isFalse);
    });

    test('isDueSoon getter works correctly', () {
      final dueSoonNote = Note(
        id: 1,
        userId: 'test',
        title: 't',
        content: 'c',
        createdAt: now,
        updatedAt: now,
        reminderDate: now.add(const Duration(hours: 12)),
      );
      final notDueSoonNote = Note(
        id: 1,
        userId: 'test',
        title: 't',
        content: 'c',
        createdAt: now,
        updatedAt: now,
        reminderDate: now.add(const Duration(hours: 48)),
      );
      final overdueNote = Note(
        id: 1,
        userId: 'test',
        title: 't',
        content: 'c',
        createdAt: now,
        updatedAt: now,
        reminderDate: now.subtract(const Duration(hours: 12)),
      );

      expect(dueSoonNote.isDueSoon, isTrue);
      expect(notDueSoonNote.isDueSoon, isFalse);
      expect(overdueNote.isDueSoon, isFalse);
    });

    test('shouldAutoArchive getter works correctly', () {
      final shouldArchiveNote = Note(
        id: 1,
        userId: 'test',
        title: 't',
        content: 'c',
        createdAt: now,
        updatedAt: now,
        reminderDate: now.subtract(const Duration(days: 31)),
      );
      final shouldNotArchiveNote = Note(
        id: 1,
        userId: 'test',
        title: 't',
        content: 'c',
        createdAt: now,
        updatedAt: now,
        reminderDate: now.subtract(const Duration(days: 15)),
      );
      final notOverdueNote = Note(
        id: 1,
        userId: 'test',
        title: 't',
        content: 'c',
        createdAt: now,
        updatedAt: now,
        reminderDate: now.add(const Duration(days: 1)),
      );

      expect(shouldArchiveNote.shouldAutoArchive, isTrue);
      expect(shouldNotArchiveNote.shouldAutoArchive, isFalse);
      expect(notOverdueNote.shouldAutoArchive, isFalse);
    });

    test('Note handles null values from JSON', () {
      final minimalJson = {
        'id': 2,
        'user_id': 'user456',
        'title': null,
        'content': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'category_id': null,
        'is_favorite': null,
        'reminder_date': null,
        'is_archived': null,
        'archived_at': null,
        'is_pinned': null,
      };
      final note = Note.fromJson(minimalJson);

      expect(note.title, '');
      expect(note.content, '');
      expect(note.categoryId, isNull);
      expect(note.isFavorite, isFalse);
      expect(note.reminderDate, isNull);
      expect(note.isArchived, isFalse);
      expect(note.archivedAt, isNull);
      expect(note.isPinned, isFalse);
      expect(note.captureStatus, 'organized');
      expect(note.captureSource, 'editor');
      expect(note.inboxSavedAt, isNull);
      expect(note.isInbox, isFalse);
      expect(note.tags, isEmpty);
    });
  });
}
