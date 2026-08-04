import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String inboxCaptureStatus = 'inbox';
const String organizedCaptureStatus = 'organized';
const String inboxCaptureSource = 'quick_inbox';

final ValueNotifier<int> inboxCaptureRevision = ValueNotifier<int>(0);

String deriveInboxNoteTitle(String text, {int maxLength = 60}) {
  final firstLine = text
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => 'Inboxメモ');
  final normalized = firstLine.replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.runes.length <= maxLength) return normalized;
  return String.fromCharCodes(normalized.runes.take(maxLength));
}

Map<String, dynamic> buildInboxNoteInsert({
  required String userId,
  required String text,
  required DateTime savedAt,
}) {
  final content = text.trim();
  if (content.isEmpty) {
    throw ArgumentError.value(text, 'text', 'Inbox text must not be empty.');
  }

  return <String, dynamic>{
    'user_id': userId,
    'title': deriveInboxNoteTitle(content),
    'content': content,
    'tags': const <String>['inbox'],
    'capture_status': inboxCaptureStatus,
    'capture_source': inboxCaptureSource,
    'inbox_saved_at': savedAt.toUtc().toIso8601String(),
    'is_archived': false,
    'is_pinned': false,
  };
}

class InboxCaptureService {
  InboxCaptureService(this._supabase, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final SupabaseClient _supabase;
  final DateTime Function() _now;

  Future<int?> save(String text) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Inbox capture requires an authenticated user.');
    }

    final dynamic inserted = await _supabase
        .from('notes')
        .insert(
          buildInboxNoteInsert(userId: user.id, text: text, savedAt: _now()),
        )
        .select('id')
        .maybeSingle();

    inboxCaptureRevision.value += 1;
    if (inserted is Map && inserted['id'] != null) {
      return int.tryParse(inserted['id'].toString());
    }
    return null;
  }
}
