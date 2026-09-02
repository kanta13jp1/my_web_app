import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_web_app/models/user_profile.dart';
import 'package:my_web_app/services/note_comments_service.dart';
import 'package:my_web_app/widgets/note_comments_panel.dart';

class _FakeNoteCommentsService implements NoteCommentsService {
  _FakeNoteCommentsService(this.comments);

  final StreamController<void> controller = StreamController<void>.broadcast();
  final List<NoteComment> comments;
  String? lastAddedContent;

  @override
  Future<NoteComment> addComment({
    required int noteId,
    required String content,
  }) async {
    lastAddedContent = content;
    final comment = NoteComment(
      id: 'comment-${comments.length + 1}',
      noteId: noteId.toString(),
      userId: 'user-1',
      content: content,
      userDisplayName: 'Codex',
      createdAt: DateTime.parse('2026-04-23T10:10:00.000Z'),
      updatedAt: DateTime.parse('2026-04-23T10:10:00.000Z'),
    );
    comments.add(comment);
    return comment;
  }

  @override
  Future<void> deleteComment({required String commentId}) async {
    comments.removeWhere((comment) => comment.id == commentId);
  }

  @override
  Future<List<NoteComment>> fetchComments({required int noteId}) async {
    return List<NoteComment>.from(comments);
  }

  @override
  Future<int> getCommentCount({required int noteId}) async {
    return comments.length;
  }

  @override
  Stream<void> watchCommentChanges({required int noteId}) => controller.stream;

  Future<void> dispose() => controller.close();
}

void main() {
  testWidgets('NoteCommentsPanel shows comments, count, and reacts to updates',
      (
    tester,
  ) async {
    final service = _FakeNoteCommentsService(<NoteComment>[
      NoteComment(
        id: 'comment-1',
        noteId: '1',
        userId: 'user-1',
        content: 'First comment',
        userDisplayName: 'Owner',
        createdAt: DateTime.parse('2026-04-23T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-04-23T10:00:00.000Z'),
      ),
      NoteComment(
        id: 'comment-2',
        noteId: '1',
        userId: 'user-2',
        content: 'Second comment',
        userDisplayName: 'Guest',
        createdAt: DateTime.parse('2026-04-23T10:05:00.000Z'),
        updatedAt: DateTime.parse('2026-04-23T10:05:00.000Z'),
      ),
    ]);
    addTearDown(service.dispose);

    int? latestCount;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 640,
            child: NoteCommentsPanel(
              noteId: 1,
              service: service,
              currentUserId: 'user-1',
              onCountChanged: (count) => latestCount = count,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('First comment'), findsOneWidget);
    expect(find.text('Second comment'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(latestCount, 2);

    await tester.enterText(find.byType(TextField), 'Fresh comment');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(service.lastAddedContent, 'Fresh comment');
    expect(find.text('Fresh comment'), findsOneWidget);
    expect(latestCount, 3);

    service.comments.add(
      NoteComment(
        id: 'comment-4',
        noteId: '1',
        userId: 'user-2',
        content: 'Realtime comment',
        userDisplayName: 'Guest',
        createdAt: DateTime.parse('2026-04-23T10:15:00.000Z'),
        updatedAt: DateTime.parse('2026-04-23T10:15:00.000Z'),
      ),
    );
    service.controller.add(null);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Realtime comment'), findsOneWidget);
    expect(latestCount, 4);
  });

  testWidgets('falls back to manual refresh after a realtime disconnect', (
    tester,
  ) async {
    final service = _FakeNoteCommentsService(<NoteComment>[]);
    addTearDown(service.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 640,
            child: NoteCommentsPanel(
              noteId: 1,
              service: service,
              currentUserId: 'user-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    service.controller.addError(
      'RealtimeSubscribeException(status: '
      'RealtimeSubscribeStatus.channelError, details: '
      'RealtimeCloseEvent(code: 1000, reason: ))',
    );
    await tester.pumpAndSettle();

    expect(find.text('手動更新'), findsOneWidget);
    expect(find.text('リアルタイム'), findsNothing);
  });
}
