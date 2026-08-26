import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/edge.ts";
import {
  buildOAuthProtectedResourceMetadata,
  isOAuthProtectedResourceMetadataRequest,
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
import { buildQueryRouteDecision } from "./query_report.ts";
import { rerankWithHaiku } from "./search/rerank.ts";
import { embedTextWithGemini, vectorSearch } from "./search/vector.ts";
import {
  buildCitationEvidence,
  hasOnlyValidCitationMarkers,
} from "./citation_evidence.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

type Body = Record<string, unknown>;

const KG_DEFAULT_SOURCE_TYPES = ["issue", "wbs", "doc", "memory", "notebooklm"];
const KG_SOURCE_ALIASES: Record<string, string> = {
  issue: "issue",
  issues: "issue",
  github: "issue",
  github_issues: "issue",
  wbs: "wbs",
  doc: "doc",
  docs: "doc",
  documentation: "doc",
  memory: "memory",
  notebooklm: "notebooklm",
  "notebooklm-intake": "notebooklm",
};
const KG_RATE_LIMIT_PER_MINUTE = 5;

/**
 * MCP-AUTH-27 self-check for memory-search-hub (#1577 Phase E).
 *
 * 1. DCR: PASS via mcp_oauth_clients + Terraform plan-only registry path.
 * 2. Bearer deny-by-default: PASS through authorize() + validateBearer().
 * 3. Prompt injection boundary: PASS for RAG answers through citation-only
 *    system prompt, excerpt trimming, and extractive fallback.
 * 4. Streamable HTTP: PASS; this function exposes JSON HTTP only and no SSE.
 * 5. Resource Indicators: PASS through requireScope(ctx, "memory-search-hub")
 *    or requireScope(ctx, "memory").
 * 6. WorkOS managed: PASS through WorkOS JWKS/issuer validation in the shared
 *    auth guard, with service-role bypass limited to internal calls.
 * 7. Audit log + monitoring: PASS through try/finally logMcpInvocation() plus
 *    the mcp-audit-anomaly-cron workflow.
 * 8. OAuth 2.1 + PKCE: PASS at the WorkOS/AuthKit boundary; the EF only accepts
 *    already-issued bearer tokens.
 * 9. .well-known: PASS through OAuth protected resource metadata handling.
 * 10. Least privilege + AttestMCP readiness: PASS with an explicit scope list,
 *    no sampling capability declaration, and docs/mcp-attest-roadmap.md.
 *
 * Result: 10/10 public MCP boundary criteria satisfied for the first guarded
 * memory-search-hub surface. Future tool additions must update this checklist.
 */

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

function normalizeKgSourceTypes(value: unknown): string[] {
  const raw = Array.isArray(value) ? value : KG_DEFAULT_SOURCE_TYPES;
  const normalized = raw
    .map((entry) => KG_SOURCE_ALIASES[asString(entry).toLowerCase()])
    .filter(Boolean);
  const unique = Array.from(new Set(normalized));
  return unique.length > 0 ? unique : KG_DEFAULT_SOURCE_TYPES;
}

function normalizeUuid(value: unknown): string | null {
  const raw = asString(value);
  if (
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(raw)
  ) {
    return raw;
  }
  return null;
}

function clientKeyFor(
  ctx: McpAuthContext | null,
  userId: string | null,
): string {
  return userId ?? ctx?.client_id ?? "anonymous";
}

function trimText(value: string, maxChars: number): string {
  const compact = value.replace(/\s+/g, " ").trim();
  if (compact.length <= maxChars) return compact;
  return `${compact.slice(0, maxChars - 3)}...`;
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

function normalizeKgDoc(row: Record<string, unknown>): MemoryDocument {
  const sourceType = String(row.source_type ?? "doc");
  const sourceId = String(row.source_id ?? row.id ?? "");
  const sourceUrl = String(row.source_url ?? "");
  const metadata = row.metadata && typeof row.metadata === "object"
    ? row.metadata as Record<string, unknown>
    : {};
  return {
    file_path: `${sourceType}:${sourceId}`,
    title: row.title == null ? null : String(row.title),
    content: String(row.content ?? ""),
    snippet: row.excerpt == null ? null : String(row.excerpt),
    updated_at: row.last_synced_at == null ? null : String(row.last_synced_at),
    metadata: {
      ...metadata,
      kg: true,
      source_id: sourceId,
      source_type: sourceType,
      source_url: sourceUrl,
      last_synced_at: row.last_synced_at == null
        ? null
        : String(row.last_synced_at),
    },
  };
}

async function loadRecentKgDocuments(
  sourceTypes: string[],
  limit = 2000,
): Promise<MemoryDocument[]> {
  const { data, error } = await adminClient()
    .from("kg_embeddings")
    .select(
      "source_id,source_type,source_url,title,content,excerpt,metadata,last_synced_at",
    )
    .in("source_type", sourceTypes)
    .order("last_synced_at", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return ((data ?? []) as Array<Record<string, unknown>>)
    .map(normalizeKgDoc)
    .filter((doc) => doc.file_path && doc.content);
}

async function kgVectorSearch(
  client: ReturnType<typeof adminClient>,
  query: string,
  sourceTypes: string[],
  limit = 20,
): Promise<ScoredMemoryDocument[]> {
  const apiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
  if (!apiKey) return [];
  const embedding = await embedTextWithGemini(query, apiKey);
  const { data, error } = await client.rpc("match_kg_embeddings", {
    query_embedding: embedding,
    match_count: limit,
    match_threshold: 0.5,
    source_filter: sourceTypes,
  });
  if (error) throw error;
  return ((data ?? []) as Array<Record<string, unknown>>)
    .map((row) => ({
      ...normalizeKgDoc(row),
      score: Number(row.score ?? 0),
      match_reason: "vector",
    }))
    .filter((doc) => doc.file_path && doc.content && doc.score > 0);
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

function citationFor(
  doc: ScoredMemoryDocument,
  maxScore: number,
  query: string,
  index: number,
) {
  const metadata = doc.metadata ?? {};
  const sourceType = String(metadata.source_type ?? "memory");
  const sourceUrl = String(metadata.source_url ?? doc.file_path);
  const confidence = maxScore <= 0 ? 0 : doc.score / maxScore;
  return buildCitationEvidence({
    citationId: String(index + 1),
    query,
    filePath: doc.file_path,
    title: doc.title ?? doc.file_path,
    content: doc.content,
    snippet: doc.snippet ?? "",
    sourceType,
    sourceUrl,
    metadata,
    confidence,
    lastSyncedAt: doc.updated_at == null
      ? metadata.last_synced_at == null ? null : String(metadata.last_synced_at)
      : String(doc.updated_at),
  });
}

function citationsAreStale(
  citations: Array<Record<string, unknown>>,
): boolean {
  const cutoff = Date.now() - 24 * 60 * 60 * 1000;
  return citations.some((citation) => {
    const raw = asString(citation["last_synced_at"]);
    if (!raw) return true;
    const timestamp = new Date(raw).getTime();
    return Number.isFinite(timestamp) && timestamp < cutoff;
  });
}

function extractiveAnswer(
  query: string,
  citations: Array<Record<string, unknown>>,
): string {
  if (citations.length === 0) {
    return "No matching project artifacts were found for this query.";
  }
  const lines = citations.slice(0, 3).map((citation, index) =>
    `[${index + 1}] ${String(citation["excerpt"] ?? "")}`
  );
  return trimText(
    [
      `Query: ${query}`,
      "The strongest matching project artifacts say:",
      ...lines,
      "Use the citations to inspect the source before acting on the answer.",
    ].join("\n"),
    1400,
  );
}

function ragMessages(query: string, citations: Array<Record<string, unknown>>) {
  const context = citations.map((citation, index) =>
    [
      `[${index + 1}] ${citation["title"] ?? citation["source_url"]}`,
      `type: ${citation["source_type"]}`,
      `url: ${citation["source_url"]}`,
      `excerpt: ${citation["excerpt"]}`,
    ].join("\n")
  ).join("\n\n");
  return [
    {
      role: "system",
      content:
        "Answer only from the provided project citations. If the citations are insufficient, say so. Keep the answer concise and include bracket citations like [1].",
    },
    {
      role: "user",
      content: `Question:\n${query}\n\nProject citations:\n${context}`,
    },
  ];
}

async function generateLlmRagAnswer(
  body: Body,
  query: string,
  citations: Array<Record<string, unknown>>,
  traceId: string,
): Promise<string | null> {
  if (body.use_llm === false || citations.length === 0) return null;
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) return null;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);
  try {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/ai-hub`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        "Content-Type": "application/json",
      },
      signal: controller.signal,
      body: JSON.stringify({
        action: "provider.chat_auto",
        tier: asString(body.tier) || "free",
        trace_id: traceId,
        messages: ragMessages(query, citations),
      }),
    });
    const payload = await response.json() as Record<string, unknown>;
    const text = asString(payload["text"]);
    if (!response.ok || payload["success"] === false || !text) {
      throw new Error(
        `ai-hub provider.chat_auto failed: ${
          asString(payload["status"]) || response.status
        }`,
      );
    }
    return text;
  } finally {
    clearTimeout(timeout);
  }
}

async function assertKgRateLimit(
  client: ReturnType<typeof adminClient>,
  clientKey: string,
): Promise<Response | null> {
  const since = new Date(Date.now() - 60 * 1000).toISOString();
  try {
    const { count, error } = await client
      .from("kg_query_logs")
      .select("trace_id", { count: "exact", head: true })
      .eq("client_key", clientKey)
      .gte("created_at", since);
    if (error) throw error;
    if ((count ?? 0) >= KG_RATE_LIMIT_PER_MINUTE) {
      return jsonResponse({
        error: "rate_limited",
        limit: KG_RATE_LIMIT_PER_MINUTE,
        window_seconds: 60,
      }, 429);
    }
  } catch (error) {
    console.warn("kg rate limit skipped", error);
  }
  return null;
}

async function logKgQuery(
  client: ReturnType<typeof adminClient>,
  entry: Record<string, unknown>,
) {
  try {
    await client.from("kg_query_logs").insert(entry);
  } catch (error) {
    console.warn("kg query log skipped", error);
  }
}

async function memoryRagQuery(body: Body, ctx: McpAuthContext | null) {
  const startedAt = performance.now();
  const query = asString(body.query);
  if (!query) return jsonResponse({ error: "query required" }, 400);

  const topK = asPositiveInt(body.top_k, 8, 12);
  const sourceTypes = normalizeKgSourceTypes(body.sources);
  const traceId = crypto.randomUUID();
  const userId = normalizeUuid(body.user_id);
  const clientKey = clientKeyFor(ctx, userId);
  const client = adminClient();

  const rateLimited = await assertKgRateLimit(client, clientKey);
  if (rateLimited) return rateLimited;

  let docs: MemoryDocument[] = [];
  let kgLoadError = "";
  try {
    docs = await loadRecentKgDocuments(sourceTypes);
  } catch (error) {
    kgLoadError = String(error);
    console.warn("kg document load skipped", error);
  }

  if (docs.length === 0 && sourceTypes.includes("memory")) {
    try {
      docs = (await loadRecentDocuments()).map((doc) => ({
        ...doc,
        metadata: {
          ...(doc.metadata ?? {}),
          kg: false,
          source_type: "memory",
          source_id: doc.file_path,
          source_url: doc.file_path,
          last_synced_at: doc.updated_at,
        },
      }));
    } catch (error) {
      console.warn("memory fallback skipped", error);
    }
  }

  const bm25 = rankBm25(query, docs, 50);
  let vector: ScoredMemoryDocument[] = [];
  if (!kgLoadError) {
    try {
      vector = await kgVectorSearch(client, query, sourceTypes, 20);
    } catch (error) {
      console.warn("kg vector stage skipped", error);
    }
  }
  const results = mergeHybridResults(bm25, vector, topK);
  const maxScore = Math.max(...results.map((item) => item.score), 0.0001);
  const citations = results.map((doc, index) =>
    citationFor(doc, maxScore, query, index)
  );

  let answerStatus = citations.length === 0
    ? "no_results"
    : citationsAreStale(citations)
    ? "stale_index"
    : "ok";
  let answer = extractiveAnswer(query, citations);

  if (citations.length > 0) {
    try {
      const generatedAnswer = await generateLlmRagAnswer(
        body,
        query,
        citations,
        traceId,
      );
      if (
        generatedAnswer != null &&
        hasOnlyValidCitationMarkers(generatedAnswer, citations.length)
      ) {
        answer = generatedAnswer;
      } else if (generatedAnswer != null && answerStatus === "ok") {
        answerStatus = "citation_fallback";
      }
    } catch (error) {
      console.warn("kg llm stage failed", error);
      if (answerStatus === "ok") answerStatus = "llm_failure";
    }
  }

  await logKgQuery(client, {
    trace_id: traceId,
    user_id: userId,
    client_key: clientKey,
    query,
    sources: sourceTypes,
    top_k: topK,
    answer_status: answerStatus,
    citation_count: citations.length,
    latency_ms: Math.round(performance.now() - startedAt),
  });

  return jsonResponse({
    success: true,
    action: "memory.rag.query",
    query,
    answer,
    citations,
    trace_id: traceId,
    answer_status: answerStatus,
    sources: sourceTypes,
    stages: {
      kg_documents: docs.length,
      bm25_candidates: bm25.length,
      vector_candidates: vector.length,
      kg_load_error: kgLoadError || null,
    },
  });
}

async function memoryQueryRoute(body: Body) {
  const query = asString(body.query);
  if (!query) return jsonResponse({ error: "query required" }, 400);

  const rawReport = asString(
    body.query_report ?? body.queryReport ?? body.report,
  );
  if (!rawReport) {
    return jsonResponse({ error: "query_report required" }, 400);
  }

  const route = buildQueryRouteDecision(query, rawReport);
  const queryRoute = {
    state: route.state,
    action: route.action,
    original_query: query,
    search_query: route.searchQuery,
    used_reformulated_query: route.action === "search" &&
      route.searchQuery !== query,
    feedback: route.feedback,
    parsed_report: {
      state: route.report.state,
      reformulated_query: route.report.reformulatedQuery,
      reason: route.report.reason,
    },
  };

  if (route.action === "clarify") {
    return jsonResponse({
      success: false,
      action: "memory.query_route",
      error: "query_clarification_required",
      query_route: queryRoute,
    }, 422);
  }

  const response = await memorySearch({
    ...body,
    query: route.searchQuery,
  });
  const payload = await response.json() as Record<string, unknown>;
  return jsonResponse({
    ...payload,
    action: "memory.query_route",
    original_action: payload.action,
    original_query: query,
    query: route.searchQuery,
    query_route: queryRoute,
  }, response.status);
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
  if (isOAuthProtectedResourceMetadataRequest(req)) {
    return jsonResponse(
      buildOAuthProtectedResourceMetadata(req.url, "memory-search-hub", [
        "memory",
        "memory.search",
        "memory.query_route",
        "memory.rank",
        "memory.related",
        "memory.stats",
        "memory.rag.query",
        "rag.query",
        "memory-search-hub.rag.query",
      ]),
    );
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
      case "memory.rag.query":
      case "rag.query":
      case "memory-search-hub.rag.query":
        response = await memoryRagQuery(body, ctx);
        break;
      case "memory.query_route":
        response = await memoryQueryRoute(body);
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
