enum ChatHighlightTrigger { commentBurst, keywordBurst }

class ChatHighlightEvent {
  const ChatHighlightEvent({
    required this.id,
    required this.offset,
    required this.author,
    required this.message,
  });

  final String id;
  final Duration offset;
  final String author;
  final String message;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'offsetMs': offset.inMilliseconds,
        'author': author,
        'message': message,
      };

  factory ChatHighlightEvent.fromJson(Map<String, dynamic> json) {
    return ChatHighlightEvent(
      id: json['id'] as String? ?? '',
      offset: Duration(milliseconds: json['offsetMs'] as int? ?? 0),
      author: json['author'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}

class ChatHighlightSettings {
  const ChatHighlightSettings({
    this.windowSeconds = 30,
    this.minimumComments = 4,
    this.minimumKeywordEvents = 2,
    this.preRollSeconds = 10,
    this.postRollSeconds = 15,
    this.keywords = const <String>['笑', '草', 'すごい', '神', 'wow', 'lol'],
  });

  final int windowSeconds;
  final int minimumComments;
  final int minimumKeywordEvents;
  final int preRollSeconds;
  final int postRollSeconds;
  final List<String> keywords;

  ChatHighlightSettings copyWith({
    int? windowSeconds,
    int? minimumComments,
    int? minimumKeywordEvents,
    int? preRollSeconds,
    int? postRollSeconds,
    List<String>? keywords,
  }) {
    return ChatHighlightSettings(
      windowSeconds: windowSeconds ?? this.windowSeconds,
      minimumComments: minimumComments ?? this.minimumComments,
      minimumKeywordEvents: minimumKeywordEvents ?? this.minimumKeywordEvents,
      preRollSeconds: preRollSeconds ?? this.preRollSeconds,
      postRollSeconds: postRollSeconds ?? this.postRollSeconds,
      keywords: keywords ?? this.keywords,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'windowSeconds': windowSeconds,
        'minimumComments': minimumComments,
        'minimumKeywordEvents': minimumKeywordEvents,
        'preRollSeconds': preRollSeconds,
        'postRollSeconds': postRollSeconds,
        'keywords': keywords,
      };

  factory ChatHighlightSettings.fromJson(Map<String, dynamic> json) {
    final rawKeywords = json['keywords'];
    return ChatHighlightSettings(
      windowSeconds: _positiveInt(json['windowSeconds'], 30),
      minimumComments: _positiveInt(json['minimumComments'], 4),
      minimumKeywordEvents: _positiveInt(json['minimumKeywordEvents'], 2),
      preRollSeconds: _nonNegativeInt(json['preRollSeconds'], 10),
      postRollSeconds: _nonNegativeInt(json['postRollSeconds'], 15),
      keywords: rawKeywords is List
          ? rawKeywords.whereType<String>().toList(growable: false)
          : const <String>['笑', '草', 'すごい', '神', 'wow', 'lol'],
    );
  }

  static int _positiveInt(Object? value, int fallback) =>
      value is int && value > 0 ? value : fallback;

  static int _nonNegativeInt(Object? value, int fallback) =>
      value is int && value >= 0 ? value : fallback;
}

class ChatHighlightCandidate {
  const ChatHighlightCandidate({
    required this.start,
    required this.end,
    required this.peakCommentCount,
    required this.peakKeywordEventCount,
    required this.matchedKeywords,
    required this.triggers,
    required this.score,
  });

  final Duration start;
  final Duration end;
  final int peakCommentCount;
  final int peakKeywordEventCount;
  final Set<String> matchedKeywords;
  final Set<ChatHighlightTrigger> triggers;
  final double score;

  String get id => '${start.inMilliseconds}-${end.inMilliseconds}';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
        'peakCommentCount': peakCommentCount,
        'peakKeywordEventCount': peakKeywordEventCount,
        'matchedKeywords': matchedKeywords.toList()..sort(),
        'triggers': triggers.map((trigger) => trigger.name).toList()..sort(),
        'score': score,
      };
}

class ChatHighlightSnapshot {
  const ChatHighlightSnapshot({
    this.sourceTitle = '',
    this.sourceVideoUrl = '',
    this.events = const <ChatHighlightEvent>[],
    this.settings = const ChatHighlightSettings(),
  });

  final String sourceTitle;
  final String sourceVideoUrl;
  final List<ChatHighlightEvent> events;
  final ChatHighlightSettings settings;

  ChatHighlightSnapshot copyWith({
    String? sourceTitle,
    String? sourceVideoUrl,
    List<ChatHighlightEvent>? events,
    ChatHighlightSettings? settings,
  }) {
    return ChatHighlightSnapshot(
      sourceTitle: sourceTitle ?? this.sourceTitle,
      sourceVideoUrl: sourceVideoUrl ?? this.sourceVideoUrl,
      events: events ?? this.events,
      settings: settings ?? this.settings,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': 1,
        'sourceTitle': sourceTitle,
        'sourceVideoUrl': sourceVideoUrl,
        'events': events.map((event) => event.toJson()).toList(),
        'settings': settings.toJson(),
      };

  factory ChatHighlightSnapshot.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'];
    final rawSettings = json['settings'];
    return ChatHighlightSnapshot(
      sourceTitle: json['sourceTitle'] as String? ?? '',
      sourceVideoUrl: json['sourceVideoUrl'] as String? ?? '',
      events: rawEvents is List
          ? rawEvents
              .whereType<Map>()
              .map(
                (event) => ChatHighlightEvent.fromJson(
                  Map<String, dynamic>.from(event),
                ),
              )
              .where((event) => event.id.isNotEmpty)
              .take(500)
              .toList(growable: false)
          : const <ChatHighlightEvent>[],
      settings: rawSettings is Map
          ? ChatHighlightSettings.fromJson(
              Map<String, dynamic>.from(rawSettings),
            )
          : const ChatHighlightSettings(),
    );
  }
}
