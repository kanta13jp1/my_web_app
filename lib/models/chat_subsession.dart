import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ChatSubsessionMessage {
  const ChatSubsessionMessage({
    required this.role,
    required this.content,
    this.attachmentName,
  });

  final String role;
  final String content;
  final String? attachmentName;

  factory ChatSubsessionMessage.fromJson(Map<String, dynamic> json) {
    final rawAttachment = json['attachment_name']?.toString().trim() ?? '';
    return ChatSubsessionMessage(
      role: (json['role'] ?? 'assistant').toString(),
      content: (json['content'] ?? '').toString(),
      attachmentName: rawAttachment.isEmpty ? null : rawAttachment,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'role': role,
      'content': content,
      if (attachmentName != null) 'attachment_name': attachmentName,
    };
  }
}

class ChatSubsession {
  const ChatSubsession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.parentSessionId,
    this.inheritedContextIds = const <String>[],
    this.inheritedContextTitles = const <String>[],
    this.messages = const <ChatSubsessionMessage>[],
  });

  final String id;
  final String title;
  final String? parentSessionId;
  final List<String> inheritedContextIds;
  final List<String> inheritedContextTitles;
  final List<ChatSubsessionMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isChildSession =>
      parentSessionId != null && parentSessionId!.trim().isNotEmpty;

  ChatSubsession copyWith({
    String? title,
    List<String>? inheritedContextIds,
    List<String>? inheritedContextTitles,
    List<ChatSubsessionMessage>? messages,
    DateTime? updatedAt,
  }) {
    return ChatSubsession(
      id: id,
      title: title ?? this.title,
      parentSessionId: parentSessionId,
      inheritedContextIds: inheritedContextIds ?? this.inheritedContextIds,
      inheritedContextTitles:
          inheritedContextTitles ?? this.inheritedContextTitles,
      messages: messages ?? this.messages,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ChatSubsession.fromJson(Map<String, dynamic> json) {
    final parentRaw = json['parent_session_id']?.toString().trim() ?? '';
    final ctxIds =
        (json['inherited_context_ids'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => e.toString())
            .toList(growable: false);
    final ctxTitles = (json['inherited_context_titles'] as List<dynamic>? ??
            const <dynamic>[])
        .map((e) => e.toString())
        .toList(growable: false);
    final msgs = (json['messages'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (m) => ChatSubsessionMessage.fromJson(
            Map<String, dynamic>.from(m),
          ),
        )
        .toList(growable: false);
    final created = DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final updated =
        DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? created;

    return ChatSubsession(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'セッション').toString(),
      parentSessionId: parentRaw.isEmpty ? null : parentRaw,
      inheritedContextIds: ctxIds,
      inheritedContextTitles: ctxTitles,
      messages: msgs,
      createdAt: created,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      if (parentSessionId != null) 'parent_session_id': parentSessionId,
      'inherited_context_ids': inheritedContextIds,
      'inherited_context_titles': inheritedContextTitles,
      'messages': messages.map((m) => m.toJson()).toList(growable: false),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

class ChatSubsessionStore {
  static const String defaultPrefsKey = 'chat_subsessions_v1';
  static const int maxRetainedSessions = 30;

  final String prefsKey;

  const ChatSubsessionStore({this.prefsKey = defaultPrefsKey});

  ChatSubsession createChildSubsession({
    required ChatSubsession parent,
    String? title,
    int childOrdinal = 1,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now().toUtc();
    final trimmed = title?.trim() ?? '';
    final resolvedTitle =
        trimmed.isNotEmpty ? trimmed : 'サブセッション #$childOrdinal';
    return ChatSubsession(
      id: '${parent.id}_sub_${childOrdinal}_${timestamp.microsecondsSinceEpoch}',
      title: resolvedTitle,
      parentSessionId: parent.id,
      inheritedContextIds: List<String>.from(parent.inheritedContextIds),
      inheritedContextTitles: List<String>.from(parent.inheritedContextTitles),
      messages: List<ChatSubsessionMessage>.from(parent.messages),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  Future<List<ChatSubsession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <ChatSubsession>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <ChatSubsession>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => ChatSubsession.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <ChatSubsession>[];
    }
  }

  Future<void> saveSessions(List<ChatSubsession> sessions) async {
    final trimmed = sessions.take(maxRetainedSessions).toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefsKey,
      jsonEncode(trimmed.map((s) => s.toJson()).toList(growable: false)),
    );
  }
}
