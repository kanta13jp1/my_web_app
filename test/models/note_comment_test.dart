import 'package:flutter_test/flutter_test.dart';

import 'package:my_web_app/models/user_profile.dart';

void main() {
  test('NoteComment.fromJson accepts numeric note id fields', () {
    final comment = NoteComment.fromJson(<String, dynamic>{
      'id': 123,
      'note_id': 456,
      'user_id': 789,
      'content': 'hello',
      'created_at': '2026-04-23T10:00:00.000Z',
      'updated_at': '2026-04-23T10:05:00.000Z',
      'user_display_name': 'Codex',
      'user_avatar_url': 'https://example.com/avatar.png',
    });

    expect(comment.id, '123');
    expect(comment.noteId, '456');
    expect(comment.userId, '789');
    expect(comment.content, 'hello');
    expect(comment.userDisplayName, 'Codex');
    expect(comment.userAvatarUrl, 'https://example.com/avatar.png');
  });
}
