import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  AiAssistantChatError,
  type AiAssistantChatStore,
  handleAiAssistantChat,
} from "./chat.ts";

const CONVERSATION_ID = "6b503d2d-5068-4e6b-8eed-21ef35c22583";

class FakeStore implements AiAssistantChatStore {
  events: string[] = [];
  ownedConversation: { id: string } | null = { id: CONVERSATION_ID };

  getOwnedConversation(userId: string, conversationId: string) {
    this.events.push(`owner:${userId}:${conversationId}`);
    return Promise.resolve(this.ownedConversation);
  }

  createConversation(
    input: { userId: string; title: string; context: string },
  ) {
    this.events.push(`create:${input.userId}:${input.context}:${input.title}`);
    return Promise.resolve({ id: CONVERSATION_ID });
  }

  loadRecentMessages(conversationId: string, limit: number) {
    this.events.push(`history:${conversationId}:${limit}`);
    return Promise.resolve([
      { role: "assistant", content: "previous answer" },
      { role: "user", content: "previous question" },
    ]);
  }

  insertUserMessage(input: {
    conversationId: string;
    content: string;
    voiceUsed: boolean;
  }) {
    this.events.push(`user:${input.conversationId}:${input.voiceUsed}`);
    return Promise.resolve();
  }

  insertAssistantMessage(input: {
    conversationId: string;
    content: string;
    model: string;
  }) {
    this.events.push(`assistant:${input.conversationId}:${input.model}`);
    return Promise.resolve("message-1");
  }
}

function runChat(store: FakeStore, conversationId: string | undefined) {
  return handleAiAssistantChat({
    store,
    userId: "user-1",
    message: "continue",
    conversationId,
    model: "test-model",
    generateReply: (prompt) => {
      store.events.push(`provider:${prompt}`);
      return Promise.resolve("reply");
    },
  });
}

Deno.test("owned conversation is checked before history and writes", async () => {
  const store = new FakeStore();
  const result = await runChat(store, CONVERSATION_ID);

  assertEquals(result, {
    reply: "reply",
    conversationId: CONVERSATION_ID,
    messageId: "message-1",
  });
  assertEquals(store.events.map((event) => event.split(":")[0]), [
    "owner",
    "history",
    "user",
    "provider",
    "assistant",
  ]);
});

Deno.test("unknown conversation stops before history, writes, and provider", async () => {
  const store = new FakeStore();
  store.ownedConversation = null;

  const error = await captureChatError(() => runChat(store, CONVERSATION_ID));

  assertEquals(error.status, 404);
  assertEquals(error.code, "conversation_not_found");
  assertEquals(error.message, "conversation not found");
  assertEquals(store.events.map((event) => event.split(":")[0]), ["owner"]);
});

Deno.test("other-user conversation is indistinguishable from an unknown ID", async () => {
  const unknownStore = new FakeStore();
  unknownStore.ownedConversation = null;
  const otherUserStore = new FakeStore();
  // The user-scoped lookup returns no row for a conversation owned elsewhere.
  otherUserStore.ownedConversation = null;

  const unknown = await captureChatError(() =>
    runChat(unknownStore, CONVERSATION_ID)
  );
  const otherUser = await captureChatError(() =>
    runChat(otherUserStore, CONVERSATION_ID)
  );

  assertEquals(errorShape(otherUser), errorShape(unknown));
  assertEquals(otherUserStore.events.length, 1);
});

Deno.test("malformed conversation ID performs no database or provider work", async () => {
  const store = new FakeStore();
  const error = await captureChatError(() => runChat(store, "not-a-uuid"));

  assertEquals(error.status, 404);
  assertEquals(error.code, "conversation_not_found");
  assertEquals(store.events, []);
});

Deno.test("missing conversation ID preserves new conversation flow", async () => {
  const store = new FakeStore();
  const result = await runChat(store, undefined);

  assertEquals(result.conversationId, CONVERSATION_ID);
  assertEquals(store.events.map((event) => event.split(":")[0]), [
    "create",
    "history",
    "user",
    "provider",
    "assistant",
  ]);
});

Deno.test("chat errors retain a stable status and code", async () => {
  const error = await assertRejects(
    () =>
      handleAiAssistantChat({
        store: new FakeStore(),
        userId: "user-1",
        message: " ",
        model: "test-model",
        generateReply: () => Promise.resolve("unexpected"),
      }),
    AiAssistantChatError,
  );

  assertEquals(error.status, 400);
  assertEquals(error.code, "message_required");
});

async function captureChatError(
  callback: () => Promise<unknown>,
): Promise<AiAssistantChatError> {
  try {
    await callback();
  } catch (error) {
    if (error instanceof AiAssistantChatError) return error;
    throw error;
  }
  throw new Error("Expected AiAssistantChatError");
}

function errorShape(error: AiAssistantChatError) {
  return { status: error.status, code: error.code, message: error.message };
}
