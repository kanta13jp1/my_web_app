import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

interface AdminUsersRequest {
  page?: number;
  perPage?: number;
}

// deno-lint-ignore no-explicit-any
type AdminClient = any;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST" && req.method !== "GET") {
      throw new Error("Method not allowed.");
    }
    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      throw new Error("Missing Supabase runtime environment variables.");
    }

    const admin: AdminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // Require authenticated user (admin check)
    await requireAuthUser(admin, req);

    const body = req.method === "POST"
      ? (await req.json().catch(() => ({}))) as AdminUsersRequest
      : {} as AdminUsersRequest;
    const page = Math.max(1, body.page ?? 1);
    const perPage = Math.min(100, Math.max(1, body.perPage ?? 50));

    // List auth users using service role
    const { data, error } = await admin.auth.admin.listUsers({
      page,
      perPage,
    });
    if (error) throw error;

    const users = data.users ?? [];
    const total = data.total ?? users.length;

    // Fetch user_profiles for display names and completeness
    const userIds = users.map((u: { id: string }) => u.id);
    const profilesResult = userIds.length > 0
      ? await admin
          .from("user_profiles")
          .select(
            "user_id, display_name, bio, avatar_url, location, twitter_handle, github_handle, website_url, is_public",
          )
          .in("user_id", userIds)
      : { data: [] };

    type ProfileRow = {
      display_name?: string;
      bio?: string;
      avatar_url?: string;
      location?: string;
      twitter_handle?: string;
      github_handle?: string;
      website_url?: string;
      is_public?: boolean;
    };
    const profiles: Record<string, ProfileRow> = {};
    for (const p of profilesResult.data ?? []) {
      profiles[p.user_id] = p;
    }

    const formattedUsers = users.map(
      (u: {
        id: string;
        email?: string;
        created_at?: string;
        last_sign_in_at?: string;
        app_metadata?: Record<string, unknown>;
        user_metadata?: Record<string, unknown>;
      }) => {
        const profile = profiles[u.id];
        const hasProfile = !!profile;
        const completedFields = hasProfile
          ? [
              profile.display_name,
              profile.bio,
              profile.avatar_url,
              profile.location,
              profile.twitter_handle,
              profile.github_handle,
              profile.website_url,
            ].filter(Boolean).length
          : 0;
        const totalFields = 7;
        const completionPct = Math.round((completedFields / totalFields) * 100);

        return {
          id: u.id,
          email: u.email ?? "",
          displayName: profile?.display_name ?? null,
          bio: profile?.bio ?? null,
          avatarUrl: profile?.avatar_url ?? null,
          location: profile?.location ?? null,
          twitterHandle: profile?.twitter_handle ?? null,
          githubHandle: profile?.github_handle ?? null,
          websiteUrl: profile?.website_url ?? null,
          isPublic: profile?.is_public ?? true,
          hasProfile,
          completionPct,
          createdAt: u.created_at ?? null,
          lastSignInAt: u.last_sign_in_at ?? null,
          provider: (u.app_metadata?.["provider"] as string) ?? "email",
        };
      },
    );

    return jsonResponse({
      success: true,
      users: formattedUsers,
      total,
      page,
      perPage,
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ success: false, error: message }, 400);
  }
});

async function requireAuthUser(admin: AdminClient, req: Request) {
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.slice(7).trim()
    : "";
  if (token === "") throw new Error("Authorization token is required.");
  const { data, error } = await admin.auth.getUser(token);
  if (error) throw error;
  if (!data.user) throw new Error("Authenticated user not found.");
  return data.user;
}

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
