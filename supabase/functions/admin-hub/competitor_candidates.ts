import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export type CandidateReviewDecision = "pending" | "approved" | "rejected";

export interface CompetitorCandidateReviewRow {
  id: string;
  display_name: string;
  category: string | null;
  website: string | null;
  source_url_status_code: number | null;
  source_url_checked_at: string | null;
  source_url_error: string | null;
  needs_manual_review: boolean;
  review_decision: CandidateReviewDecision;
  reviewed: boolean;
  rejected_reason: string | null;
  staged_at: string | null;
  reviewed_at: string | null;
}

export interface CandidateStoreResult<T> {
  data: T | null;
  error: { message: string } | null;
}

export interface AdminProfileRow {
  is_admin?: boolean | null;
  role?: string | null;
}

export interface CandidateCallerContext {
  userId: string | null;
  isServiceRole: boolean;
}

export interface CompetitorCandidateStore {
  getAdminProfile(userId: string): Promise<CandidateStoreResult<AdminProfileRow>>;
  listCandidates(
    onlyManualReview: boolean,
    limit: number,
  ): Promise<CandidateStoreResult<CompetitorCandidateReviewRow[]>>;
  getCandidate(
    id: string,
  ): Promise<CandidateStoreResult<CompetitorCandidateReviewRow>>;
  updateCandidate(
    id: string,
    updates: Record<string, unknown>,
  ): Promise<CandidateStoreResult<CompetitorCandidateReviewRow>>;
}

export function createSupabaseCompetitorCandidateStore(
  admin: SupabaseClient,
): CompetitorCandidateStore {
  return {
    async getAdminProfile(userId) {
      const { data, error } = await admin
        .from("user_profiles")
        .select("is_admin, role")
        .eq("user_id", userId)
        .maybeSingle();
      return {
        data: data ? (data as AdminProfileRow) : null,
        error: error ? { message: error.message } : null,
      };
    },
    async listCandidates(onlyManualReview, limit) {
      let query = admin
        .from("competitor_candidates")
        .select(
          "id,display_name,category,website,source_url_status_code,source_url_checked_at,source_url_error,needs_manual_review,review_decision,reviewed,rejected_reason,staged_at,reviewed_at",
        );
      if (onlyManualReview) {
        query = query.eq("needs_manual_review", true);
      }
      const { data, error } = await query
        .order("needs_manual_review", { ascending: false })
        .order("staged_at", { ascending: false })
        .limit(limit);
      return {
        data: data ? (data as CompetitorCandidateReviewRow[]) : null,
        error: error ? { message: error.message } : null,
      };
    },
    async getCandidate(id) {
      const { data, error } = await admin
        .from("competitor_candidates")
        .select(
          "id,display_name,category,website,source_url_status_code,source_url_checked_at,source_url_error,needs_manual_review,review_decision,reviewed,rejected_reason,staged_at,reviewed_at",
        )
        .eq("id", id)
        .maybeSingle();
      return {
        data: data ? (data as CompetitorCandidateReviewRow) : null,
        error: error ? { message: error.message } : null,
      };
    },
    async updateCandidate(id, updates) {
      const { data, error } = await admin
        .from("competitor_candidates")
        .update(updates)
        .eq("id", id)
        .select(
          "id,display_name,category,website,source_url_status_code,source_url_checked_at,source_url_error,needs_manual_review,review_decision,reviewed,rejected_reason,staged_at,reviewed_at",
        )
        .maybeSingle();
      return {
        data: data ? (data as CompetitorCandidateReviewRow) : null,
        error: error ? { message: error.message } : null,
      };
    },
  };
}

export interface UrlCheckResult {
  statusCode: number | null;
  needsManualReview: boolean;
  error: string | null;
  checkedAt: string;
}

const MAX_REDIRECT_HOPS = 5;
const REDIRECT_STATUSES = new Set([301, 302, 303, 307, 308]);

function stripBracketsAndZone(host: string): string {
  let clean = host.trim().toLowerCase();
  if (clean.startsWith("[") && clean.endsWith("]")) {
    clean = clean.slice(1, -1);
  }
  const zoneIdx = clean.indexOf("%");
  if (zoneIdx !== -1) {
    clean = clean.slice(0, zoneIdx);
  }
  return clean;
}

function parseIpv4Octets(host: string): number[] | null {
  const parts = host.split(".");
  if (parts.length !== 4 || parts.some((p) => !/^\d{1,3}$/.test(p))) {
    return null;
  }
  const nums = parts.map((p) => Number(p));
  if (nums.some((n) => n < 0 || n > 255)) return null;
  return nums;
}

function isBlockedIpv4Octets(nums: number[]): boolean {
  const [a, b, c] = nums;
  if (a === 0 || a === 10 || a === 127) return true;
  if (a === 100 && b >= 64 && b <= 127) return true; // CGNAT 100.64.0.0/10
  if (a === 169 && b === 254) return true; // link-local & cloud metadata
  if (a === 172 && b >= 16 && b <= 31) return true;
  if (a === 192 && b === 0 && (c === 0 || c === 2)) return true;
  if (a === 192 && b === 168) return true;
  if (a === 198 && (b === 18 || b === 19)) return true;
  if (a === 198 && b === 51 && c === 100) return true;
  if (a === 203 && b === 0 && c === 113) return true;
  if (a >= 224) return true; // multicast + reserved + broadcast
  return false;
}

function expandIpv6Groups(raw: string): number[] | null {
  let addr = raw;
  const lastColon = addr.lastIndexOf(":");
  if (lastColon !== -1 && addr.slice(lastColon + 1).includes(".")) {
    const ipv4 = parseIpv4Octets(addr.slice(lastColon + 1));
    if (!ipv4) return null;
    const hi = ((ipv4[0] << 8) | ipv4[1]).toString(16);
    const lo = ((ipv4[2] << 8) | ipv4[3]).toString(16);
    addr = `${addr.slice(0, lastColon)}:${hi}:${lo}`;
  }
  const doubleColonParts = addr.split("::");
  if (doubleColonParts.length > 2) return null;
  if (doubleColonParts.length === 2) {
    const left = doubleColonParts[0] === ""
      ? []
      : doubleColonParts[0].split(":");
    const right = doubleColonParts[1] === ""
      ? []
      : doubleColonParts[1].split(":");
    const fill = 8 - (left.length + right.length);
    if (fill < 0) return null;
    const full = [...left, ...Array<string>(fill).fill("0"), ...right];
    if (full.length !== 8 || full.some((g) => !/^[0-9a-f]{1,4}$/i.test(g))) {
      return null;
    }
    return full.map((g) => parseInt(g, 16));
  }
  const groups = addr.split(":");
  if (groups.length !== 8 || groups.some((g) => !/^[0-9a-f]{1,4}$/i.test(g))) {
    return null;
  }
  return groups.map((g) => parseInt(g, 16));
}

export function isBlockedIpAddress(rawHostOrIp: string): boolean {
  const clean = stripBracketsAndZone(rawHostOrIp);
  if (!clean) return true;
  const ipv4 = parseIpv4Octets(clean);
  if (ipv4) {
    return isBlockedIpv4Octets(ipv4);
  }
  if (!clean.includes(":")) {
    return false;
  }
  const g = expandIpv6Groups(clean);
  if (!g) return true; // Malformed IPv6 fails closed
  const isAllZeroPrefix = g[0] === 0 && g[1] === 0 && g[2] === 0 && g[3] === 0 &&
    g[4] === 0;
  // :: and ::1
  if (isAllZeroPrefix && g[5] === 0 && g[6] === 0 && (g[7] === 0 || g[7] === 1)) {
    return true;
  }
  // ::ffff:0:0/96 IPv4-mapped IPv6
  if (isAllZeroPrefix && g[5] === 0xffff) {
    return isBlockedIpv4Octets([
      (g[6] >> 8) & 0xff,
      g[6] & 0xff,
      (g[7] >> 8) & 0xff,
      g[7] & 0xff,
    ]);
  }
  // fc00::/7 (Unique Local Addresses)
  if ((g[0] & 0xfe00) === 0xfc00) return true;
  // fe80::/10 (Link-local) & fec0::/10 (Site-local)
  if ((g[0] & 0xffc0) === 0xfe80 || (g[0] & 0xffc0) === 0xfec0) return true;
  // ff00::/8 (Multicast)
  if ((g[0] & 0xff00) === 0xff00) return true;
  // 2001:db8::/32 (Documentation)
  if (g[0] === 0x2001 && g[1] === 0x0db8) return true;
  return false;
}

export function validatePublicHttpUrl(
  rawUrl: string | null | undefined,
): { ok: true; url: string; hostname: string } | { ok: false; error: string } {
  const candidate = (rawUrl ?? "").trim();
  if (!candidate) {
    return { ok: false, error: "Empty source URL" };
  }
  let parsed: URL;
  try {
    parsed = new URL(candidate);
  } catch {
    return { ok: false, error: "Malformed source URL" };
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    return { ok: false, error: `Unsupported URL scheme: ${parsed.protocol}` };
  }
  if (parsed.username !== "" || parsed.password !== "") {
    return { ok: false, error: "Credentials in URL are not allowed" };
  }
  const host = stripBracketsAndZone(parsed.hostname);
  if (
    host === "" ||
    host === "localhost" ||
    host === "localhost.localdomain" ||
    host.endsWith(".localhost") ||
    host.endsWith(".local") ||
    host.endsWith(".internal") ||
    isBlockedIpAddress(host)
  ) {
    return { ok: false, error: `Blocked non-public host: ${host || "empty"}` };
  }
  return { ok: true, url: parsed.toString(), hostname: host };
}

export type DnsResolver = (hostname: string) => Promise<string[]>;

export async function defaultResolveDns(hostname: string): Promise<string[]> {
  const [v4Res, v6Res] = await Promise.allSettled([
    Deno.resolveDns(hostname, "A"),
    Deno.resolveDns(hostname, "AAAA"),
  ]);
  const ips: string[] = [];
  if (v4Res.status === "fulfilled") ips.push(...v4Res.value);
  if (v6Res.status === "fulfilled") ips.push(...v6Res.value);
  return ips;
}

export async function validateResolvedPublicUrl(
  rawUrl: string | null | undefined,
  resolveDnsFn: DnsResolver = defaultResolveDns,
): Promise<{ ok: true; url: string } | { ok: false; error: string }> {
  const checked = validatePublicHttpUrl(rawUrl);
  if (!checked.ok) {
    return checked;
  }
  const isIpLiteral = parseIpv4Octets(checked.hostname) !== null ||
    checked.hostname.includes(":");
  if (!isIpLiteral) {
    let resolvedIps: string[];
    try {
      resolvedIps = await resolveDnsFn(checked.hostname);
    } catch {
      return { ok: false, error: `DNS lookup failed for ${checked.hostname}` };
    }
    if (resolvedIps.length === 0) {
      return { ok: false, error: `DNS returned no records for ${checked.hostname}` };
    }
    const blockedIp = resolvedIps.find((ip) => isBlockedIpAddress(ip));
    if (blockedIp) {
      return {
        ok: false,
        error: `DNS resolved to blocked non-public IP: ${blockedIp}`,
      };
    }
  }
  return { ok: true, url: checked.url };
}

export type FetchLike = (
  input: string | URL,
  init?: RequestInit,
) => Promise<Response>;

export async function verifyCandidateUrl(
  rawUrl: string | null | undefined,
  fetchFn: FetchLike = fetch,
  nowIso: string = new Date().toISOString(),
  resolveDnsFn: DnsResolver = defaultResolveDns,
): Promise<UrlCheckResult> {
  let currentUrl = rawUrl ?? "";
  let method: "HEAD" | "GET" = "HEAD";

  for (let hop = 0; hop <= MAX_REDIRECT_HOPS; hop += 1) {
    const validated = await validateResolvedPublicUrl(currentUrl, resolveDnsFn);
    if (!validated.ok) {
      return {
        statusCode: null,
        needsManualReview: true,
        error: validated.error,
        checkedAt: nowIso,
      };
    }

    let resp: Response;
    try {
      resp = await fetchFn(validated.url, {
        method,
        redirect: "manual",
        signal: AbortSignal.timeout(5000),
      });
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return {
        statusCode: null,
        needsManualReview: true,
        error: msg.slice(0, 200),
        checkedAt: nowIso,
      };
    }

    if (method === "HEAD" && (resp.status === 405 || resp.status === 501)) {
      method = "GET";
      hop -= 1;
      continue;
    }

    if (REDIRECT_STATUSES.has(resp.status)) {
      const location = resp.headers.get("location")?.trim() ?? "";
      if (!location) {
        return {
          statusCode: resp.status,
          needsManualReview: true,
          error: `HTTP ${resp.status} missing Location header`,
          checkedAt: nowIso,
        };
      }
      if (hop >= MAX_REDIRECT_HOPS) {
        return {
          statusCode: resp.status,
          needsManualReview: true,
          error: "Too many redirects",
          checkedAt: nowIso,
        };
      }
      try {
        currentUrl = new URL(location, validated.url).toString();
      } catch {
        return {
          statusCode: resp.status,
          needsManualReview: true,
          error: "Malformed redirect Location",
          checkedAt: nowIso,
        };
      }
      continue;
    }

    const ok = resp.status >= 200 && resp.status < 400;
    return {
      statusCode: resp.status,
      needsManualReview: !ok,
      error: ok ? null : `HTTP ${resp.status}`,
      checkedAt: nowIso,
    };
  }

  return {
    statusCode: null,
    needsManualReview: true,
    error: "Too many redirects",
    checkedAt: nowIso,
  };
}

export interface CandidateServiceResponse {
  status: number;
  body: Record<string, unknown>;
}

export async function authorizeCandidateAdmin(
  store: CompetitorCandidateStore,
  caller: CandidateCallerContext,
): Promise<CandidateServiceResponse | null> {
  if (!caller.userId && !caller.isServiceRole) {
    return { status: 401, body: { error: "Unauthorized" } };
  }
  if (caller.isServiceRole) {
    return null;
  }
  const profileRes = await store.getAdminProfile(caller.userId!);
  if (profileRes.error) {
    return { status: 500, body: { error: profileRes.error.message } };
  }
  const profile = profileRes.data;
  if (profile?.is_admin !== true && profile?.role !== "admin") {
    return { status: 403, body: { error: "admin_required" } };
  }
  return null;
}

export async function handleCompetitorCandidateList(
  store: CompetitorCandidateStore,
  caller: CandidateCallerContext,
  input: Record<string, unknown>,
): Promise<CandidateServiceResponse> {
  const denied = await authorizeCandidateAdmin(store, caller);
  if (denied) return denied;
  const onlyManual = input.only_manual_review === true;
  const rawLimit = typeof input.limit === "number"
    ? input.limit
    : Number(input.limit);
  const limit = Number.isFinite(rawLimit) && rawLimit > 0
    ? Math.min(Math.max(Math.trunc(rawLimit), 1), 100)
    : 50;
  const { data, error } = await store.listCandidates(onlyManual, limit);
  if (error) {
    return { status: 500, body: { error: error.message } };
  }
  return {
    status: 200,
    body: {
      success: true,
      candidates: data ?? [],
    },
  };
}

export async function handleCompetitorCandidateVerifyUrl(
  store: CompetitorCandidateStore,
  caller: CandidateCallerContext,
  input: Record<string, unknown>,
  fetchFn: FetchLike = fetch,
  nowIso: string = new Date().toISOString(),
  resolveDnsFn: DnsResolver = defaultResolveDns,
): Promise<CandidateServiceResponse> {
  const denied = await authorizeCandidateAdmin(store, caller);
  if (denied) return denied;
  const id = typeof input.candidate_id === "string"
    ? input.candidate_id.trim()
    : "";
  if (!id) {
    return { status: 400, body: { error: "candidate_id is required" } };
  }
  const existing = await store.getCandidate(id);
  if (existing.error) {
    return { status: 500, body: { error: existing.error.message } };
  }
  if (!existing.data) {
    return { status: 404, body: { error: "Candidate not found" } };
  }

  const targetUrl = typeof input.website === "string" &&
      input.website.trim() !== ""
    ? input.website.trim()
    : existing.data.website;
  const check = await verifyCandidateUrl(targetUrl, fetchFn, nowIso, resolveDnsFn);
  const updated = await store.updateCandidate(id, {
    source_url_status_code: check.statusCode,
    source_url_checked_at: check.checkedAt,
    source_url_error: check.error,
    needs_manual_review: check.needsManualReview,
  });
  if (updated.error || !updated.data) {
    return {
      status: 500,
      body: { error: updated.error?.message ?? "Failed to update verification" },
    };
  }
  return {
    status: 200,
    body: {
      success: true,
      candidate: updated.data,
    },
  };
}

export async function handleCompetitorCandidateReview(
  store: CompetitorCandidateStore,
  caller: CandidateCallerContext,
  input: Record<string, unknown>,
  nowIso: string = new Date().toISOString(),
): Promise<CandidateServiceResponse> {
  const denied = await authorizeCandidateAdmin(store, caller);
  if (denied) return denied;
  const id = typeof input.candidate_id === "string"
    ? input.candidate_id.trim()
    : "";
  const rawDecision = typeof input.decision === "string"
    ? input.decision.trim().toLowerCase()
    : "";
  if (!id) {
    return { status: 400, body: { error: "candidate_id is required" } };
  }
  if (rawDecision !== "approved" && rawDecision !== "rejected") {
    return {
      status: 400,
      body: { error: "decision must be 'approved' or 'rejected'" },
    };
  }

  const reason = typeof input.rejected_reason === "string"
    ? input.rejected_reason.trim().slice(0, 300)
    : "";

  const updated = await store.updateCandidate(id, {
    reviewed: true,
    needs_manual_review: false,
    review_decision: rawDecision,
    reviewed_at: nowIso,
    rejected_reason: rawDecision === "rejected"
      ? (reason !== "" ? reason : "Manual review rejected")
      : null,
  });
  if (updated.error) {
    return { status: 500, body: { error: updated.error.message } };
  }
  if (!updated.data) {
    return { status: 404, body: { error: "Candidate not found" } };
  }
  return {
    status: 200,
    body: {
      success: true,
      candidate: updated.data,
    },
  };
}
