/// チャット/プロンプトメッセージの出所種別 (#2682)。
enum ChatMessageOriginType {
  userInput,
  mcpSampling,
  assistantResponse,
  systemNotice,
}

/// MCP `sampling/createMessage` 等の出所情報を保持するモデル (#2682)。
class ChatMessageOrigin {
  final ChatMessageOriginType type;
  final String sourceServer;
  final String? toolName;
  final String? rpcMethod;

  const ChatMessageOrigin({
    required this.type,
    this.sourceServer = '',
    this.toolName,
    this.rpcMethod,
  });

  const ChatMessageOrigin.user()
      : type = ChatMessageOriginType.userInput,
        sourceServer = 'user',
        toolName = null,
        rpcMethod = null;

  const ChatMessageOrigin.mcpSampling({
    required this.sourceServer,
    this.toolName,
    this.rpcMethod = 'sampling/createMessage',
  }) : type = ChatMessageOriginType.mcpSampling;

  bool get isMcpSampling => type == ChatMessageOriginType.mcpSampling;

  String get displayBadgeLabel => switch (type) {
        ChatMessageOriginType.userInput => 'ユーザー入力',
        ChatMessageOriginType.mcpSampling => 'MCP Sampling要求',
        ChatMessageOriginType.assistantResponse => 'AI応答',
        ChatMessageOriginType.systemNotice => 'システム通知',
      };
}
