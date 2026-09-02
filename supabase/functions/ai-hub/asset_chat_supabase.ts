import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

import {
  AssetChatActionError,
  type AssetChatHistoryRow,
  type AssetChatSnapshotRow,
  type AssetChatStore,
  type AssetChatThread,
} from "./asset_chat.ts";

type UnknownRecord = Record<string, unknown>;

export function createSupabaseAssetChatStore(
  client: SupabaseClient,
): AssetChatStore {
  return {
    async getOwnedThread(userId, threadId) {
      const { data, error } = await client.from("asset_chat_threads")
        .select("id,title,created_at,last_message_at")
        .eq("id", threadId)
        .eq("user_id", userId)
        .maybeSingle();
      if (error) throw storeError("thread read", error.message);
      return normalizeThread(data);
    },

    async createThread(userId, title, createdAt) {
      const { data, error } = await client.from("asset_chat_threads")
        .insert({
          user_id: userId,
          title,
          created_at: createdAt,
          last_message_at: createdAt,
        })
        .select("id,title,created_at,last_message_at")
        .single();
      if (error) throw storeError("thread insert", error.message);
      const thread = normalizeThread(data);
      if (!thread) throw storeError("thread insert", "missing response row");
      return thread;
    },

    async loadSnapshots(userId, limit) {
      const { data, error } = await client
        .from("asset_liability_monthly_snapshots")
        .select("month_key,payload,updated_at")
        .eq("user_id", userId)
        .neq("month_key", "global")
        .order("month_key", { ascending: false })
        .limit(limit);
      if (error) throw storeError("snapshot read", error.message);
      return toRecords(data).map(normalizeSnapshotRow).filter(
        (row): row is AssetChatSnapshotRow => row !== null,
      );
    },

    async loadRecentMessages(threadId, limit) {
      const { data, error } = await client.from("asset_chat_messages")
        .select("id,role,content,created_at")
        .eq("thread_id", threadId)
        .order("created_at", { ascending: false })
        .order("id", { ascending: false })
        .limit(limit);
      if (error) throw storeError("message history read", error.message);
      return toRecords(data).map(normalizeHistoryRow).filter(
        (row): row is AssetChatHistoryRow => row !== null,
      );
    },

    async appendExchange(threadId, exchange) {
      const { error } = await client.from("asset_chat_messages").insert([
        { thread_id: threadId, ...exchange.user },
        { thread_id: threadId, ...exchange.assistant },
      ]);
      if (error) throw storeError("message insert", error.message);
    },

    async touchThread(userId, threadId, lastMessageAt) {
      const { error } = await client.from("asset_chat_threads")
        .update({ last_message_at: lastMessageAt })
        .eq("id", threadId)
        .eq("user_id", userId);
      if (error) throw storeError("thread update", error.message);
    },
  };
}

function normalizeThread(value: unknown): AssetChatThread | null {
  const record = asRecord(value);
  if (!record) return null;
  const id = readString(record.id);
  const title = readString(record.title);
  const createdAt = readString(record.created_at);
  const lastMessageAt = readString(record.last_message_at);
  if (!id || !title || !createdAt || !lastMessageAt) return null;
  return { id, title, created_at: createdAt, last_message_at: lastMessageAt };
}

function normalizeSnapshotRow(
  value: UnknownRecord,
): AssetChatSnapshotRow | null {
  const monthKey = readString(value.month_key);
  const payload = asRecord(value.payload);
  if (!monthKey || !payload) return null;
  return {
    month_key: monthKey,
    payload,
    updated_at: readString(value.updated_at) || null,
  };
}

function normalizeHistoryRow(value: UnknownRecord): AssetChatHistoryRow | null {
  const role = readString(value.role);
  const content = readString(value.content);
  const createdAt = readString(value.created_at);
  if ((role !== "user" && role !== "assistant") || !content || !createdAt) {
    return null;
  }
  return {
    id: readString(value.id) || undefined,
    role,
    content,
    created_at: createdAt,
  };
}

function storeError(operation: string, detail: string): AssetChatActionError {
  return new AssetChatActionError(
    `asset chat ${operation} failed: ${detail || "unknown"}`,
    500,
    "assetChatStoreError",
  );
}

function readString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
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
