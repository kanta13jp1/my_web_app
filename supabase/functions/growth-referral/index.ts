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

type GrowthReferralAction = "ensure_code" | "apply_pending" | "load_snapshot";

interface GrowthReferralRequest {
  action?: GrowthReferralAction;
  pendingCode?: string;
}

interface ReferralSnapshotPayload {
  referralCode: Record<string, unknown> | null;
  totalReferrals: number;
  successfulReferrals: number;
}

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
    value === "load_snapshot";
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
