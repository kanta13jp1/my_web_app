class BoardMeetingLog {
  final String id;
  final String userId;
  final String topic;
  final String conclusion;
  final List<BoardMessage> messages;
  final DateTime createdAt;

  BoardMeetingLog({
    required this.id,
    required this.userId,
    required this.topic,
    required this.conclusion,
    required this.messages,
    required this.createdAt,
  });
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

  static BoardMessage empty() {
    return BoardMessage(
      id: '',
      speakerName: '',
      role: '',
      content: '',
      timestamp: DateTime(0),
    );
  }
}
