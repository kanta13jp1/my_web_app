import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const REFERRAL_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const REFERRAL_LENGTH = 8;
const REFERRAL_BONUS_POINTS = 500;
/** Max referral applications a single account can trigger in one UTC day. */
const MAX_REFERRALS_PER_DAY = 5;
/** Min account age in milliseconds before the account may be referred. */
const MIN_ACCOUNT_AGE_MS = 60 * 60 * 1000; // 1 hour

type GrowthReferralAction =
  | "ensure_code"
  | "apply_pending"
  | "load_snapshot"
  | "check_abuse";

interface GrowthReferralRequest {
  action?: GrowthReferralAction;
  pendingCode?: string;
}

interface ReferralSnapshotPayload {
  referralCode: Record<string, unknown> | null;
  totalReferrals: number;
  successfulReferrals: number;
}

// deno-lint-ignore no-explicit-any
type AdminClient = any;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      throw new Error("Method not allowed.");
    }
    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      throw new Error("Missing Supabase runtime environment variables.");
    }

    const body = (await req.json().catch(() => ({}))) as GrowthReferralRequest;
    const action = body.action ?? "load_snapshot";
    if (!isSupportedAction(action)) {
      throw new Error("Unsupported referral action.");
    }

    const admin: AdminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const user = await requireUser(admin, req);

    switch (action) {
      case "ensure_code": {
        const referralCode = await ensureReferralCode(admin, user.id);
        return jsonResponse({
          success: true,
          action,
          referralCode,
        });
      }
      case "apply_pending": {
        const pendingCode = normalizeCode(body.pendingCode);
        if (pendingCode == null) {
          throw new Error("pendingCode is required for apply_pending.");
        }

        const result = await applyPendingReferral({
          admin,
          pendingCode,
          referredUserId: user.id,
        });

        return jsonResponse({
          success: true,
          action,
          ...result,
        });
      }
      case "check_abuse": {
        const abuseReport = await checkAbuseReport(admin, user.id);
        return jsonResponse({
          success: true,
          action,
          ...abuseReport,
        });
      }
      case "load_snapshot":
      default: {
        const snapshot = await loadReferralSnapshot(admin, user.id);
        return jsonResponse({
          success: true,
          action,
          ...snapshot,
        });
      }
    }
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ success: false, error: message }, 400);
  }
});

function isSupportedAction(value: string): value is GrowthReferralAction {
  return value === "ensure_code" || value === "apply_pending" ||
    value === "load_snapshot" || value === "check_abuse";
}

async function requireUser(
  admin: AdminClient,
  req: Request,
) {
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.slice(7).trim()
    : "";
  if (token === "") {
    throw new Error("Authorization token is required.");
  }

  const { data, error } = await admin.auth.getUser(token);
  if (error) {
    throw error;
  }
  if (!data.user) {
    throw new Error("Authenticated user not found.");
  }
  return data.user;
}

async function ensureReferralCode(
  admin: AdminClient,
  userId: string,
) {
  const existing = await admin
    .from("referral_codes")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();
  if (existing.error) {
    throw existing.error;
  }
  if (existing.data) {
    return existing.data;
  }

  for (let attempt = 0; attempt < 8; attempt += 1) {
    const referralCode = generateReferralCode();
    const insertResult = await admin.from("referral_codes").insert({
      user_id: userId,
      referral_code: referralCode,
    }).select("*").maybeSingle();

    if (insertResult.error == null && insertResult.data) {
      return insertResult.data;
    }
  }

  const fallback = await admin
    .from("referral_codes")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();
  if (fallback.error) {
    throw fallback.error;
  }
  if (!fallback.data) {
    throw new Error("Referral code could not be created.");
  }
  return fallback.data;
}

async function applyPendingReferral({
  admin,
  pendingCode,
  referredUserId,
}: {
  admin: AdminClient;
  pendingCode: string;
  referredUserId: string;
}) {
  const existingReferral = await admin
    .from("referrals")
    .select("id, status, referral_code")
    .eq("referred_user_id", referredUserId)
    .maybeSingle();
  if (existingReferral.error) {
    throw existingReferral.error;
  }
  if (existingReferral.data) {
    return {
      applied: false,
      clearPendingCode: true,
      reason: "already_applied",
    };
  }

  const referrer = await admin
    .from("referral_codes")
    .select("user_id, referral_code")
    .eq("referral_code", pendingCode)
    .maybeSingle();
  if (referrer.error) {
    throw referrer.error;
  }
  if (!referrer.data) {
    return {
      applied: false,
      clearPendingCode: false,
      reason: "invalid_code",
    };
  }

  const referrerUserId = referrer.data.user_id?.toString() ?? "";
  if (referrerUserId === "" || referrerUserId === referredUserId) {
    return {
      applied: false,
      clearPendingCode: true,
      reason: "self_referral_blocked",
    };
  }

  // ---- Anti-abuse: rate limit ----------------------------------------
  const todayStart = new Date();
  todayStart.setUTCHours(0, 0, 0, 0);
  const dailyCount = await admin
    .from("referrals")
    .select("id", { count: "exact", head: true })
    .eq("referrer_user_id", referrerUserId)
    .gte("completed_at", todayStart.toISOString());
  if (!dailyCount.error && (dailyCount.count ?? 0) >= MAX_REFERRALS_PER_DAY) {
    return {
      applied: false,
      clearPendingCode: false,
      reason: "rate_limit_exceeded",
    };
  }

  // ---- Anti-abuse: minimum account age --------------------------------
  const userMeta = await admin.auth.admin.getUserById(referredUserId);
  if (!userMeta.error && userMeta.data?.user?.created_at) {
    const createdAt = new Date(userMeta.data.user.created_at).getTime();
    const ageMs = Date.now() - createdAt;
    if (ageMs < MIN_ACCOUNT_AGE_MS) {
      return {
        applied: false,
        clearPendingCode: false,
        reason: "account_too_new",
      };
    }
  }

  const insertResult = await admin.from("referrals").insert({
    referrer_user_id: referrerUserId,
    referred_user_id: referredUserId,
    referral_code: pendingCode,
    bonus_points: REFERRAL_BONUS_POINTS,
    status: "completed",
    completed_at: new Date().toISOString(),
  });
  if (insertResult.error) {
    throw insertResult.error;
  }

  await refreshReferralCodeCounters(admin, referrerUserId);

  return {
    applied: true,
    clearPendingCode: true,
    reason: "completed",
  };
}

async function loadReferralSnapshot(
  admin: AdminClient,
  userId: string,
): Promise<ReferralSnapshotPayload> {
  const referralCode = await ensureReferralCode(admin, userId);

  const referrals = await admin
    .from("referrals")
    .select("status")
    .eq("referrer_user_id", userId);
  if (referrals.error) {
    throw referrals.error;
  }

  const referralRows = referrals.data ?? [];
  const successfulReferrals =
    // deno-lint-ignore no-explicit-any
    referralRows.filter((row: any) => row.status?.toString() === "completed")
      .length;

  await refreshReferralCodeCounters(
    admin,
    userId,
    referralRows.length,
    successfulReferrals,
  );

  const refreshedCode = await admin
    .from("referral_codes")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();
  if (refreshedCode.error) {
    throw refreshedCode.error;
  }

  return {
    referralCode: refreshedCode.data ?? referralCode,
    totalReferrals: referralRows.length,
    successfulReferrals,
  };
}

/**
 * Scans the referrals table for patterns that indicate abuse:
 * - Users who received more than MAX_REFERRALS_PER_DAY referrals in one day
 * - Users with referral attempts blocked in the last 24 hours (via reason field)
 * Returns a summary that the admin analytics page can display.
 */
async function checkAbuseReport(admin: AdminClient, _requestingUserId: string) {
  const since = new Date();
  since.setUTCDate(since.getUTCDate() - 7);

  const referrals = await admin
    .from("referrals")
    .select("referrer_user_id, referred_user_id, status, completed_at")
    .gte("completed_at", since.toISOString())
    .order("completed_at", { ascending: false });

  if (referrals.error) {
    throw referrals.error;
  }

  const rows: Array<Record<string, unknown>> = referrals.data ?? [];

  // Group by referrer, count completions per UTC day
  const referrerDayCounts: Record<string, Record<string, number>> = {};
  for (const row of rows) {
    if (row["status"]?.toString() !== "completed") continue;
    const referrerId = row["referrer_user_id"]?.toString() ?? "";
    const dayKey = (row["completed_at"]?.toString() ?? "").slice(0, 10);
    if (!referrerId || !dayKey) continue;
    referrerDayCounts[referrerId] ??= {};
    referrerDayCounts[referrerId][dayKey] =
      (referrerDayCounts[referrerId][dayKey] ?? 0) + 1;
  }

  const suspiciousReferrers: Array<{
    referrerId: string;
    maxPerDay: number;
    totalCompleted: number;
  }> = [];

  for (const [referrerId, dayCounts] of Object.entries(referrerDayCounts)) {
    const maxPerDay = Math.max(...Object.values(dayCounts));
    const totalCompleted = Object.values(dayCounts).reduce((a, b) => a + b, 0);
    if (maxPerDay >= MAX_REFERRALS_PER_DAY) {
      suspiciousReferrers.push({ referrerId, maxPerDay, totalCompleted });
    }
  }

  return {
    windowDays: 7,
    since: since.toISOString(),
    totalRows: rows.length,
    suspiciousReferrers,
    flagged: suspiciousReferrers.length > 0,
  };
}

async function refreshReferralCodeCounters(
  admin: AdminClient,
  userId: string,
  totalReferrals?: number,
  successfulReferrals?: number,
) {
  let nextTotal = totalReferrals;
  let nextSuccessful = successfulReferrals;

  if (nextTotal == null || nextSuccessful == null) {
    const referrals = await admin
      .from("referrals")
      .select("status")
      .eq("referrer_user_id", userId);
    if (referrals.error) {
      throw referrals.error;
    }

    const rows = referrals.data ?? [];
    nextTotal = rows.length;
    // deno-lint-ignore no-explicit-any
    nextSuccessful = rows.filter((row: any) =>
      row.status?.toString() === "completed"
    ).length;
  }

  const updateResult = await admin
    .from("referral_codes")
    .update({
      total_referrals: nextTotal,
      successful_referrals: nextSuccessful,
      bonus_points_earned: (nextSuccessful ?? 0) * REFERRAL_BONUS_POINTS,
    })
    .eq("user_id", userId);

  if (updateResult.error) {
    throw updateResult.error;
  }
}

function generateReferralCode(): string {
  const characters = REFERRAL_ALPHABET.split("");
  const values = crypto.getRandomValues(new Uint32Array(REFERRAL_LENGTH));
  let result = "";
  for (const value of values) {
    result += characters[value % characters.length];
  }
  return result;
}

function normalizeCode(value: string | undefined): string | null {
  const normalized = value?.trim().toUpperCase() ?? "";
  return normalized === "" ? null : normalized;
}

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
