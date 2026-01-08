class BoardMeetingLog {
  final String? topic;
  final String? conclusion;
  final List<BoardMessage> messages;

  BoardMeetingLog({
    this.topic,
    this.conclusion,
    required this.messages,
  });

  factory BoardMeetingLog.fromJson(Map<String, dynamic> json) {
    final list = json['meeting_minutes'] as List;
    final List<BoardMessage> messagesList =
        list.map((i) => BoardMessage.fromJson(i)).toList();

    return BoardMeetingLog(
      conclusion: json['conclusion'],
      messages: messagesList,
    );
  }
}

class BoardMessage {
  final String role;
  final String name;
  final String text;

  BoardMessage({
    required this.role,
    required this.name,
    required this.text,
  });

  factory BoardMessage.fromJson(Map<String, dynamic> json) {
    return BoardMessage(
      role: json['role'] ?? '',
      name: json['name'] ?? '',
      text: json['text'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'name': name,
      'text': text,
    };
  }
}
