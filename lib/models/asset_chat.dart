enum AssetChatMessageRole { user, assistant }

class AssetChatUsage {
  final int tokensIn;
  final int tokensOut;
  final double estimatedCostUsd;
  final String provider;
  final String model;

  const AssetChatUsage({
    required this.tokensIn,
    required this.tokensOut,
    required this.estimatedCostUsd,
    required this.provider,
    required this.model,
  });

  int get totalTokens => tokensIn + tokensOut;
}

class AssetChatMessage {
  final AssetChatMessageRole role;
  final String text;
  final AssetChatUsage? usage;

  const AssetChatMessage({required this.role, required this.text, this.usage});

  bool get isUser => role == AssetChatMessageRole.user;
}

class AssetChatResponse {
  final String threadId;
  final String threadTitle;
  final bool threadCreated;
  final String reply;
  final AssetChatUsage usage;

  const AssetChatResponse({
    required this.threadId,
    required this.threadTitle,
    required this.threadCreated,
    required this.reply,
    required this.usage,
  });
}

class AssetChatThreadSummary {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime lastMessageAt;

  const AssetChatThreadSummary({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastMessageAt,
  });

  factory AssetChatThreadSummary.fromMap(Map<String, dynamic> map) {
    return AssetChatThreadSummary(
      id: _requiredString(map, 'id'),
      title: _requiredString(map, 'title'),
      createdAt: _requiredDateTime(map, 'created_at'),
      lastMessageAt: _requiredDateTime(map, 'last_message_at'),
    );
  }
}

class AssetChatStoredMessage {
  final String id;
  final String threadId;
  final AssetChatMessageRole role;
  final String text;
  final int tokensIn;
  final int tokensOut;
  final String? model;
  final DateTime createdAt;

  const AssetChatStoredMessage({
    required this.id,
    required this.threadId,
    required this.role,
    required this.text,
    required this.tokensIn,
    required this.tokensOut,
    required this.model,
    required this.createdAt,
  });

  factory AssetChatStoredMessage.fromMap(Map<String, dynamic> map) {
    final roleValue = _requiredString(map, 'role');
    final role = switch (roleValue) {
      'user' => AssetChatMessageRole.user,
      'assistant' => AssetChatMessageRole.assistant,
      _ => throw FormatException('Unsupported asset chat role: $roleValue'),
    };
    final modelValue = map['model']?.toString().trim();
    return AssetChatStoredMessage(
      id: _requiredString(map, 'id'),
      threadId: _requiredString(map, 'thread_id'),
      role: role,
      text: _requiredString(map, 'content'),
      tokensIn: _nonNegativeInt(map['tokens_in']),
      tokensOut: _nonNegativeInt(map['tokens_out']),
      model: modelValue == null || modelValue.isEmpty ? null : modelValue,
      createdAt: _requiredDateTime(map, 'created_at'),
    );
  }

  bool get isUser => role == AssetChatMessageRole.user;
}

class AssetChatThreadPage {
  final List<AssetChatThreadSummary> items;
  final bool hasMore;

  const AssetChatThreadPage({required this.items, required this.hasMore});
}

class AssetChatMessagePage {
  final List<AssetChatStoredMessage> items;
  final bool hasMore;

  const AssetChatMessagePage({required this.items, required this.hasMore});
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key]?.toString().trim() ?? '';
  if (value.isEmpty) {
    throw FormatException('Asset chat $key is required');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> map, String key) {
  final value = _requiredString(map, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Asset chat $key must be an ISO-8601 timestamp');
  }
  return parsed;
}

int _nonNegativeInt(Object? value) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  return parsed < 0 ? 0 : parsed;
}
