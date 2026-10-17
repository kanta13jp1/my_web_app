import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String inboxCaptureStatus = 'inbox';
const String organizedCaptureStatus = 'organized';
const String inboxCaptureSource = 'quick_inbox';
const String pendingClassificationStatus = 'pending';
const String classifiedClassificationStatus = 'classified';
const String failedClassificationStatus = 'failed';

final ValueNotifier<int> inboxCaptureRevision = ValueNotifier<int>(0);

typedef InboxClassificationLauncher = Future<void> Function(int noteId);

Map<String, dynamic> buildInboxClassificationRequest(int noteId) {
  if (noteId <= 0) {
    throw ArgumentError.value(noteId, 'noteId', 'Must be a positive integer.');
  }
  return <String, dynamic>{'action': 'notes.classify', 'note_id': noteId};
}

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
    'classification_status': pendingClassificationStatus,
    'classification_category': null,
    'classification_source': null,
    'classified_at': null,
    'is_archived': false,
    'is_pinned': false,
  };
}

class InboxCaptureService {
  InboxCaptureService(
    this._supabase, {
    DateTime Function()? now,
    InboxClassificationLauncher? classificationLauncher,
  })  : _now = now ?? DateTime.now,
        _classificationLauncher = classificationLauncher;

  final SupabaseClient _supabase;
  final DateTime Function() _now;
  final InboxClassificationLauncher? _classificationLauncher;

  Future<void> requestClassification(int noteId) async {
    final request = buildInboxClassificationRequest(noteId);
    try {
      final launcher = _classificationLauncher;
      if (launcher != null) {
        await launcher(noteId);
      } else {
        await _supabase.functions.invoke(
          'ai-hub',
          body: request,
        );
      }
    } finally {
      inboxCaptureRevision.value += 1;
    }
  }

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

    final noteId = inserted is Map && inserted['id'] != null
        ? int.tryParse(inserted['id'].toString())
        : null;
    inboxCaptureRevision.value += 1;
    if (noteId != null) {
      unawaited(
        requestClassification(noteId).catchError((Object error) {
          debugPrint('Inbox classification failed for note $noteId: $error');
        }),
      );
    }
    return noteId;
  }
}
