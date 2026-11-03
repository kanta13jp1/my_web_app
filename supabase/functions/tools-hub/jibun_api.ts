// 自分API v1 — Notion Developer Platform 対抗 (2026-07-12 WEB版)
//
// 2 つの action namespace を提供する:
//   jibunapi.* — 管理系 (Supabase JWT 認証 / Flutter アプリから functions.invoke)
//     jibunapi.key.create / key.list / key.revoke
//     jibunapi.worker.register / worker.list / worker.update / worker.delete
//     jibunapi.usage
//   api.* — 外部公開系 (自分API キー `jibun_sk_...` を Authorization: Bearer で提示)
//     api.me / api.notes.list / api.notes.create / api.tasks.list
//     api.achievements.list / api.workers.list / api.workers.invoke
//
// セキュリティ: docs/MCP_AUTH_SECURITY_PRINCIPLES.md + docs/AI_DEV_PRINCIPLES.md 準拠
//   - deny-by-default: キー必須 + スコープ必須 + 未知 action は 404
//   - キーは sha256 のみ保存・平文は発行時 1 回のみ返却
//   - per-key rate limit (60/min, 2000/day, worker invoke 10/min)
//   - 全呼び出しを user_api_audit_log に記録 (trace_id + duration_ms)
//   - Worker endpoint は https 限定 + プライベート IP / メタデータ帯域を SSRF ガードで遮断
//   - Worker 呼び出しには HMAC-SHA256 署名 (X-Jibun-Signature) を付与

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export const JIBUN_API_KEY_PREFIX = "jibun_sk_";
export const JIBUN_API_SCOPES = [
  "notes.read",
  "notes.write",
  "tasks.read",
  "achievements.read",
  "workers.invoke",
] as const;
export type JibunApiScope = (typeof JIBUN_API_SCOPES)[number];

export const MAX_KEYS_PER_USER = 10;
export const MAX_WORKERS_PER_USER = 10;
export const API_RATE_LIMIT_PER_MINUTE = 60;
export const API_RATE_LIMIT_PER_DAY = 2000;
export const WORKER_INVOKE_LIMIT_PER_MINUTE = 10;
export const WORKER_RESPONSE_MAX_BYTES = 64 * 1024;
export const NOTE_TITLE_MAX_LENGTH = 200;
export const NOTE_CONTENT_MAX_LENGTH = 100_000;
const SLOW_REQUEST_THRESHOLD_MS = 5_000;
export const JIBUN_API_WEBHOOK_EVENTS = [
  "note.created",
  "note.updated",
  "note.deleted",
] as const;
export type JibunApiWebhookEvent = (typeof JIBUN_API_WEBHOOK_EVENTS)[number];
export const MAX_WEBHOOKS_PER_USER = 10;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Max-Age": "86400",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// ── 純関数ヘルパー (unit test 対象) ──────────────────────────────────────────

export function normalizeScopes(input: unknown): JibunApiScope[] | null {
  if (!Array.isArray(input)) return null;
  const allowed = new Set<string>(JIBUN_API_SCOPES);
  const out: JibunApiScope[] = [];
  for (const raw of input) {
    if (typeof raw !== "string") return null;
    const scope = raw.trim();
    if (!allowed.has(scope)) return null;
    if (!out.includes(scope as JibunApiScope)) {
      out.push(scope as JibunApiScope);
    }
  }
  return out.length > 0 ? out : null;
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/,
    "",
  );
}

export function generateApiKey(): { key: string; prefix: string } {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  const key = `${JIBUN_API_KEY_PREFIX}${base64UrlEncode(bytes)}`;
  return { key, prefix: key.slice(0, JIBUN_API_KEY_PREFIX.length + 8) };
}

export function generateSigningSecret(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return `jibun_whsec_${base64UrlEncode(bytes)}`;
}

export async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(text),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function hmacSha256Hex(
  secret: string,
  message: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(message),
  );
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// SSRF ガード: プライベート帯域 / ループバック / リンクローカル / クラウド
// メタデータへの到達を遮断する。DNS rebinding までは防げないため、Worker は
// service_role 権限を一切持たない fetch 専用経路に限定している (多層防御)。
export function isPrivateHost(hostname: string): boolean {
  const host = hostname.trim().toLowerCase().replace(/^\[|\]$/g, "");
  if (host === "" || host === "localhost" || host.endsWith(".localhost")) {
    return true;
  }
  if (host.endsWith(".local") || host.endsWith(".internal")) return true;
  if (host === "metadata.google.internal") return true;
  // IPv6
  if (host.includes(":")) {
    if (host === "::" || host === "::1") return true;
    if (/^(fc|fd)/.test(host)) return true; // unique local fc00::/7
    if (/^fe[89ab]/.test(host)) return true; // link local fe80::/10
    if (host.startsWith("::ffff:")) {
      const rest = host.slice(7);
      // dotted-decimal form (::ffff:127.0.0.1)
      if (rest.includes(".")) return isPrivateHost(rest);
      // hex-quad form (::ffff:7f00:1) — WHATWG URL canonicalizes here.
      const hex = rest.match(/^([0-9a-f]{1,4}):([0-9a-f]{1,4})$/);
      if (hex) {
        const hi = parseInt(hex[1], 16);
        const lo = parseInt(hex[2], 16);
        const v4 = `${(hi >> 8) & 0xff}.${hi & 0xff}.${(lo >> 8) & 0xff}.${
          lo & 0xff
        }`;
        return isPrivateHost(v4);
      }
      return true; // 未知の ::ffff: 形式は安全側で拒否
    }
    return false;
  }
  // IPv4 リテラル
  const ipv4 = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (ipv4) {
    const [a, b] = [Number(ipv4[1]), Number(ipv4[2])];
    if (a === 0 || a === 10 || a === 127) return true;
    if (a === 169 && b === 254) return true;
    if (a === 172 && b >= 16 && b <= 31) return true;
    if (a === 192 && b === 168) return true;
    if (a === 100 && b >= 64 && b <= 127) return true; // CGNAT 100.64/10
    if (a >= 224) return true; // multicast / reserved
    return false;
  }
  return false;
}

export function validateWorkerEndpoint(rawUrl: unknown): string | null {
  if (typeof rawUrl !== "string" || rawUrl.trim() === "") {
    return "endpoint_url is required";
  }
  let url: URL;
  try {
    url = new URL(rawUrl.trim());
  } catch {
    return "endpoint_url is not a valid URL";
  }
  if (url.protocol !== "https:") {
    return "endpoint_url must use https";
  }
  if (url.username !== "" || url.password !== "") {
    return "endpoint_url must not contain credentials";
  }
  if (isPrivateHost(url.hostname)) {
    return "endpoint_url must not point to a private or internal address";
  }
  return null;
}

// 名前解決した全 IP がプライベート帯域でないことを invoke 時に検証する。
// isPrivateHost の literal 文字列チェックは A レコードが内部 IP を指す
// ホスト名を防げないため、Deno.resolveDns が使える環境では実 IP を検査する。
// Supabase Edge Runtime で resolveDns が使えない場合は literal チェックに退避
// (= 挙動は従来どおりで悪化しない / hex バイパスは isPrivateHost 側で塞ぎ済み)。
export async function resolveHostToPrivateError(
  hostname: string,
  resolver?: (
    host: string,
    type: "A" | "AAAA",
  ) => Promise<string[]>,
): Promise<string | null> {
  const resolve = resolver ??
    ((host: string, type: "A" | "AAAA") =>
      type === "A"
        ? Deno.resolveDns(host, "A")
        : Deno.resolveDns(host, "AAAA"));
  const addresses: string[] = [];
  for (const type of ["A", "AAAA"] as const) {
    try {
      const records = await resolve(hostname, type);
      if (Array.isArray(records)) addresses.push(...records);
    } catch {
      // その type のレコードが無い / resolveDns 非対応環境 — 無視して literal 検査に退避
    }
  }
  for (const ip of addresses) {
    if (isPrivateHost(ip)) {
      return `endpoint resolves to a private address (${ip})`;
    }
  }
  return null;
}

// PostgREST .or() フィルタに埋め込む検索語のサニタイズ。
// カンマ・括弧・引用符・バックスラッシュ・ワイルドカード (% _) を除去し、
// フィルタ文法 (or 区切り / グループ化 / ilike パターン) への注入を防ぐ。
export function sanitizeSearchQuery(input: unknown): string {
  if (typeof input !== "string") return "";
  return input
    .replace(/[,()"'\\%_*]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 100);
}

// x-forwarded-for の先頭ホップが有効な IP リテラルの時のみ返す。
// inet カラムへ不正値を渡すと INSERT 全体が失敗し audit / rate limit が
// 静かに壊れるため、パースできない値は null に落とす。
export function parseInetOrNull(value: string): string | null {
  const token = value.trim();
  if (token === "") return null;
  const ipv4 = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
  if (ipv4.test(token)) {
    return token.split(".").every((o) => Number(o) <= 255) ? token : null;
  }
  // IPv6 (簡易): hex グループと :: 圧縮のみ許可
  if (/^[0-9a-fA-F:]+$/.test(token) && token.includes(":")) {
    return token;
  }
  return null;
}

export function normalizeWorkerSlug(input: unknown): string | null {
  if (typeof input !== "string") return null;
  const slug = input.trim().toLowerCase();
  return /^[a-z0-9][a-z0-9-]{1,63}$/.test(slug) ? slug : null;
}

export function slugFromName(name: string): string {
  const slug = name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 64);
  return /^[a-z0-9][a-z0-9-]{1,63}$/.test(slug) ? slug : `worker-${Date.now()}`;
}

// ── ストア (Supabase 実装 + テスト用に interface 注入) ────────────────────────

export interface ApiKeyRow {
  id: string;
  user_id: string;
  name: string;
  key_prefix: string;
  key_hash: string;
  scopes: string[];
  revoked: boolean;
  expires_at: string | null;
  last_used_at: string | null;
  created_at: string;
}

export interface WorkerRow {
  id: string;
  user_id: string;
  name: string;
  slug: string;
  description: string;
  endpoint_url: string;
  signing_secret: string;
  enabled: boolean;
  timeout_ms: number;
  invocation_count: number;
  last_invoked_at: string | null;
  created_at: string;
}

export interface AuditLogRow {
  user_id: string;
  api_key_id: string | null;
  worker_id: string | null;
  action: string;
  status: number;
  request_ip: string | null;
  duration_ms: number | null;
  trace_id: string | null;
  request_preview: string | null;
}

export interface NoteRow {
  id: number;
  title: string;
  content: string;
  created_at: string;
  updated_at: string | null;
}

export interface WebhookRow {
  id: string;
  user_id: string;
  name: string;
  endpoint_url: string;
  signing_secret: string;
  events: string[];
  enabled: boolean;
  delivery_count: number;
  last_delivered_at: string | null;
  created_at: string;
}

export interface JibunApiStore {
  countKeys(userId: string): Promise<number>;
  insertKey(
    row: Omit<ApiKeyRow, "id" | "created_at" | "last_used_at" | "revoked">,
  ): Promise<ApiKeyRow>;
  listKeys(userId: string): Promise<ApiKeyRow[]>;
  findKeyByHash(keyHash: string): Promise<ApiKeyRow | null>;
  revokeKey(userId: string, keyId: string): Promise<boolean>;
  touchKeyLastUsed(keyId: string): Promise<void>;
  countWorkers(userId: string): Promise<number>;
  insertWorker(
    row: Omit<
      WorkerRow,
      "id" | "created_at" | "invocation_count" | "last_invoked_at"
    >,
  ): Promise<WorkerRow>;
  listWorkers(userId: string): Promise<WorkerRow[]>;
  findWorkerBySlug(userId: string, slug: string): Promise<WorkerRow | null>;
  updateWorker(
    userId: string,
    workerId: string,
    patch: Partial<
      Pick<
        WorkerRow,
        "name" | "description" | "endpoint_url" | "enabled" | "timeout_ms"
      >
    >,
  ): Promise<boolean>;
  deleteWorker(userId: string, workerId: string): Promise<boolean>;
  recordWorkerInvocation(workerId: string): Promise<void>;
  insertAuditLog(row: AuditLogRow): Promise<void>;
  countAuditSince(
    apiKeyId: string,
    sinceIso: string,
    actionPrefix?: string,
  ): Promise<number>;
  listAuditForUser(
    userId: string,
    limit: number,
  ): Promise<Record<string, unknown>[]>;
  listNotes(
    userId: string,
    options: { limit: number; query: string },
  ): Promise<NoteRow[]>;
  createNote(
    userId: string,
    note: { title: string; content: string },
  ): Promise<NoteRow>;
  listUserTasks(limit: number): Promise<Record<string, unknown>[]>;
  listAchievements(limit: number): Promise<Record<string, unknown>[]>;
  // Notes CRUD
  updateNote(
    userId: string,
    noteId: number,
    patch: { title?: string; content?: string },
  ): Promise<NoteRow | null>;
  deleteNote(userId: string, noteId: number): Promise<boolean>;
  // Webhooks
  countWebhooks(userId: string): Promise<number>;
  insertWebhook(
    row: Omit<
      WebhookRow,
      "id" | "created_at" | "delivery_count" | "last_delivered_at"
    >,
  ): Promise<WebhookRow>;
  listWebhooks(userId: string): Promise<WebhookRow[]>;
  findWebhookById(
    userId: string,
    webhookId: string,
  ): Promise<WebhookRow | null>;
  deleteWebhook(userId: string, webhookId: string): Promise<boolean>;
  listActiveWebhooks(userId: string, event: string): Promise<WebhookRow[]>;
  touchWebhookDelivery(webhookId: string): Promise<void>;
}

export function createSupabaseJibunApiStore(
  admin: SupabaseClient,
): JibunApiStore {
  return {
    async countKeys(userId) {
      const { count, error } = await admin
        .from("user_api_keys")
        .select("id", { count: "exact", head: true })
        .eq("user_id", userId)
        .eq("revoked", false);
      if (error) throw new Error(error.message);
      return count ?? 0;
    },
    async insertKey(row) {
      const { data, error } = await admin
        .from("user_api_keys")
        .insert(row)
        .select()
        .single();
      if (error) throw new Error(error.message);
      return data as ApiKeyRow;
    },
    async listKeys(userId) {
      const { data, error } = await admin
        .from("user_api_keys")
        .select(
          "id, user_id, name, key_prefix, key_hash, scopes, revoked, expires_at, last_used_at, created_at",
        )
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(50);
      if (error) throw new Error(error.message);
      return (data ?? []) as ApiKeyRow[];
    },
    async findKeyByHash(keyHash) {
      const { data, error } = await admin
        .from("user_api_keys")
        .select(
          "id, user_id, name, key_prefix, key_hash, scopes, revoked, expires_at, last_used_at, created_at",
        )
        .eq("key_hash", keyHash)
        .maybeSingle();
      if (error) throw new Error(error.message);
      return (data as ApiKeyRow | null) ?? null;
    },
    async revokeKey(userId, keyId) {
      const { data, error } = await admin
        .from("user_api_keys")
        .update({ revoked: true, revoked_at: new Date().toISOString() })
        .eq("id", keyId)
        .eq("user_id", userId)
        .eq("revoked", false)
        .select("id");
      if (error) throw new Error(error.message);
      return (data ?? []).length > 0;
    },
    async touchKeyLastUsed(keyId) {
      const { error } = await admin
        .from("user_api_keys")
        .update({ last_used_at: new Date().toISOString() })
        .eq("id", keyId);
      if (error) {
        console.warn(`jibun-api touchKeyLastUsed skipped: ${error.message}`);
      }
    },
    async countWorkers(userId) {
      const { count, error } = await admin
        .from("user_agent_workers")
        .select("id", { count: "exact", head: true })
        .eq("user_id", userId);
      if (error) throw new Error(error.message);
      return count ?? 0;
    },
    async insertWorker(row) {
      const { data, error } = await admin
        .from("user_agent_workers")
        .insert(row)
        .select()
        .single();
      if (error) throw new Error(error.message);
      return data as WorkerRow;
    },
    async listWorkers(userId) {
      const { data, error } = await admin
        .from("user_agent_workers")
        .select(
          "id, user_id, name, slug, description, endpoint_url, signing_secret, enabled, timeout_ms, invocation_count, last_invoked_at, created_at",
        )
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(50);
      if (error) throw new Error(error.message);
      return (data ?? []) as WorkerRow[];
    },
    async findWorkerBySlug(userId, slug) {
      const { data, error } = await admin
        .from("user_agent_workers")
        .select(
          "id, user_id, name, slug, description, endpoint_url, signing_secret, enabled, timeout_ms, invocation_count, last_invoked_at, created_at",
        )
        .eq("user_id", userId)
        .eq("slug", slug)
        .maybeSingle();
      if (error) throw new Error(error.message);
      return (data as WorkerRow | null) ?? null;
    },
    async updateWorker(userId, workerId, patch) {
      const { data, error } = await admin
        .from("user_agent_workers")
        .update(patch)
        .eq("id", workerId)
        .eq("user_id", userId)
        .select("id");
      if (error) throw new Error(error.message);
      return (data ?? []).length > 0;
    },
    async deleteWorker(userId, workerId) {
      const { data, error } = await admin
        .from("user_agent_workers")
        .delete()
        .eq("id", workerId)
        .eq("user_id", userId)
        .select("id");
      if (error) throw new Error(error.message);
      return (data ?? []).length > 0;
    },
    async recordWorkerInvocation(workerId) {
      const { data, error } = await admin
        .from("user_agent_workers")
        .select("invocation_count")
        .eq("id", workerId)
        .maybeSingle();
      if (error || !data) return;
      const { error: updateError } = await admin
        .from("user_agent_workers")
        .update({
          invocation_count: Number(data.invocation_count ?? 0) + 1,
          last_invoked_at: new Date().toISOString(),
        })
        .eq("id", workerId);
      if (updateError) {
        console.warn(
          `jibun-api recordWorkerInvocation skipped: ${updateError.message}`,
        );
      }
    },
    async insertAuditLog(row) {
      const { error } = await admin.from("user_api_audit_log").insert(row);
      if (error) {
        console.warn(`jibun-api audit insert skipped: ${error.message}`);
      }
    },
    async countAuditSince(apiKeyId, sinceIso, actionPrefix) {
      let query = admin
        .from("user_api_audit_log")
        .select("id", { count: "exact", head: true })
        .eq("api_key_id", apiKeyId)
        .gte("created_at", sinceIso);
      if (actionPrefix) {
        query = query.like("action", `${actionPrefix}%`);
      }
      const { count, error } = await query;
      if (error) {
        // fail-open (repo 慣例: rate limit 判定エラーは警告して通す。認証は別途 fail-closed)
        console.warn(`jibun-api rate limit count skipped: ${error.message}`);
        return 0;
      }
      return count ?? 0;
    },
    async listAuditForUser(userId, limit) {
      const { data, error } = await admin
        .from("user_api_audit_log")
        .select(
          "action, status, api_key_id, worker_id, duration_ms, trace_id, created_at",
        )
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (error) throw new Error(error.message);
      return (data ?? []) as Record<string, unknown>[];
    },
    async listNotes(userId, options) {
      let query = admin
        .from("notes")
        .select("id, title, content, created_at, updated_at")
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(options.limit);
      if (options.query !== "") {
        query = query.or(
          `title.ilike.%${options.query}%,content.ilike.%${options.query}%`,
        );
      }
      const { data, error } = await query;
      if (error) throw new Error(error.message);
      return (data ?? []) as NoteRow[];
    },
    async createNote(userId, note) {
      const { data, error } = await admin
        .from("notes")
        .insert({ user_id: userId, title: note.title, content: note.content })
        .select("id, title, content, created_at, updated_at")
        .single();
      if (error) throw new Error(error.message);
      return data as NoteRow;
    },
    async listUserTasks(limit) {
      const { data, error } = await admin
        .from("wbs_tasks")
        .select(
          "id, category, title, description, status, progress, priority, end_date, updated_at",
        )
        .or("instance.eq.user,owner_instance.eq.user")
        .in("status", ["pending", "in_progress", "blocked"])
        .order("end_date", { ascending: true, nullsFirst: false })
        .limit(limit);
      if (error) throw new Error(error.message);
      return (data ?? []) as Record<string, unknown>[];
    },
    async listAchievements(limit) {
      const { data, error } = await admin
        .from("development_achievements")
        .select("title, description, completed_at")
        .order("completed_at", { ascending: false })
        .limit(limit);
      if (error) throw new Error(error.message);
      return (data ?? []) as Record<string, unknown>[];
    },
    async updateNote(userId, noteId, patch) {
      const updates: Record<string, unknown> = {
        updated_at: new Date().toISOString(),
      };
      if (patch.title !== undefined) updates.title = patch.title;
      if (patch.content !== undefined) updates.content = patch.content;
      const { data, error } = await admin
        .from("notes")
        .update(updates)
        .eq("id", noteId)
        .eq("user_id", userId)
        .select("id, title, content, created_at, updated_at")
        .maybeSingle();
      if (error) throw new Error(error.message);
      return (data as NoteRow | null) ?? null;
    },
    async deleteNote(userId, noteId) {
      const { data, error } = await admin
        .from("notes")
        .delete()
        .eq("id", noteId)
        .eq("user_id", userId)
        .select("id");
      if (error) throw new Error(error.message);
      return (data ?? []).length > 0;
    },
    async countWebhooks(userId) {
      const { count, error } = await admin
        .from("user_api_webhooks")
        .select("id", { count: "exact", head: true })
        .eq("user_id", userId)
        .eq("enabled", true);
      if (error) throw new Error(error.message);
      return count ?? 0;
    },
    async insertWebhook(row) {
      const { data, error } = await admin
        .from("user_api_webhooks")
        .insert(row)
        .select()
        .single();
      if (error) throw new Error(error.message);
      return data as WebhookRow;
    },
    async listWebhooks(userId) {
      const { data, error } = await admin
        .from("user_api_webhooks")
        .select(
          "id, user_id, name, endpoint_url, signing_secret, events, enabled, delivery_count, last_delivered_at, created_at",
        )
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(50);
      if (error) throw new Error(error.message);
      return (data ?? []) as WebhookRow[];
    },
    async findWebhookById(userId, webhookId) {
      const { data, error } = await admin
        .from("user_api_webhooks")
        .select(
          "id, user_id, name, endpoint_url, signing_secret, events, enabled, delivery_count, last_delivered_at, created_at",
        )
        .eq("user_id", userId)
        .eq("id", webhookId)
        .maybeSingle();
      if (error) throw new Error(error.message);
      return (data as WebhookRow | null) ?? null;
    },
    async deleteWebhook(userId, webhookId) {
      const { data, error } = await admin
        .from("user_api_webhooks")
        .delete()
        .eq("id", webhookId)
        .eq("user_id", userId)
        .select("id");
      if (error) throw new Error(error.message);
      return (data ?? []).length > 0;
    },
    async listActiveWebhooks(userId, event) {
      const { data, error } = await admin
        .from("user_api_webhooks")
        .select("id, endpoint_url, signing_secret, events")
        .eq("user_id", userId)
        .eq("enabled", true)
        .contains("events", [event])
        .limit(10);
      if (error) {
        console.warn(`jibun-api listActiveWebhooks skipped: ${error.message}`);
        return [];
      }
      return (data ?? []) as WebhookRow[];
    },
    async touchWebhookDelivery(webhookId) {
      const { data } = await admin
        .from("user_api_webhooks")
        .select("delivery_count")
        .eq("id", webhookId)
        .maybeSingle();
      const current = Number(
        (data as Record<string, unknown> | null)?.delivery_count ?? 0,
      );
      const { error } = await admin
        .from("user_api_webhooks")
        .update({
          delivery_count: current + 1,
          last_delivered_at: new Date().toISOString(),
        })
        .eq("id", webhookId);
      if (error) {
        console.warn(
          `jibun-api touchWebhookDelivery skipped: ${error.message}`,
        );
      }
    },
  };
}

// ── ハンドラ ─────────────────────────────────────────────────────────────────

export interface JibunApiHandlerDeps {
  req: Request;
  action: string;
  body: Record<string, unknown>;
  store: JibunApiStore;
  getUserId: () => Promise<string | null>;
  workerFetch?: (
    input: string,
    init: RequestInit,
  ) => Promise<Response>;
  resolveDns?: (host: string, type: "A" | "AAAA") => Promise<string[]>;
  now?: () => Date;
}

function keyToSafeJson(row: ApiKeyRow): Record<string, unknown> {
  return {
    id: row.id,
    name: row.name,
    key_prefix: row.key_prefix,
    scopes: row.scopes,
    revoked: row.revoked,
    expires_at: row.expires_at,
    last_used_at: row.last_used_at,
    created_at: row.created_at,
  };
}

function workerToSafeJson(row: WorkerRow): Record<string, unknown> {
  return {
    id: row.id,
    name: row.name,
    slug: row.slug,
    description: row.description,
    endpoint_url: row.endpoint_url,
    enabled: row.enabled,
    timeout_ms: row.timeout_ms,
    invocation_count: row.invocation_count,
    last_invoked_at: row.last_invoked_at,
    created_at: row.created_at,
  };
}

function webhookToSafeJson(row: WebhookRow): Record<string, unknown> {
  return {
    id: row.id,
    name: row.name,
    endpoint_url: row.endpoint_url,
    events: row.events,
    enabled: row.enabled,
    delivery_count: row.delivery_count,
    last_delivered_at: row.last_delivered_at,
    created_at: row.created_at,
  };
}

// Outbound webhook dispatch — fire-and-forget / best-effort.
// 呼び出し側は await しない。Supabase Edge Functions では Response 返却後に
// バックグラウンド Promise が完了するか保証されないが、MVP では best-effort とする。
function fireWebhooks(
  store: JibunApiStore,
  userId: string,
  event: JibunApiWebhookEvent,
  payload: Record<string, unknown>,
  fetcher?: (input: string, init: RequestInit) => Promise<Response>,
): void {
  void (async () => {
    let webhooks: WebhookRow[];
    try {
      webhooks = await store.listActiveWebhooks(userId, event);
    } catch {
      return;
    }
    for (const wh of webhooks) {
      const body = JSON.stringify({
        event,
        data: payload,
        delivered_at: new Date().toISOString(),
      });
      const sig = await hmacSha256Hex(wh.signing_secret, body);
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 5_000);
      try {
        await (fetcher ?? fetch)(wh.endpoint_url, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Jibun-Webhook-Event": event,
            "X-Jibun-Webhook-Signature": `sha256=${sig}`,
            "User-Agent": "jibun-webhook/1.0",
          },
          body,
          signal: controller.signal,
          redirect: "error",
        });
        await store.touchWebhookDelivery(wh.id);
      } catch {
        // best-effort: delivery failures are silent
      } finally {
        clearTimeout(timer);
      }
    }
  })();
}

function clampLimit(raw: unknown, fallback: number, max: number): number {
  const value = Number(raw ?? fallback);
  if (!Number.isFinite(value)) return fallback;
  return Math.min(Math.max(Math.floor(value), 1), max);
}

function requestIp(req: Request): string | null {
  const forwarded = req.headers.get("x-forwarded-for") ?? "";
  const first = forwarded.split(",")[0]?.trim() ?? "";
  return parseInetOrNull(first);
}

// Worker レスポンス body を最大 maxBytes バイトまでストリーム読みして打ち切る。
// text() で全体をメモリに載せると悪意ある Worker が数百MB を返してメモリを
// 枯渇させられるため、上限に達したらリーダーを cancel する。
async function readBoundedBody(
  response: Response,
  maxBytes: number,
): Promise<{ text: string; truncated: boolean }> {
  if (!response.body) {
    const raw = await response.text();
    const encoded = new TextEncoder().encode(raw);
    if (encoded.length <= maxBytes) return { text: raw, truncated: false };
    return {
      text: new TextDecoder().decode(encoded.slice(0, maxBytes)),
      truncated: true,
    };
  }
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  let truncated = false;
  try {
    while (total < maxBytes) {
      const { done, value } = await reader.read();
      if (done) break;
      if (!value) continue;
      const remaining = maxBytes - total;
      if (value.length > remaining) {
        chunks.push(value.slice(0, remaining));
        total += remaining;
        truncated = true;
        break;
      }
      chunks.push(value);
      total += value.length;
    }
    // 上限到達後に残りが存在するか確認 (truncated フラグ精度向上)
    if (total >= maxBytes && !truncated) {
      const { done } = await reader.read();
      if (!done) truncated = true;
    }
  } finally {
    await reader.cancel().catch(() => {});
  }
  const merged = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    merged.set(chunk, offset);
    offset += chunk.length;
  }
  return { text: new TextDecoder().decode(merged), truncated };
}

export async function handleJibunApiAction(
  deps: JibunApiHandlerDeps,
): Promise<Response | null> {
  const { action } = deps;
  if (action.startsWith("jibunapi.")) {
    return await handleManagementAction(deps);
  }
  if (action.startsWith("api.")) {
    return await handleExternalApiAction(deps);
  }
  return null;
}

// ── 管理系 (Supabase JWT) ────────────────────────────────────────────────────

async function handleManagementAction(
  deps: JibunApiHandlerDeps,
): Promise<Response> {
  const { action, body, store } = deps;
  const userId = await deps.getUserId();
  if (!userId) return json({ error: "Unauthorized" }, 401);

  const audit = (
    extra: Partial<AuditLogRow>,
    status: number,
  ): Promise<void> =>
    store.insertAuditLog({
      user_id: userId,
      api_key_id: null,
      worker_id: null,
      action,
      status,
      request_ip: requestIp(deps.req),
      duration_ms: null,
      trace_id: null,
      request_preview: null,
      ...extra,
    });

  switch (action) {
    case "jibunapi.key.create": {
      const name = String(body.name ?? "").trim();
      if (name === "" || name.length > 100) {
        return json({ error: "name is required (1-100 chars)" }, 400);
      }
      const scopes = normalizeScopes(body.scopes);
      if (!scopes) {
        return json({
          error: "scopes must be a non-empty array of allowed scopes",
          allowed_scopes: JIBUN_API_SCOPES,
        }, 400);
      }
      const activeKeys = await store.countKeys(userId);
      if (activeKeys >= MAX_KEYS_PER_USER) {
        return json({
          error:
            `key limit reached (max ${MAX_KEYS_PER_USER}). Revoke an existing key first.`,
        }, 409);
      }
      let expiresAt: string | null = null;
      if (body.expires_in_days !== undefined && body.expires_in_days !== null) {
        const days = Number(body.expires_in_days);
        if (!Number.isFinite(days) || days < 1 || days > 365) {
          return json({ error: "expires_in_days must be 1-365" }, 400);
        }
        expiresAt = new Date(Date.now() + days * 86_400_000).toISOString();
      }
      const { key, prefix } = generateApiKey();
      const keyHash = await sha256Hex(key);
      const row = await store.insertKey({
        user_id: userId,
        name,
        key_prefix: prefix,
        key_hash: keyHash,
        scopes,
        expires_at: expiresAt,
      });
      await audit({}, 201);
      return json({
        success: true,
        // 平文キーはこのレスポンスでのみ返却する。以降は取得不可 (sha256 のみ保存)。
        api_key: key,
        key: keyToSafeJson(row),
        warning:
          "このキーは今回のみ表示されます。安全な場所に保管してください。",
      }, 201);
    }
    case "jibunapi.key.list": {
      const keys = await store.listKeys(userId);
      return json({ success: true, keys: keys.map(keyToSafeJson) });
    }
    case "jibunapi.key.revoke": {
      const keyId = String(body.id ?? "").trim();
      if (keyId === "") return json({ error: "id is required" }, 400);
      const revoked = await store.revokeKey(userId, keyId);
      if (!revoked) return json({ error: "key not found" }, 404);
      await audit({ api_key_id: keyId }, 200);
      return json({ success: true });
    }
    case "jibunapi.worker.register": {
      const name = String(body.name ?? "").trim();
      if (name === "" || name.length > 100) {
        return json({ error: "name is required (1-100 chars)" }, 400);
      }
      const endpointError = validateWorkerEndpoint(body.endpoint_url);
      if (endpointError) return json({ error: endpointError }, 400);
      const slug = body.slug !== undefined && body.slug !== null &&
          String(body.slug).trim() !== ""
        ? normalizeWorkerSlug(body.slug)
        : slugFromName(name);
      if (!slug) {
        return json({
          error:
            "slug must be 2-64 chars of lowercase letters, digits, hyphens",
        }, 400);
      }
      const workerCount = await store.countWorkers(userId);
      if (workerCount >= MAX_WORKERS_PER_USER) {
        return json({
          error:
            `worker limit reached (max ${MAX_WORKERS_PER_USER}). Delete an existing worker first.`,
        }, 409);
      }
      const existing = await store.findWorkerBySlug(userId, slug);
      if (existing) {
        return json({ error: `worker slug already exists: ${slug}` }, 409);
      }
      const timeoutMs = clampLimit(body.timeout_ms, 10_000, 15_000);
      const signingSecret = generateSigningSecret();
      const row = await store.insertWorker({
        user_id: userId,
        name,
        slug,
        description: String(body.description ?? "").slice(0, 500),
        endpoint_url: String(body.endpoint_url).trim(),
        signing_secret: signingSecret,
        enabled: true,
        timeout_ms: Math.max(timeoutMs, 1_000),
      });
      await audit({ worker_id: row.id }, 201);
      return json({
        success: true,
        worker: workerToSafeJson(row),
        // 署名シークレットはこのレスポンスでのみ返却する。
        signing_secret: signingSecret,
        warning:
          "signing_secret は今回のみ表示されます。Worker 側での署名検証に使用してください。",
      }, 201);
    }
    case "jibunapi.worker.list": {
      const workers = await store.listWorkers(userId);
      return json({ success: true, workers: workers.map(workerToSafeJson) });
    }
    case "jibunapi.worker.update": {
      const workerId = String(body.id ?? "").trim();
      if (workerId === "") return json({ error: "id is required" }, 400);
      const patch: Partial<
        Pick<
          WorkerRow,
          "name" | "description" | "endpoint_url" | "enabled" | "timeout_ms"
        >
      > = {};
      if (body.name !== undefined) {
        const name = String(body.name).trim();
        if (name === "" || name.length > 100) {
          return json({ error: "name must be 1-100 chars" }, 400);
        }
        patch.name = name;
      }
      if (body.description !== undefined) {
        patch.description = String(body.description).slice(0, 500);
      }
      if (body.endpoint_url !== undefined) {
        const endpointError = validateWorkerEndpoint(body.endpoint_url);
        if (endpointError) return json({ error: endpointError }, 400);
        patch.endpoint_url = String(body.endpoint_url).trim();
      }
      if (body.enabled !== undefined) {
        patch.enabled = body.enabled === true || body.enabled === "true";
      }
      if (body.timeout_ms !== undefined) {
        patch.timeout_ms = Math.max(
          clampLimit(body.timeout_ms, 10_000, 15_000),
          1_000,
        );
      }
      if (Object.keys(patch).length === 0) {
        return json({ error: "no updatable fields provided" }, 400);
      }
      const updated = await store.updateWorker(userId, workerId, patch);
      if (!updated) return json({ error: "worker not found" }, 404);
      await audit({ worker_id: workerId }, 200);
      return json({ success: true });
    }
    case "jibunapi.worker.delete": {
      const workerId = String(body.id ?? "").trim();
      if (workerId === "") return json({ error: "id is required" }, 400);
      const deleted = await store.deleteWorker(userId, workerId);
      if (!deleted) return json({ error: "worker not found" }, 404);
      await audit({ worker_id: workerId }, 200);
      return json({ success: true });
    }
    case "jibunapi.usage": {
      const limit = clampLimit(deps.body.limit, 50, 200);
      const entries = await store.listAuditForUser(userId, limit);
      return json({ success: true, usage: entries });
    }
    // ── Webhook 管理 (Supabase JWT 認証 / アウトバウンド Notion Webhook triggers 対抗) ──
    case "jibunapi.webhook.create": {
      const name = String(body.name ?? "").trim();
      if (name === "" || name.length > 100) {
        return json({ error: "name is required (1-100 chars)" }, 400);
      }
      const endpointError = validateWorkerEndpoint(body.endpoint_url);
      if (endpointError) return json({ error: endpointError }, 400);
      const rawEvents = Array.isArray(body.events) ? body.events : [];
      const validSet = new Set<string>(JIBUN_API_WEBHOOK_EVENTS);
      const events: string[] = rawEvents.filter(
        (e) => typeof e === "string" && validSet.has(e),
      );
      if (events.length === 0) {
        return json({
          error: "events must be a non-empty array of valid event types",
          allowed_events: JIBUN_API_WEBHOOK_EVENTS,
        }, 400);
      }
      const webhookCount = await store.countWebhooks(userId);
      if (webhookCount >= MAX_WEBHOOKS_PER_USER) {
        return json({
          error:
            `webhook limit reached (max ${MAX_WEBHOOKS_PER_USER}). Delete an existing webhook first.`,
        }, 409);
      }
      const signingSecret = generateSigningSecret();
      const row = await store.insertWebhook({
        user_id: userId,
        name,
        endpoint_url: String(body.endpoint_url).trim(),
        signing_secret: signingSecret,
        events,
        enabled: true,
      });
      await audit({}, 201);
      return json({
        success: true,
        webhook: webhookToSafeJson(row),
        // 署名シークレットはこのレスポンスでのみ返却する。
        signing_secret: signingSecret,
        warning:
          "signing_secret は今回のみ表示されます。Webhook 受信側の署名検証 (X-Jibun-Webhook-Signature) に使用してください。",
      }, 201);
    }
    case "jibunapi.webhook.list": {
      const webhooks = await store.listWebhooks(userId);
      return json({ success: true, webhooks: webhooks.map(webhookToSafeJson) });
    }
    case "jibunapi.webhook.delete": {
      const webhookId = String(body.id ?? "").trim();
      if (webhookId === "") return json({ error: "id is required" }, 400);
      const deleted = await store.deleteWebhook(userId, webhookId);
      if (!deleted) return json({ error: "webhook not found" }, 404);
      await audit({}, 200);
      return json({ success: true });
    }
    case "jibunapi.webhook.test": {
      const webhookId = String(body.id ?? "").trim();
      if (webhookId === "") return json({ error: "id is required" }, 400);
      const wh = await store.findWebhookById(userId, webhookId);
      if (!wh) return json({ error: "webhook not found" }, 404);
      const testPayload = JSON.stringify({
        event: "webhook.test",
        data: { message: "自分API からのテスト ping です。" },
        delivered_at: new Date().toISOString(),
      });
      const sig = await hmacSha256Hex(wh.signing_secret, testPayload);
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 5_000);
      let httpOk = false;
      let httpStatus = 0;
      try {
        const res = await (deps.workerFetch ?? fetch)(wh.endpoint_url, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Jibun-Webhook-Event": "webhook.test",
            "X-Jibun-Webhook-Signature": `sha256=${sig}`,
            "User-Agent": "jibun-webhook/1.0",
          },
          body: testPayload,
          signal: controller.signal,
          redirect: "error",
        });
        httpOk = res.ok;
        httpStatus = res.status;
      } catch (error) {
        const msg = controller.signal.aborted
          ? "timeout after 5s"
          : String(error).slice(0, 100);
        return json({ success: false, error: `delivery failed: ${msg}` }, 502);
      } finally {
        clearTimeout(timer);
      }
      await audit({}, 200);
      return json({ success: httpOk, webhook_response_status: httpStatus });
    }
    default:
      return json({ error: `Unknown action: ${action}` }, 400);
  }
}

// ── 外部公開系 (自分API キー) ────────────────────────────────────────────────

interface ApiKeyContext {
  key: ApiKeyRow;
}

async function authenticateApiKey(
  deps: JibunApiHandlerDeps,
): Promise<ApiKeyContext | Response> {
  const header = deps.req.headers.get("authorization") ?? "";
  const bearer = header.replace(/^Bearer\s+/i, "").trim();
  if (bearer === "" || !bearer.startsWith(JIBUN_API_KEY_PREFIX)) {
    return json({
      error: "Unauthorized: provide 'Authorization: Bearer jibun_sk_...'",
    }, 401);
  }
  const keyHash = await sha256Hex(bearer);
  const row = await deps.store.findKeyByHash(keyHash);
  if (!row) return json({ error: "Unauthorized: unknown API key" }, 401);
  if (row.revoked) return json({ error: "Unauthorized: key revoked" }, 401);
  if (row.expires_at !== null) {
    const now = deps.now ? deps.now() : new Date();
    if (new Date(row.expires_at).getTime() <= now.getTime()) {
      return json({ error: "Unauthorized: key expired" }, 401);
    }
  }
  return { key: row };
}

function requireApiScope(
  ctx: ApiKeyContext,
  scope: JibunApiScope,
): Response | null {
  if (ctx.key.scopes.includes(scope)) return null;
  return json({
    error: `Forbidden: missing scope '${scope}'`,
    granted_scopes: ctx.key.scopes,
  }, 403);
}

async function checkRateLimit(
  deps: JibunApiHandlerDeps,
  ctx: ApiKeyContext,
): Promise<Response | null> {
  const now = deps.now ? deps.now() : new Date();
  const minuteAgo = new Date(now.getTime() - 60_000).toISOString();
  const dayAgo = new Date(now.getTime() - 86_400_000).toISOString();
  const perMinute = await deps.store.countAuditSince(ctx.key.id, minuteAgo);
  if (perMinute >= API_RATE_LIMIT_PER_MINUTE) {
    return json({
      error: "rate_limited",
      limit: API_RATE_LIMIT_PER_MINUTE,
      window_seconds: 60,
    }, 429);
  }
  const perDay = await deps.store.countAuditSince(ctx.key.id, dayAgo);
  if (perDay >= API_RATE_LIMIT_PER_DAY) {
    return json({
      error: "rate_limited",
      limit: API_RATE_LIMIT_PER_DAY,
      window_seconds: 86_400,
    }, 429);
  }
  if (deps.action === "api.workers.invoke") {
    const invokesPerMinute = await deps.store.countAuditSince(
      ctx.key.id,
      minuteAgo,
      "api.workers.invoke",
    );
    if (invokesPerMinute >= WORKER_INVOKE_LIMIT_PER_MINUTE) {
      return json({
        error: "rate_limited",
        limit: WORKER_INVOKE_LIMIT_PER_MINUTE,
        window_seconds: 60,
        detail: "worker invocation limit",
      }, 429);
    }
  }
  return null;
}

async function handleExternalApiAction(
  deps: JibunApiHandlerDeps,
): Promise<Response> {
  const { action, body, store } = deps;
  const startedAt = performance.now();
  const traceId = typeof body.trace_id === "string" && body.trace_id !== ""
    ? String(body.trace_id).slice(0, 64)
    : crypto.randomUUID();

  const auth = await authenticateApiKey(deps);
  if (auth instanceof Response) return auth;
  const ctx = auth;

  const rateLimited = await checkRateLimit(deps, ctx);

  let workerId: string | null = null;
  let response: Response;
  if (rateLimited) {
    response = rateLimited;
  } else {
    const outcome = await dispatchExternalApiAction(deps, ctx, traceId);
    response = outcome.response;
    workerId = outcome.workerId;
  }

  const durationMs = Math.round(performance.now() - startedAt);
  if (durationMs > SLOW_REQUEST_THRESHOLD_MS) {
    console.warn(JSON.stringify({
      level: "WARN",
      span_name: `jibun-api.${action}`,
      trace_id: traceId,
      duration_ms: durationMs,
      slow: true,
    }));
  } else {
    console.log(JSON.stringify({
      span_name: `jibun-api.${action}`,
      trace_id: traceId,
      duration_ms: durationMs,
      status: response.status,
    }));
  }
  try {
    await store.insertAuditLog({
      user_id: ctx.key.user_id,
      api_key_id: ctx.key.id,
      worker_id: workerId,
      action,
      status: response.status,
      request_ip: requestIp(deps.req),
      duration_ms: durationMs,
      trace_id: traceId,
      request_preview: JSON.stringify({ ...body, action: undefined })
        .slice(0, 200),
    });
    await store.touchKeyLastUsed(ctx.key.id);
  } catch (error) {
    console.warn(`jibun-api audit skipped: ${String(error)}`);
  }
  return response;
}

async function dispatchExternalApiAction(
  deps: JibunApiHandlerDeps,
  ctx: ApiKeyContext,
  traceId: string,
): Promise<{ response: Response; workerId: string | null }> {
  const { action, body, store } = deps;
  const userId = ctx.key.user_id;

  switch (action) {
    case "api.me": {
      return {
        response: json({
          success: true,
          user_id: userId,
          key: keyToSafeJson(ctx.key),
          trace_id: traceId,
        }),
        workerId: null,
      };
    }
    case "api.notes.list": {
      const denied = requireApiScope(ctx, "notes.read");
      if (denied) return { response: denied, workerId: null };
      const limit = clampLimit(body.limit, 20, 50);
      const query = sanitizeSearchQuery(body.q);
      const notes = await store.listNotes(userId, { limit, query });
      return {
        response: json({
          success: true,
          count: notes.length,
          notes,
          trace_id: traceId,
        }),
        workerId: null,
      };
    }
    case "api.notes.create": {
      const denied = requireApiScope(ctx, "notes.write");
      if (denied) return { response: denied, workerId: null };
      const title = String(body.title ?? "").trim();
      const content = String(body.content ?? "");
      if (title === "" || title.length > NOTE_TITLE_MAX_LENGTH) {
        return {
          response: json({
            error: `title is required (1-${NOTE_TITLE_MAX_LENGTH} chars)`,
          }, 400),
          workerId: null,
        };
      }
      if (content.length > NOTE_CONTENT_MAX_LENGTH) {
        return {
          response: json({
            error: `content exceeds ${NOTE_CONTENT_MAX_LENGTH} chars`,
          }, 400),
          workerId: null,
        };
      }
      const note = await store.createNote(userId, { title, content });
      fireWebhooks(
        store,
        userId,
        "note.created",
        { note, trace_id: traceId },
        deps.workerFetch,
      );
      return {
        response: json(
          { success: true, note, trace_id: traceId },
          201,
        ),
        workerId: null,
      };
    }
    case "api.notes.update": {
      const denied = requireApiScope(ctx, "notes.write");
      if (denied) return { response: denied, workerId: null };
      const noteId = Math.floor(Number(body.id ?? 0));
      if (!Number.isFinite(noteId) || noteId <= 0) {
        return {
          response: json({ error: "id is required (positive integer)" }, 400),
          workerId: null,
        };
      }
      const patch: { title?: string; content?: string } = {};
      if (body.title !== undefined) {
        const title = String(body.title).trim();
        if (title === "" || title.length > NOTE_TITLE_MAX_LENGTH) {
          return {
            response: json(
              { error: `title must be 1-${NOTE_TITLE_MAX_LENGTH} chars` },
              400,
            ),
            workerId: null,
          };
        }
        patch.title = title;
      }
      if (body.content !== undefined) {
        const content = String(body.content);
        if (content.length > NOTE_CONTENT_MAX_LENGTH) {
          return {
            response: json(
              { error: `content exceeds ${NOTE_CONTENT_MAX_LENGTH} chars` },
              400,
            ),
            workerId: null,
          };
        }
        patch.content = content;
      }
      if (Object.keys(patch).length === 0) {
        return {
          response: json(
            { error: "no updatable fields provided (title, content)" },
            400,
          ),
          workerId: null,
        };
      }
      const updated = await store.updateNote(userId, noteId, patch);
      if (!updated) {
        return {
          response: json({ error: "note not found" }, 404),
          workerId: null,
        };
      }
      fireWebhooks(store, userId, "note.updated", {
        note: updated,
        trace_id: traceId,
      }, deps.workerFetch);
      return {
        response: json({ success: true, note: updated, trace_id: traceId }),
        workerId: null,
      };
    }
    case "api.notes.delete": {
      const denied = requireApiScope(ctx, "notes.write");
      if (denied) return { response: denied, workerId: null };
      const noteId = Math.floor(Number(body.id ?? 0));
      if (!Number.isFinite(noteId) || noteId <= 0) {
        return {
          response: json({ error: "id is required (positive integer)" }, 400),
          workerId: null,
        };
      }
      const deleted = await store.deleteNote(userId, noteId);
      if (!deleted) {
        return {
          response: json({ error: "note not found" }, 404),
          workerId: null,
        };
      }
      fireWebhooks(store, userId, "note.deleted", {
        note_id: noteId,
        trace_id: traceId,
      }, deps.workerFetch);
      return {
        response: json(
          { success: true, deleted: true, note_id: noteId, trace_id: traceId },
        ),
        workerId: null,
      };
    }
    case "api.tasks.list": {
      const denied = requireApiScope(ctx, "tasks.read");
      if (denied) return { response: denied, workerId: null };
      const limit = clampLimit(body.limit, 20, 50);
      const tasks = await store.listUserTasks(limit);
      return {
        response: json({
          success: true,
          count: tasks.length,
          tasks,
          trace_id: traceId,
        }),
        workerId: null,
      };
    }
    case "api.achievements.list": {
      const denied = requireApiScope(ctx, "achievements.read");
      if (denied) return { response: denied, workerId: null };
      const limit = clampLimit(body.limit, 20, 100);
      const achievements = await store.listAchievements(limit);
      return {
        response: json({
          success: true,
          count: achievements.length,
          achievements,
          trace_id: traceId,
        }),
        workerId: null,
      };
    }
    case "api.workers.list": {
      const denied = requireApiScope(ctx, "workers.invoke");
      if (denied) return { response: denied, workerId: null };
      const workers = await store.listWorkers(userId);
      return {
        response: json({
          success: true,
          count: workers.length,
          workers: workers.map(workerToSafeJson),
          trace_id: traceId,
        }),
        workerId: null,
      };
    }
    case "api.workers.invoke": {
      const denied = requireApiScope(ctx, "workers.invoke");
      if (denied) return { response: denied, workerId: null };
      const slug = normalizeWorkerSlug(body.slug ?? body.worker);
      if (!slug) {
        return {
          response: json({ error: "slug is required" }, 400),
          workerId: null,
        };
      }
      const worker = await store.findWorkerBySlug(userId, slug);
      if (!worker) {
        return {
          response: json({ error: `worker not found: ${slug}` }, 404),
          workerId: null,
        };
      }
      if (!worker.enabled) {
        return {
          response: json({ error: `worker is disabled: ${slug}` }, 403),
          workerId: worker.id,
        };
      }
      // SSRF ガードを呼び出し時にも再検証 (登録後に DNS/URL が差し替わる可能性)
      const endpointError = validateWorkerEndpoint(worker.endpoint_url);
      if (endpointError) {
        return {
          response: json({
            error: `worker endpoint rejected: ${endpointError}`,
          }, 400),
          workerId: worker.id,
        };
      }
      // 名前解決した実 IP がプライベート帯域を指していないか検証 (DNS rebinding 対策)
      const dnsError = await resolveHostToPrivateError(
        new URL(worker.endpoint_url).hostname,
        deps.resolveDns,
      );
      if (dnsError) {
        return {
          response: json(
            { error: `worker endpoint rejected: ${dnsError}` },
            400,
          ),
          workerId: worker.id,
        };
      }
      const invokedAt = new Date().toISOString();
      const payload = JSON.stringify({
        worker: worker.slug,
        payload: body.payload ?? {},
        trace_id: traceId,
        invoked_at: invokedAt,
      });
      const signature = await hmacSha256Hex(worker.signing_secret, payload);
      const fetcher = deps.workerFetch ?? fetch;
      const controller = new AbortController();
      const timeoutId = setTimeout(
        () => controller.abort(),
        Math.min(Math.max(worker.timeout_ms, 1_000), 15_000),
      );
      try {
        const workerResponse = await fetcher(worker.endpoint_url, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Jibun-Signature": `sha256=${signature}`,
            "X-Jibun-Timestamp": invokedAt,
            "X-Jibun-Worker": worker.slug,
            "User-Agent": "jibun-api-worker/1.0",
          },
          body: payload,
          signal: controller.signal,
          redirect: "error",
        });
        const { text, truncated } = await readBoundedBody(
          workerResponse,
          WORKER_RESPONSE_MAX_BYTES,
        );
        let parsed: unknown = text;
        try {
          parsed = JSON.parse(text);
        } catch {
          // テキストのまま返す
        }
        await store.recordWorkerInvocation(worker.id);
        return {
          response: json({
            success: workerResponse.ok,
            worker: worker.slug,
            worker_status: workerResponse.status,
            result: parsed,
            truncated,
            trace_id: traceId,
          }, workerResponse.ok ? 200 : 502),
          workerId: worker.id,
        };
      } catch (error) {
        const aborted = controller.signal.aborted;
        return {
          response: json({
            error: aborted
              ? `worker timed out after ${worker.timeout_ms}ms`
              : `worker call failed: ${String(error).slice(0, 200)}`,
            worker: worker.slug,
            trace_id: traceId,
          }, 504),
          workerId: worker.id,
        };
      } finally {
        clearTimeout(timeoutId);
      }
    }
    default:
      return {
        response: json({
          error: `unknown_endpoint: ${action}`,
          available_actions: [
            "api.me",
            "api.notes.list",
            "api.notes.create",
            "api.notes.update",
            "api.notes.delete",
            "api.tasks.list",
            "api.achievements.list",
            "api.workers.list",
            "api.workers.invoke",
          ],
        }, 404),
        workerId: null,
      };
  }
}
