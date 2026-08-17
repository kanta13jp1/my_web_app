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
