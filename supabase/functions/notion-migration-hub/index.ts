import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

import { externalFetch } from "../_shared/external_fetch.ts";
import {
  asNotionRecord,
  countNotionKinds,
  NOTION_MIGRATION_API_VERSION,
  notionAttachmentRows,
  notionDurablePayload,
  type NotionInventoryRow,
  notionInventoryRow,
  type NotionObject,
  notionPlainText,
  notionSourceId,
} from "./inventory_model.ts";
import {
  isCloudInventoryActionAllowed,
  resolveCloudInventoryOwner,
} from "./cloud_inventory_auth.ts";
import {
  type InventoryExpansionCandidate,
  inventoryExpansionPlanSha256,
} from "./inventory_expansion_plan.ts";
import {
  prepareWbsStagingRows,
  reconcileWbsMirror,
  type WbsMirrorRecord,
  wbsMirrorRecord,
} from "./wbs_reconciliation_model.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-notion-migration-owner, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Max-Age": "86400",
};

type PageResult = {
  results: NotionObject[];
  hasMore: boolean;
  nextCursor: string | null;
  incompleteReason: string | null;
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function boundedInt(
  value: unknown,
  fallback: number,
  min: number,
  max: number,
) {
  const parsed = Number(value ?? fallback);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(min, Math.min(max, Math.trunc(parsed)));
}

function rawNotionId(sourceId: string): string {
  const separator = sourceId.indexOf(":");
  return separator < 0 ? sourceId : sourceId.slice(separator + 1);
}

function normalizeNotionId(value: unknown): string {
  const raw = String(value ?? "").trim();
  if (!raw) return "";
  const compactIds = raw.replace(/-/g, "").match(/[0-9a-fA-F]{32}/g);
  const compact = compactIds?.at(-1)?.toLowerCase();
  if (!compact) return raw.replace(/^['"]|['"]$/g, "");
  return [
    compact.slice(0, 8),
    compact.slice(8, 12),
    compact.slice(12, 16),
    compact.slice(16, 20),
    compact.slice(20),
  ].join("-");
}

function notionHeaders(token: string): Record<string, string> {
  return {
    "Authorization": `Bearer ${token}`,
    "Notion-Version": NOTION_MIGRATION_API_VERSION,
    "Content-Type": "application/json",
  };
}

async function notionJson(
  token: string,
  path: string,
  init: RequestInit = {},
): Promise<NotionObject> {
  const url = path.startsWith("http")
    ? path
    : `https://api.notion.com/v1${path}`;
  let response: Response | null = null;
  for (let attempt = 0; attempt < 3; attempt++) {
    response = await externalFetch(
      "notion",
      url,
      {
        ...init,
        headers: { ...notionHeaders(token), ...(init.headers ?? {}) },
      },
      { traceId: `notion-migration-hub.${path.split("?")[0]}` },
    );
    if (response.status !== 429) break;
    const retryAfter = boundedInt(
      response.headers.get("retry-after"),
      attempt + 1,
      1,
      8,
    );
    await new Promise((resolve) => setTimeout(resolve, retryAfter * 1000));
  }
  if (!response?.ok) {
    const detail = await response?.text().catch(() => "") ?? "";
    throw new Error(
      `notion_api_failed:${response?.status ?? 0}:${detail.slice(0, 300)}`,
    );
  }
  return await response.json() as NotionObject;
}

function listPage(payload: NotionObject): PageResult {
  const requestStatus = asNotionRecord(payload.request_status);
  return {
    results: Array.isArray(payload.results)
      ? payload.results.map(asNotionRecord).filter((
        value,
      ): value is NotionObject => value !== null)
      : [],
    hasMore: payload.has_more === true,
    nextCursor: typeof payload.next_cursor === "string"
      ? payload.next_cursor
      : null,
    incompleteReason: typeof requestStatus?.incomplete_reason === "string"
      ? requestStatus.incomplete_reason
      : null,
  };
}

async function notionPostPages(
  token: string,
  path: string,
  body: Record<string, unknown>,
  maxPages: number,
): Promise<PageResult> {
  const results: NotionObject[] = [];
  let cursor = typeof body.start_cursor === "string" ? body.start_cursor : null;
  let last: PageResult = {
    results: [],
    hasMore: false,
    nextCursor: null,
    incompleteReason: null,
  };
  for (let page = 0; page < maxPages; page++) {
    const payload = await notionJson(token, path, {
      method: "POST",
      body: JSON.stringify({
        ...body,
        page_size: 100,
        ...(cursor ? { start_cursor: cursor } : {}),
      }),
    });
    last = listPage(payload);
    results.push(...last.results);
    if (!last.hasMore || !last.nextCursor) break;
    cursor = last.nextCursor;
  }
  return { ...last, results };
}

async function notionGetPages(
  token: string,
  path: string,
  maxPages: number,
  startCursor: string | null = null,
): Promise<PageResult> {
  const results: NotionObject[] = [];
  let cursor = startCursor;
  let last: PageResult = {
    results: [],
    hasMore: false,
    nextCursor: null,
    incompleteReason: null,
  };
  for (let page = 0; page < maxPages; page++) {
    const url = new URL(`https://api.notion.com/v1${path}`);
    url.searchParams.set("page_size", "100");
    if (cursor) url.searchParams.set("start_cursor", cursor);
    const payload = await notionJson(token, url.toString());
    last = listPage(payload);
    results.push(...last.results);
    if (!last.hasMore || !last.nextCursor) break;
    cursor = last.nextCursor;
  }
  return { ...last, results };
}

async function authenticatedAdmin(
  req: Request,
): Promise<
  {
    admin: SupabaseClient;
    userId: string;
    isAutomation: boolean;
  } | Response
> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    Deno.env.get("SERVICE_ROLE_KEY") ?? "";
  const authorization = req.headers.get("Authorization") ?? "";
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !authorization) {
    return json({ success: false, error: "Unauthorized" }, 401);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);
  const automationOwner = resolveCloudInventoryOwner({
    authorization,
    serviceRoleKey,
    requestedOwner: req.headers.get("x-notion-migration-owner") ?? "",
  });
  if (automationOwner !== null) {
    return {
      admin,
      userId: automationOwner,
      isAutomation: true,
    };
  }

  const session = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: authData, error: authError } = await session.auth.getUser();
  if (authError || !authData.user) {
    return json({ success: false, error: "Unauthorized" }, 401);
  }

  const { data: profile, error: profileError } = await admin
    .from("user_profiles")
    .select("is_admin, role")
    .eq("user_id", authData.user.id)
    .maybeSingle();
  if (profileError) {
    return json({ success: false, error: profileError.message }, 500);
  }
  if (profile?.is_admin !== true && profile?.role !== "admin") {
    return json({ success: false, error: "admin_required" }, 403);
  }
  return { admin, userId: authData.user.id, isAutomation: false };
}

async function ownedBatch(
  admin: SupabaseClient,
  userId: string,
  batchId: unknown,
) {
  const id = String(batchId ?? "").trim();
  if (!/^[0-9a-f-]{36}$/i.test(id)) {
    throw new Error("batch_id_required");
  }
  const { data, error } = await admin
    .from("notion_migration_batches")
    .select("id, workspace_id, workspace_name, status")
    .eq("id", id)
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new Error("batch_not_found");
  if (data.status === "completed") throw new Error("batch_already_completed");
  return data as {
    id: string;
    workspace_id: string;
    workspace_name: string;
    status: string;
  };
}

async function insertNewRows(
  admin: SupabaseClient,
  rows: readonly NotionInventoryRow[],
): Promise<void> {
  for (let offset = 0; offset < rows.length; offset += 200) {
    const chunk = rows.slice(offset, offset + 200);
    const { error } = await admin
      .from("notion_migration_items")
      .upsert(chunk, {
        onConflict: "batch_id,source_id",
        ignoreDuplicates: true,
      });
    if (error) throw new Error(error.message);
  }
}

async function countRemaining(
  admin: SupabaseClient,
  batchId: string,
  userId: string,
): Promise<number> {
  const { count, error } = await admin
    .from("notion_migration_items")
    .select("id", { count: "exact", head: true })
    .eq("batch_id", batchId)
    .eq("user_id", userId)
    .in("source_kind", ["page", "database", "data_source"])
    .filter("metadata->>inventory_expanded", "eq", "false");
  if (error) throw new Error(error.message);
  return count ?? 0;
}

async function inventoryExpansionCandidates(
  admin: SupabaseClient,
  batchId: string,
  userId: string,
  limit: number,
): Promise<InventoryExpansionCandidate[]> {
  const { data, error } = await admin
    .from("notion_migration_items")
    .select("id,source_id,source_kind,metadata,created_at")
    .eq("batch_id", batchId)
    .eq("user_id", userId)
    .in("source_kind", ["page", "database", "data_source"])
    .filter("metadata->>inventory_expanded", "eq", "false")
    .order("created_at")
    .order("source_id")
    .limit(limit);
  if (error) throw new Error(error.message);
  return (data ?? []) as InventoryExpansionCandidate[];
}

async function planInventoryExpansion(
  admin: SupabaseClient,
  userId: string,
  body: Record<string, unknown>,
) {
  const batch = await ownedBatch(admin, userId, body.batch_id);
  const limit = boundedInt(body.limit, 2, 1, 5);
  const candidates = await inventoryExpansionCandidates(
    admin,
    batch.id,
    userId,
    limit,
  );
  const planSha256 = await inventoryExpansionPlanSha256(candidates);
  const remaining = await countRemaining(admin, batch.id, userId);
  return {
    success: true,
    batch_id: batch.id,
    api_version: NOTION_MIGRATION_API_VERSION,
    plan_sha256: planSha256,
    selected: candidates.length,
    remaining_to_expand: remaining,
    safe_apply_gate_open: candidates.length > 0,
    source_deletion_attempted: false,
  };
}

async function startInventory(
  admin: SupabaseClient,
  userId: string,
  body: Record<string, unknown>,
) {
  const batch = await ownedBatch(admin, userId, body.batch_id);
  const token = Deno.env.get("NOTION_API_TOKEN")?.trim() ?? "";
  if (!token) throw new Error("notion_not_configured");

  const seenAt = new Date().toISOString();
  const [search, users] = await Promise.all([
    notionPostPages(token, "/search", {
      sort: { direction: "ascending", timestamp: "last_edited_time" },
    }, 100),
    notionGetPages(token, "/users", 20),
  ]);

  const workspaceRow: NotionInventoryRow = {
    batch_id: batch.id,
    user_id: userId,
    source_id: notionSourceId("workspace", batch.workspace_id),
    parent_source_id: null,
    source_kind: "workspace",
    title: batch.workspace_name,
    source_path: batch.workspace_name,
    source_updated_at: null,
    metadata: {
      inventory_expanded: true,
      inventory_seen_at: seenAt,
      api_version: NOTION_MIGRATION_API_VERSION,
    },
  };
  const rows = [workspaceRow];
  for (const object of [...search.results, ...users.results]) {
    const row = notionInventoryRow({
      batchId: batch.id,
      userId,
      object,
      seenAt,
      parentSourceId: object.object === "user"
        ? workspaceRow.source_id
        : undefined,
    });
    if (row) rows.push(row);
  }
  await insertNewRows(admin, rows);

  const { error: updateError } = await admin
    .from("notion_migration_batches")
    .update({ status: "inventory", started_at: seenAt })
    .eq("id", batch.id)
    .eq("user_id", userId);
  if (updateError) throw new Error(updateError.message);

  const remaining = await countRemaining(admin, batch.id, userId);

  return {
    success: true,
    batch_id: batch.id,
    api_version: NOTION_MIGRATION_API_VERSION,
    discovered: rows.length,
    counts: countNotionKinds(rows),
    remaining_to_expand: remaining,
    inventory_complete: remaining === 0,
    request_incomplete_reason: search.incompleteReason,
    integration_scope_warning:
      "Only pages and data sources shared with NOTION_API_TOKEN are visible. Compare against the browser/export inventory before deletion.",
  };
}

async function databaseExpansionRows(args: {
  token: string;
  batchId: string;
  userId: string;
  databaseId: string;
  seenAt: string;
}): Promise<NotionInventoryRow[]> {
  const database = await notionJson(
    args.token,
    `/databases/${args.databaseId}`,
  );
  if (!Array.isArray(database.data_sources)) return [];
  const rows: NotionInventoryRow[] = [];
  for (const value of database.data_sources) {
    const reference = asNotionRecord(value);
    if (!reference) continue;
    const row = notionInventoryRow({
      batchId: args.batchId,
      userId: args.userId,
      object: {
        ...reference,
        object: "data_source",
        parent: {
          type: "database_id",
          database_id: args.databaseId,
        },
      },
      seenAt: args.seenAt,
      parentSourceId: notionSourceId("database", args.databaseId),
    });
    if (row) rows.push(row);
  }
  return rows;
}

async function pageExpansionRows(args: {
  token: string;
  batchId: string;
  userId: string;
  pageId: string;
  pageSourceId: string;
  seenAt: string;
}): Promise<{ rows: NotionInventoryRow[]; complete: boolean }> {
  const rows: NotionInventoryRow[] = [];
  const queue: Array<{ id: string; parentSourceId: string }> = [{
    id: args.pageId,
    parentSourceId: args.pageSourceId,
  }];
  let apiCalls = 0;
  while (queue.length > 0 && apiCalls < 80 && rows.length < 5000) {
    const parent = queue.shift()!;
    const children = await notionGetPages(
      args.token,
      `/blocks/${parent.id}/children`,
      10,
    );
    apiCalls += 1;
    for (const block of children.results) {
      const row = notionInventoryRow({
        batchId: args.batchId,
        userId: args.userId,
        object: block,
        seenAt: args.seenAt,
        parentSourceId: parent.parentSourceId,
      });
      if (!row) continue;
      rows.push(row);
      rows.push(...notionAttachmentRows({
        batchId: args.batchId,
        userId: args.userId,
        block,
        seenAt: args.seenAt,
      }));
      if (
        block.has_children === true && row.source_kind === "block" && block.id
      ) {
        queue.push({
          id: String(block.id),
          parentSourceId: row.source_id,
        });
      }
    }
    if (children.hasMore) return { rows, complete: false };
  }

  const comments = await notionGetPages(
    args.token,
    `/comments?block_id=${encodeURIComponent(args.pageId)}`,
    10,
  );
  for (const comment of comments.results) {
    const row = notionInventoryRow({
      batchId: args.batchId,
      userId: args.userId,
      object: comment,
      seenAt: args.seenAt,
      parentSourceId: args.pageSourceId,
    });
    if (row) rows.push(row);
  }
  return {
    rows,
    complete: queue.length === 0 && !comments.hasMore,
  };
}

async function dataSourceExpansionRows(args: {
  token: string;
  batchId: string;
  userId: string;
  sourceId: string;
  cursor: string | null;
  seenAt: string;
}): Promise<{
  rows: NotionInventoryRow[];
  complete: boolean;
  nextCursor: string | null;
}> {
  const rows: NotionInventoryRow[] = [];
  const query = await notionPostPages(
    args.token,
    `/data_sources/${args.sourceId}/query`,
    args.cursor ? { start_cursor: args.cursor } : {},
    20,
  );
  for (const object of query.results) {
    const row = notionInventoryRow({
      batchId: args.batchId,
      userId: args.userId,
      object,
      seenAt: args.seenAt,
      parentSourceId: notionSourceId("data_source", args.sourceId),
    });
    if (row) rows.push(row);
  }

  if (!args.cursor) {
    const views = await notionGetPages(
      args.token,
      `/views?data_source_id=${encodeURIComponent(args.sourceId)}`,
      10,
    );
    for (const viewReference of views.results) {
      const viewId = String(viewReference.id ?? "").trim();
      const object = viewId
        ? await notionJson(args.token, `/views/${viewId}`)
        : viewReference;
      const row = notionInventoryRow({
        batchId: args.batchId,
        userId: args.userId,
        object,
        seenAt: args.seenAt,
        parentSourceId: notionSourceId("data_source", args.sourceId),
      });
      if (row) rows.push(row);
    }
  }
  return {
    rows,
    complete: !query.hasMore,
    nextCursor: query.nextCursor,
  };
}

async function expandInventory(
  admin: SupabaseClient,
  userId: string,
  body: Record<string, unknown>,
  requirePlanDigest = false,
) {
  const batch = await ownedBatch(admin, userId, body.batch_id);
  const token = Deno.env.get("NOTION_API_TOKEN")?.trim() ?? "";
  if (!token) throw new Error("notion_not_configured");
  const limit = boundedInt(body.limit, 2, 1, 5);
  const candidates = await inventoryExpansionCandidates(
    admin,
    batch.id,
    userId,
    limit,
  );
  const planSha256 = await inventoryExpansionPlanSha256(candidates);
  const expectedPlanSha256 = String(body.expected_plan_sha256 ?? "").trim();
  if (requirePlanDigest || expectedPlanSha256 !== "") {
    if (!/^[0-9a-f]{64}$/.test(expectedPlanSha256)) {
      throw new Error("inventory_expand_plan_sha256_required");
    }
    if (expectedPlanSha256 !== planSha256) {
      throw new Error("inventory_expand_plan_sha256_mismatch");
    }
  }

  const seenAt = new Date().toISOString();
  let discovered = 0;
  for (const candidate of candidates) {
    const metadata = asNotionRecord(candidate.metadata) ?? {};
    let result: {
      rows: NotionInventoryRow[];
      complete: boolean;
      nextCursor?: string | null;
    };
    if (candidate.source_kind === "data_source") {
      result = await dataSourceExpansionRows({
        token,
        batchId: batch.id,
        userId,
        sourceId: rawNotionId(candidate.source_id),
        cursor: typeof metadata.inventory_cursor === "string"
          ? metadata.inventory_cursor
          : null,
        seenAt,
      });
    } else if (candidate.source_kind === "page") {
      result = await pageExpansionRows({
        token,
        batchId: batch.id,
        userId,
        pageId: rawNotionId(candidate.source_id),
        pageSourceId: candidate.source_id,
        seenAt,
      });
    } else if (candidate.source_kind === "database") {
      result = {
        rows: await databaseExpansionRows({
          token,
          batchId: batch.id,
          userId,
          databaseId: rawNotionId(candidate.source_id),
          seenAt,
        }),
        complete: true,
      };
    } else {
      result = { rows: [], complete: true };
    }
    await insertNewRows(admin, result.rows);
    discovered += result.rows.length;
    const { error: markError } = await admin
      .from("notion_migration_items")
      .update({
        metadata: {
          ...metadata,
          inventory_expanded: result.complete,
          inventory_cursor: result.nextCursor ?? null,
          inventory_expanded_at: result.complete ? seenAt : null,
          block_comment_scope_complete: false,
        },
      })
      .eq("id", candidate.id)
      .eq("user_id", userId);
    if (markError) throw new Error(markError.message);
  }

  const remaining = await countRemaining(admin, batch.id, userId);
  return {
    success: true,
    batch_id: batch.id,
    api_version: NOTION_MIGRATION_API_VERSION,
    plan_sha256: planSha256,
    expanded: candidates.length,
    discovered,
    remaining_to_expand: remaining,
    inventory_complete: remaining === 0,
    source_deletion_attempted: false,
    limitation:
      "Block-level comments and objects not shared with the integration remain unverified until export/browser reconciliation.",
  };
}

function notionProperty(
  page: NotionObject,
  name: string,
): NotionObject | null {
  return asNotionRecord(asNotionRecord(page.properties)?.[name]);
}

function notionSelectName(property: NotionObject | null): string {
  const value = asNotionRecord(property?.select) ??
    asNotionRecord(property?.status);
  return typeof value?.name === "string" ? value.name : "";
}

function notionDateStart(property: NotionObject | null): string | null {
  const date = asNotionRecord(property?.date);
  return typeof date?.start === "string" ? date.start : null;
}

function notionWbsRecord(page: NotionObject): WbsMirrorRecord {
  const id = notionProperty(page, "id");
  const title = notionProperty(page, "task_title");
  return wbsMirrorRecord({
    id: notionPlainText(id?.title),
    title: notionPlainText(title?.rich_text),
    instance: notionSelectName(notionProperty(page, "instance")),
    status: notionSelectName(notionProperty(page, "status")),
    progress: notionProperty(page, "progress")?.number,
    deadline: notionDateStart(notionProperty(page, "deadline")),
    updatedAt: notionDateStart(notionProperty(page, "updated_at")),
  });
}

function siteWbsRecord(row: NotionObject): WbsMirrorRecord {
  return wbsMirrorRecord({
    id: row.id,
    title: row.title,
    instance: row.instance,
    status: row.status,
    progress: row.progress,
    deadline: row.end_date,
    updatedAt: row.updated_at,
  });
}

async function resolveWbsDataSourceId(token: string): Promise<string> {
  const configuredDataSource = normalizeNotionId(
    Deno.env.get("NOTION_WBS_DATA_SOURCE_ID"),
  );
  if (configuredDataSource) return configuredDataSource;

  const databaseId = normalizeNotionId(
    Deno.env.get("NOTION_WBS_DATABASE_ID"),
  );
  if (!databaseId) throw new Error("wbs_source_not_configured");
  const database = await notionJson(token, `/databases/${databaseId}`);
  const dataSources = Array.isArray(database.data_sources)
    ? database.data_sources.map(asNotionRecord).filter((
      value,
    ): value is NotionObject => value !== null)
    : [];
  const ids = dataSources.map((source) => normalizeNotionId(source.id)).filter(
    Boolean,
  );
  if (ids.length === 0) throw new Error("wbs_data_source_not_found");
  if (ids.length > 1) {
    throw new Error("wbs_database_has_multiple_data_sources");
  }
  return ids[0];
}

async function siteWbsRows(admin: SupabaseClient): Promise<WbsMirrorRecord[]> {
  const rows: WbsMirrorRecord[] = [];
  const pageSize = 1000;
  for (let offset = 0; offset < 100000; offset += pageSize) {
    const { data, error } = await admin
      .from("wbs_tasks")
      .select("id,title,instance,status,progress,end_date,updated_at")
      .order("id", { ascending: true })
      .range(offset, offset + pageSize - 1);
    if (error) throw new Error(`wbs_site_fetch_failed:${error.message}`);
    const page = (data ?? []).map((row) =>
      siteWbsRecord(asNotionRecord(row) ?? {})
    );
    rows.push(...page);
    if (page.length < pageSize) return rows;
  }
  throw new Error("wbs_site_inventory_limit_exceeded");
}

async function persistWbsReconciliation(args: {
  admin: SupabaseClient;
  batchId: string;
  userId: string;
  dataSourceId: string;
  checkedAt: string;
  reconciliation: Record<string, unknown>;
}): Promise<void> {
  const sourceId = notionSourceId("data_source", args.dataSourceId);
  const { data: item, error } = await args.admin
    .from("notion_migration_items")
    .select("id,metadata")
    .eq("batch_id", args.batchId)
    .eq("user_id", args.userId)
    .eq("source_id", sourceId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!item) return;

  const metadata = asNotionRecord(item.metadata) ?? {};
  const { error: itemError } = await args.admin
    .from("notion_migration_items")
    .update({
      metadata: {
        ...metadata,
        wbs_reconciliation: {
          ...args.reconciliation,
          checked_at: args.checkedAt,
        },
      },
    })
    .eq("id", item.id)
    .eq("user_id", args.userId);
  if (itemError) throw new Error(itemError.message);

  const passed = args.reconciliation.deletion_gate_passed === true;
  const evidence = JSON.stringify({
    mirror: "wbs_tasks",
    ...args.reconciliation,
  });
  const { error: checkError } = await args.admin
    .from("notion_migration_checks")
    .upsert({
      item_id: item.id,
      user_id: args.userId,
      check_key: "properties",
      status: passed ? "passed" : "failed",
      source_count: args.reconciliation.notion_rows,
      destination_count: args.reconciliation.site_rows,
      checked_at: args.checkedAt,
      evidence_summary: evidence.slice(0, 4000),
    }, { onConflict: "item_id,check_key" });
  if (checkError) throw new Error(checkError.message);
}

async function reconcileWbs(
  admin: SupabaseClient,
  userId: string,
  body: Record<string, unknown>,
) {
  const batch = await ownedBatch(admin, userId, body.batch_id);
  const token = Deno.env.get("NOTION_API_TOKEN")?.trim() ?? "";
  if (!token) throw new Error("notion_not_configured");
  const dataSourceId = await resolveWbsDataSourceId(token);

  const [notion, siteRows] = await Promise.all([
    notionPostPages(token, `/data_sources/${dataSourceId}/query`, {}, 200),
    siteWbsRows(admin),
  ]);
  const notionRows = notion.results.map(notionWbsRecord);
  const result = reconcileWbsMirror(siteRows, notionRows);
  const inventoryComplete = !notion.hasMore && !notion.incompleteReason;
  const deletionGatePassed = inventoryComplete && result.deletionGatePassed;
  const checkedAt = new Date().toISOString();
  const reconciliation = {
    site_rows: result.siteRows,
    notion_rows: result.notionRows,
    site_distinct_ids: result.siteDistinctIds,
    notion_distinct_ids: result.notionDistinctIds,
    site_duplicate_rows: result.siteDuplicateRows,
    notion_duplicate_rows: result.notionDuplicateRows,
    site_invalid_ids: result.siteInvalidIds,
    notion_invalid_ids: result.notionInvalidIds,
    only_in_site: result.onlyInSite,
    only_in_notion: result.onlyInNotion,
    exact_matches: result.exactMatches,
    mismatched_records: result.mismatchedRecords,
    mismatched_fields: result.mismatchedFields,
    inventory_complete: inventoryComplete,
    deletion_gate_passed: deletionGatePassed,
  };
  await persistWbsReconciliation({
    admin,
    batchId: batch.id,
    userId,
    dataSourceId,
    checkedAt,
    reconciliation,
  });

  return {
    success: true,
    batch_id: batch.id,
    checked_at: checkedAt,
    ...reconciliation,
    deletion_block_reason: deletionGatePassed
      ? null
      : "WBS is retained in Notion until every ID and mirrored field matches and duplicates are zero.",
  };
}

async function stageWbs(
  admin: SupabaseClient,
  userId: string,
  body: Record<string, unknown>,
) {
  const batch = await ownedBatch(admin, userId, body.batch_id);
  const token = Deno.env.get("NOTION_API_TOKEN")?.trim() ?? "";
  if (!token) throw new Error("notion_not_configured");
  const dataSourceId = await resolveWbsDataSourceId(token);
  const notion = await notionPostPages(
    token,
    `/data_sources/${dataSourceId}/query`,
    {},
    200,
  );
  if (notion.hasMore || notion.incompleteReason) {
    throw new Error("wbs_stage_inventory_incomplete");
  }

  const rows = prepareWbsStagingRows(notion.results.map((page) => ({
    sourcePageId: normalizeNotionId(page.id),
    record: notionWbsRecord(page),
    sourceLastEditedAt: page.last_edited_time,
    sourcePayload: notionDurablePayload(page) as NotionObject,
  })));
  const stageRunId = crypto.randomUUID();
  const stagedAt = new Date().toISOString();
  const chunkSize = 100;
  for (let offset = 0; offset < rows.length; offset += chunkSize) {
    const payload = rows.slice(offset, offset + chunkSize).map((row) => ({
      batch_id: batch.id,
      user_id: userId,
      source_page_id: row.sourcePageId,
      task_id: row.taskId,
      duplicate_ordinal: row.duplicateOrdinal,
      title: row.title,
      instance: row.instance,
      status: row.status,
      progress: row.progress,
      deadline: row.deadline,
      source_updated_at: row.sourceUpdatedAt,
      source_last_edited_at: row.sourceLastEditedAt,
      source_payload: row.sourcePayload,
      stage_run_id: stageRunId,
      is_current: true,
      staged_at: stagedAt,
    }));
    const { error } = await admin
      .from("notion_migration_wbs_staging")
      .upsert(payload, { onConflict: "batch_id,source_page_id" });
    if (error) throw new Error(`wbs_stage_upsert_failed:${error.message}`);
  }

  const { error: staleError } = await admin
    .from("notion_migration_wbs_staging")
    .update({ is_current: false })
    .eq("batch_id", batch.id)
    .eq("user_id", userId)
    .eq("is_current", true)
    .neq("stage_run_id", stageRunId);
  if (staleError) {
    throw new Error(`wbs_stage_finalize_failed:${staleError.message}`);
  }

  const validTaskIds = new Set(
    rows.map((row) => row.taskId).filter(Boolean),
  );
  return {
    success: true,
    batch_id: batch.id,
    staged_at: stagedAt,
    staged_rows: rows.length,
    distinct_task_ids: validTaskIds.size,
    duplicate_rows: rows.filter((row) => row.duplicateOrdinal > 1).length,
    invalid_task_ids: rows.filter((row) => !row.taskId).length,
    production_rows_changed: 0,
    next_gate:
      "Resolve duplicate and field-conflict decisions before applying staged rows to wbs_tasks.",
  };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ success: false, error: "method_not_allowed" }, 405);
  }
  try {
    const authorization = await authenticatedAdmin(req);
    if (authorization instanceof Response) return authorization;
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const action = String(body.action ?? "");
    if (
      authorization.isAutomation && !isCloudInventoryActionAllowed(action)
    ) {
      return json({ success: false, error: "automation_action_not_allowed" }, 403);
    }
    let result: Record<string, unknown>;
    switch (action) {
      case "inventory.start":
        result = await startInventory(
          authorization.admin,
          authorization.userId,
          body,
        );
        break;
      case "inventory.plan_expand":
        result = await planInventoryExpansion(
          authorization.admin,
          authorization.userId,
          body,
        );
        break;
      case "inventory.expand":
        result = await expandInventory(
          authorization.admin,
          authorization.userId,
          body,
          authorization.isAutomation,
        );
        break;
      case "reconcile.wbs":
        result = await reconcileWbs(
          authorization.admin,
          authorization.userId,
          body,
        );
        break;
      case "stage.wbs":
        result = await stageWbs(
          authorization.admin,
          authorization.userId,
          body,
        );
        break;
      default:
        throw new Error("unknown_action");
    }
    return json(result);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const status =
      message === "batch_id_required" || message === "unknown_action"
        ? 400
        : message === "batch_not_found"
        ? 404
        : message === "batch_already_completed"
        ? 409
        : message === "notion_not_configured" ||
            message === "wbs_source_not_configured"
        ? 503
        : message === "wbs_database_has_multiple_data_sources"
        ? 409
        : message === "wbs_stage_inventory_incomplete"
        ? 409
        : 500;
    console.error("notion-migration-hub", { status, message });
    return json({ success: false, error: message }, status);
  }
});
