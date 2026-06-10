import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class NoteInboxClassification {
  final List<String> tags;
  final String captureStatus;
  final String classificationStatus;
  final double confidence;
  final String summary;

  const NoteInboxClassification({
    required this.tags,
    required this.captureStatus,
    required this.classificationStatus,
    required this.confidence,
    required this.summary,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tags': tags,
      'capture_status': captureStatus,
      'classification_status': classificationStatus,
      'confidence': confidence,
      'summary': summary,
    };
  }
}

class NoteInboxService {
  static const captureStatusInbox = 'inbox';
  static const captureStatusOrganized = 'organized';
  static const captureSourceQuickInbox = 'quick_inbox';
  static const classificationStatusPending = 'pending';
  static const classificationStatusClassified = 'classified';

  final SupabaseClient _supabase;

  const NoteInboxService(this._supabase);

  Future<String?> quickCapture(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return null;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Login is required.');
    }

    final now = DateTime.now().toUtc();
    final title = buildInboxTitle(trimmed, now.toLocal());
    final classification = classifyText(title: title, content: trimmed);

    final dynamic inserted = await _supabase
        .from('notes')
        .insert(<String, dynamic>{
          'user_id': user.id,
          'title': title,
          'content': trimmed,
          'tags': classification.tags,
          'capture_status': captureStatusInbox,
          'capture_source': captureSourceQuickInbox,
          'classification_status': classificationStatusPending,
          'inbox_saved_at': now.toIso8601String(),
          'is_archived': false,
          'is_pinned': false,
        })
        .select('id')
        .maybeSingle();

    final noteId = inserted is Map && inserted['id'] != null
        ? inserted['id'].toString()
        : null;
    if (noteId != null) {
      unawaited(_classifyInBackground(noteId, title, trimmed));
    }
    return noteId;
  }

  Future<void> _classifyInBackground(
    String noteId,
    String title,
    String content,
  ) async {
    try {
      await _supabase.functions.invoke(
        'ai-hub',
        body: <String, dynamic>{
          'action': 'notes.classify',
          'note_id': noteId,
          'title': title,
          'content': content,
          'capture_source': captureSourceQuickInbox,
        },
      );
    } catch (_) {
      // Quick capture should stay fast; the pending status keeps retry possible.
    }
  }

  static String buildInboxTitle(String content, DateTime now) {
    final firstLine = content
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    if (firstLine.isNotEmpty) {
      return firstLine.length <= 48
          ? firstLine
          : '${firstLine.substring(0, 48)}...';
    }
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return 'Inbox $month/$day $hour:$minute';
  }

  static NoteInboxClassification classifyText({
    required String title,
    required String content,
  }) {
    final text = '$title $content'.toLowerCase();
    final tags = <String>[];

    void addTag(String tag, Iterable<String> keywords) {
      if (tags.contains(tag)) return;
      if (keywords.any(text.contains)) tags.add(tag);
    }

    addTag('task', const <String>['todo', 'task', 'deadline', 'due', 'fix']);
    addTag('meeting', const <String>['meeting', 'agenda', 'minutes', 'sync']);
    addTag('money', const <String>['invoice', 'payment', 'budget', 'cost']);
    addTag('idea', const <String>['idea', 'draft', 'concept', 'brainstorm']);
    addTag('learning', const <String>['learn', 'course', 'study', 'book']);
    addTag('contact', const <String>['call', 'email', 'dm', 'reply']);

    final compact = content.trim().replaceAll(RegExp(r'\s+'), ' ');
    final confidence = tags.isEmpty
        ? (compact.length >= 40 ? 0.55 : 0.32)
        : (0.68 + tags.length * 0.05).clamp(0.0, 0.92);
    final status = confidence >= 0.5
        ? classificationStatusClassified
        : classificationStatusPending;

    return NoteInboxClassification(
      tags: tags.take(5).toList(growable: false),
      captureStatus: captureStatusInbox,
      classificationStatus: status,
      confidence: confidence,
      summary: compact.length <= 120
          ? compact
          : '${compact.substring(0, 120)}...',
    );
  }
}
