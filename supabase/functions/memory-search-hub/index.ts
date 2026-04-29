import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/edge.ts";
import {
  logMcpInvocation,
  McpAuthContext,
  requireScope,
  validateBearer,
} from "../_shared/mcp_auth_guard.ts";
import {
  MemoryDocument,
  rankBm25,
  ScoredMemoryDocument,
} from "./search/bm25.ts";
import { rerankWithHaiku } from "./search/rerank.ts";
import { vectorSearch } from "./search/vector.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

type Body = Record<string, unknown>;

function adminClient() {
  return createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asPositiveInt(value: unknown, fallback: number, max: number): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(max, Math.floor(parsed));
}

function asStringArray(value: unknown, max = 20): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry) => asString(entry))
    .filter(Boolean)
    .slice(0, max);
}

async function authorize(req: Request): Promise<McpAuthContext | Response> {
  const auth = req.headers.get("Authorization") ?? "";
  if (
    SERVICE_ROLE_KEY &&
    auth === `Bearer ${SERVICE_ROLE_KEY}`
  ) {
    return {
      client_id: "service-role",
      scopes: ["all"],
      aud: ["urn:jibun:tool:*"],
    };
  }

  const ctx = await validateBearer(req);
  if (!ctx) return jsonResponse({ error: "Unauthorized" }, 401);
  if (!requireScope(ctx, "memory-search-hub") && !requireScope(ctx, "memory")) {
    return jsonResponse({ error: "Forbidden" }, 403);
  }
  return ctx;
}

function normalizeDoc(row: Record<string, unknown>): MemoryDocument {
  return {
    file_path: String(row.file_path ?? ""),
    title: row.title == null ? null : String(row.title),
    content: String(row.content ?? ""),
    snippet: row.snippet == null ? null : String(row.snippet),
    updated_at: row.updated_at == null ? null : String(row.updated_at),
    metadata: row.metadata && typeof row.metadata === "object"
      ? row.metadata as Record<string, unknown>
      : null,
  };
}

async function loadRecentDocuments(limit = 1500): Promise<MemoryDocument[]> {
  const { data, error } = await adminClient()
    .from("memory_index")
    .select("file_path,title,content,snippet,metadata,updated_at")
    .order("updated_at", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return ((data ?? []) as Array<Record<string, unknown>>)
    .map(normalizeDoc)
    .filter((doc) => doc.file_path && doc.content);
}

async function loadDocumentsByPath(paths: string[]): Promise<MemoryDocument[]> {
  if (paths.length === 0) return [];
  const { data, error } = await adminClient()
    .from("memory_index")
    .select("file_path,title,content,snippet,metadata,updated_at")
    .in("file_path", paths);
  if (error) throw error;
  const order = new Map(paths.map((path, index) => [path, index]));
  return ((data ?? []) as Array<Record<string, unknown>>)
    .map(normalizeDoc)
    .sort((a, b) =>
      (order.get(a.file_path) ?? 999) - (order.get(b.file_path) ?? 999)
    );
}

function mergeHybridResults(
  bm25: ScoredMemoryDocument[],
  vector: ScoredMemoryDocument[],
  topK: number,
): ScoredMemoryDocument[] {
  const maxBm25 = Math.max(...bm25.map((item) => item.score), 0.0001);
  const merged = new Map<string, ScoredMemoryDocument>();

  for (const item of bm25) {
    merged.set(item.file_path, {
      ...item,
      score: 0.65 * (item.score / maxBm25),
      match_reason: "bm25",
    });
  }

  for (const item of vector) {
    const existing = merged.get(item.file_path);
    if (existing) {
      existing.score += 0.35 * item.score;
      existing.match_reason = "bm25+vector";
    } else {
      merged.set(item.file_path, {
        ...item,
        score: 0.35 * item.score,
        match_reason: "vector",
      });
    }
  }

  return Array.from(merged.values())
    .sort((a, b) => b.score - a.score)
    .slice(0, topK);
}

function toResult(doc: ScoredMemoryDocument) {
  return {
    file: doc.file_path,
    file_path: doc.file_path,
    title: doc.title,
    score: Number(doc.score.toFixed(4)),
    snippet: doc.snippet,
    match_reason: doc.match_reason,
    updated_at: doc.updated_at,
    metadata: doc.metadata ?? {},
  };
}

async function memorySearch(body: Body) {
  const query = asString(body.query);
  if (!query) return jsonResponse({ error: "query required" }, 400);
  const topK = asPositiveInt(body.top_k, 5, 20);

  const docs = await loadRecentDocuments();
  const bm25 = rankBm25(query, docs, 50);
  let vector: ScoredMemoryDocument[] = [];
  try {
    vector = (await vectorSearch(adminClient(), query, 20)).map((match) => ({
      ...match,
      updated_at: null,
    }));
  } catch (error) {
    console.warn("memory.search vector stage skipped", error);
  }

  const results = mergeHybridResults(bm25, vector, topK);
  return jsonResponse({
    success: true,
    action: "memory.search",
    query,
    stages: {
      bm25_candidates: bm25.length,
      vector_candidates: vector.length,
    },
    results: results.map(toResult),
  });
}

async function memoryRank(body: Body) {
  const query = asString(body.query);
  const candidates = asStringArray(body.candidates ?? body.file_paths, 20);
  if (!query) return jsonResponse({ error: "query required" }, 400);
  if (candidates.length === 0) {
    return jsonResponse({ error: "candidates required" }, 400);
  }

  const docs = await loadDocumentsByPath(candidates);
  const ranked = await rerankWithHaiku(
    query,
    docs,
    asPositiveInt(body.top_k, 5, 20),
  );
  return jsonResponse({
    success: true,
    action: "memory.rank",
    ranked: ranked.map((doc) => ({
      ...toResult(doc),
      llm_score: Number(doc.llm_score.toFixed(4)),
    })),
  });
}

async function memoryRelated(body: Body) {
  const file = asString(body.file ?? body.file_path);
  if (!file) return jsonResponse({ error: "file required" }, 400);
  const topK = asPositiveInt(body.top_k, 10, 20);

  const [target] = await loadDocumentsByPath([file]);
  if (!target) return jsonResponse({ error: "file not indexed" }, 404);

  const docs = (await loadRecentDocuments())
    .filter((doc) => doc.file_path !== target.file_path);
  const related = rankBm25(
    [target.title ?? "", target.snippet ?? "", target.content.slice(0, 3000)]
      .join("\n"),
    docs,
    topK,
  );
  return jsonResponse({
    success: true,
    action: "memory.related",
    file,
    related: related.map((doc) => ({
      file: doc.file_path,
      file_path: doc.file_path,
      title: doc.title,
      similarity: Number(doc.score.toFixed(4)),
      snippet: doc.snippet,
      match_reason: "content-similarity",
    })),
  });
}

async function memoryStats() {
  const { count, error: countError } = await adminClient()
    .from("memory_index")
    .select("file_path", { count: "exact", head: true });
  if (countError) throw countError;

  const docs = await loadRecentDocuments(5000);
  const totalBytes = docs.reduce(
    (sum, doc) => sum + new TextEncoder().encode(doc.content).length,
    0,
  );
  const orphanCount = docs.filter((doc) => {
    const links = doc.metadata?.links;
    return !Array.isArray(links) || links.length === 0;
  }).length;
  const staleCount = docs.filter((doc) => {
    if (!doc.updated_at) return false;
    return Date.now() - new Date(doc.updated_at).getTime() >
      45 * 24 * 60 * 60 * 1000;
  }).length;

  return jsonResponse({
    success: true,
    action: "memory.stats",
    total_files: count ?? docs.length,
    sampled_files: docs.length,
    avg_size: docs.length === 0 ? 0 : Math.round(totalBytes / docs.length),
    orphan_count: orphanCount,
    stale_count: staleCount,
    largest_files: docs
      .map((doc) => ({
        file: doc.file_path,
        size: new TextEncoder().encode(doc.content).length,
      }))
      .sort((a, b) => b.size - a.size)
      .slice(0, 10),
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  let ctx: McpAuthContext | null = null;
  let body: Body = {};
  let action = "";
  let status = 500;

  try {
    const authResult = await authorize(req);
    if (authResult instanceof Response) {
      status = authResult.status;
      return authResult;
    }
    ctx = authResult;

    body = req.method === "POST"
      ? await req.json() as Body
      : Object.fromEntries(new URL(req.url).searchParams.entries());
    action = asString(body.action) || "memory.search";

    let response: Response;
    switch (action) {
      case "memory.search":
        response = await memorySearch(body);
        break;
      case "memory.rank":
        response = await memoryRank(body);
        break;
      case "memory.related":
        response = await memoryRelated(body);
        break;
      case "memory.stats":
        response = await memoryStats();
        break;
      default:
        response = jsonResponse({ error: `Unknown action: ${action}` }, 400);
    }
    status = response.status;
    return response;
  } catch (error) {
    status = 500;
    return jsonResponse({ error: String(error) }, 500);
  } finally {
    await logMcpInvocation(ctx, action || "unknown", body, status, req);
  }
});
