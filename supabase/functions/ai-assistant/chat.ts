const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface AiAssistantConversation {
  id: string;
}

export interface AiAssistantHistoryMessage {
  role: string;
  content: string;
}

export interface AiAssistantChatStore {
  getOwnedConversation(
    userId: string,
    conversationId: string,
  ): Promise<AiAssistantConversation | null>;
  createConversation(input: {
    userId: string;
    title: string;
    context: string;
  }): Promise<AiAssistantConversation>;
  loadRecentMessages(
    conversationId: string,
    limit: number,
  ): Promise<AiAssistantHistoryMessage[]>;
  insertUserMessage(input: {
    conversationId: string;
    content: string;
    voiceUsed: boolean;
  }): Promise<void>;
  insertAssistantMessage(input: {
    conversationId: string;
    content: string;
    model: string;
  }): Promise<string | null>;
}

export class AiAssistantChatError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly code: string,
  ) {
    super(message);
    this.name = "AiAssistantChatError";
  }
}

export interface AiAssistantChatResult {
  reply: string;
  conversationId: string;
  messageId: string | null;
}

export async function handleAiAssistantChat(options: {
  store: AiAssistantChatStore;
  userId: string;
  message: string;
  conversationId?: string;
  conversationContext?: string;
  voiceUsed?: boolean;
  model: string;
  generateReply: (prompt: string) => Promise<string>;
}): Promise<AiAssistantChatResult> {
  const userId = options.userId.trim();
  const message = options.message;
  let conversationId = options.conversationId?.trim() ?? "";

  if (!userId) {
    throw new AiAssistantChatError("Unauthorized", 401, "unauthorized");
  }
  if (!message.trim()) {
    throw new AiAssistantChatError(
      "message is required",
      400,
      "message_required",
    );
  }

  if (conversationId) {
    if (!UUID_PATTERN.test(conversationId)) throw conversationNotFound();
    const conversation = await options.store.getOwnedConversation(
      userId,
      conversationId,
    );
    if (!conversation) throw conversationNotFound();
    conversationId = conversation.id;
  } else {
    const conversation = await options.store.createConversation({
      userId,
      title: message.slice(0, 50),
      context: options.conversationContext ?? "general_chat",
    });
    conversationId = conversation.id;
  }

  const history = await options.store.loadRecentMessages(conversationId, 10);
  const historyText = [...history].reverse().map((entry) =>
    `[${entry.role}]: ${entry.content}`
  ).join("\n");
  const prompt = historyText
    ? `以下はこれまでの会話履歴です:\n${historyText}\n\n---\n[user]: ${message}`
    : message;

  await options.store.insertUserMessage({
    conversationId,
    content: message,
    voiceUsed: options.voiceUsed ?? false,
  });
  const reply = await options.generateReply(prompt);
  const messageId = await options.store.insertAssistantMessage({
    conversationId,
    content: reply,
    model: options.model,
  });

  return { reply, conversationId, messageId };
}

function conversationNotFound(): AiAssistantChatError {
  return new AiAssistantChatError(
    "conversation not found",
    404,
    "conversation_not_found",
  );
}
