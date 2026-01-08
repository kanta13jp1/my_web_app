import 'package:uuid/uuid.dart';

class BoardMeetingLog {
  final String id;
  final String topic;
  final String? conclusion;
  final DateTime createdAt;
  final List<BoardMessage> messages;

  BoardMeetingLog({
    required this.id,
    required this.topic,
    this.conclusion,
    required this.createdAt,
    required this.messages,
  });

  factory BoardMeetingLog.fromMap(Map<String, dynamic> map) {
    return BoardMeetingLog(
      id: map['id'] ?? const Uuid().v4(),
      topic: map['topic'] ?? '',
      conclusion: map['conclusion'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      messages: map['messages'] != null
          ? (map['messages'] as List)
              .map((e) => BoardMessage.fromMap(e))
              .toList()
          : [],
    );
  }
}

class BoardMessage {
  final String id;
  final String speakerName;
  final String role;
  final String content;
  final DateTime timestamp;

  BoardMessage({
    required this.id,
    required this.speakerName,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory BoardMessage.fromMap(Map<String, dynamic> map) {
    return BoardMessage(
      id: map['id'] ?? const Uuid().v4(),
      speakerName: map['speaker_name'] ?? 'Unknown',
      role: map['role'] ?? 'Member',
      content: map['content'] ?? '',
      timestamp: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }
}
