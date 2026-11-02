import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

import {
  AiAssistantChatError,
  type AiAssistantChatStore,
  type AiAssistantHistoryMessage,
} from "./chat.ts";

type UnknownRecord = Record<string, unknown>;

export function createSupabaseAiAssistantChatStore(
  client: SupabaseClient,
): AiAssistantChatStore {
  return {
    async getOwnedConversation(userId, conversationId) {
      const { data, error } = await client.from("user_conversations")
        .select("id")
        .eq("id", conversationId)
        .eq("user_id", userId)
        .maybeSingle();
      if (error) throw storeError("conversation read");
      const id = readString(asRecord(data)?.id);
      return id ? { id } : null;
    },

    async createConversation(input) {
      const { data, error } = await client.from("user_conversations")
        .insert({
          user_id: input.userId,
          title: input.title,
          context: input.context,
        })
        .select("id")
        .single();
      if (error) throw storeError("conversation insert");
      const id = readString(asRecord(data)?.id);
      if (!id) throw storeError("conversation insert");
      return { id };
    },

    async loadRecentMessages(conversationId, limit) {
      const { data, error } = await client.from("conversation_messages")
        .select("role, content")
        .eq("conversation_id", conversationId)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (error) throw storeError("message history read");
      return toRecords(data).map(normalizeHistoryMessage).filter(
        (entry): entry is AiAssistantHistoryMessage => entry !== null,
      );
    },

    async insertUserMessage(input) {
      const { error } = await client.from("conversation_messages").insert({
        conversation_id: input.conversationId,
        role: "user",
        content: input.content,
        voice_used: input.voiceUsed,
      });
      if (error) throw storeError("user message insert");
    },

    async insertAssistantMessage(input) {
      const { data, error } = await client.from("conversation_messages")
        .insert({
          conversation_id: input.conversationId,
          role: "assistant",
          content: input.content,
          model: input.model,
          voice_used: false,
        })
        .select("id")
        .single();
      if (error) throw storeError("assistant message insert");
      return readString(asRecord(data)?.id) || null;
    },
  };
}

function normalizeHistoryMessage(
  value: UnknownRecord,
): AiAssistantHistoryMessage | null {
  const role = readString(value.role);
  const content = readString(value.content);
  return role && content ? { role, content } : null;
}

function asRecord(value: unknown): UnknownRecord | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as UnknownRecord
    : null;
}

function toRecords(value: unknown): UnknownRecord[] {
  return Array.isArray(value)
    ? value.map(asRecord).filter((row): row is UnknownRecord => row !== null)
    : [];
}

function readString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function storeError(operation: string): AiAssistantChatError {
  return new AiAssistantChatError(
    `AI assistant ${operation} failed`,
    500,
    "chat_store_error",
  );
}
