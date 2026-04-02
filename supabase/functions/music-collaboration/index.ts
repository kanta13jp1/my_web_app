import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

// Collaboration session types
const SESSION_TYPES = ["jam", "remix", "duet", "band_practice", "lesson"] as const;
const MAX_COLLABORATORS = 8;

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    const url = new URL(req.url);
    const action = url.searchParams.get("action") ?? "feed";

    // GET: Public recording feed
    if (action === "feed" && req.method === "GET") {
      const sortBy = url.searchParams.get("sort") ?? "recent"; // recent, popular, trending
      const genre = url.searchParams.get("genre");
      const limit = parseInt(url.searchParams.get("limit") ?? "20");

      const { data: recordings } = await supabase
        .from("app_analytics")
        .select("*")
        .eq("source", "guitar-recording-studio")
        .eq("event_type", "recording_saved")
        .order("created_at", { ascending: false })
        .limit(200);

      let publicRecordings = (recordings ?? [])
        .filter((r: Record<string, unknown>) => {
          const ed = r.event_data as Record<string, unknown>;
          return ed?.isPublic === true;
        })
        .map((r: Record<string, unknown>) => ({
          ...(r.event_data as Record<string, unknown>),
          createdAt: r.created_at,
        }));

      // Filter by genre/preset if specified
      if (genre) {
        publicRecordings = publicRecordings.filter(
          (r: Record<string, unknown>) => r.preset === genre || (r.tags as string[] | undefined)?.includes(genre)
        );
      }

      // Sort
      if (sortBy === "popular") {
        publicRecordings.sort((a: Record<string, unknown>, b: Record<string, unknown>) =>
          ((b.likes as number) ?? 0) - ((a.likes as number) ?? 0)
        );
      } else if (sortBy === "trending") {
        // Trending = most likes in last 7 days
        const weekAgo = new Date(Date.now() - 7 * 86400000).toISOString();
        publicRecordings = publicRecordings.filter(
          (r: Record<string, unknown>) => (r.createdAt as string) >= weekAgo
        );
        publicRecordings.sort((a: Record<string, unknown>, b: Record<string, unknown>) =>
          ((b.plays as number) ?? 0) - ((a.plays as number) ?? 0)
        );
      }

      return new Response(
        JSON.stringify({
          recordings: publicRecordings.slice(0, limit),
          totalCount: publicRecordings.length,
          sortBy,
          genre: genre ?? "all",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // GET: Collaboration sessions
    if (action === "sessions") {
      const status = url.searchParams.get("status") ?? "active"; // active, completed, all

      const { data: sessions } = await supabase
        .from("app_analytics")
        .select("*")
        .eq("source", "music-collaboration")
        .eq("event_type", "collab_session")
        .order("created_at", { ascending: false })
        .limit(50);

      const filtered = status === "all"
        ? sessions ?? []
        : (sessions ?? []).filter((s: Record<string, unknown>) => {
            const ed = s.event_data as Record<string, unknown>;
            return ed?.status === status;
          });

      return new Response(
        JSON.stringify({
          sessions: filtered.map((s: Record<string, unknown>) => ({
            ...(s.event_data as Record<string, unknown>),
            createdAt: s.created_at,
          })),
          totalCount: filtered.length,
          sessionTypes: SESSION_TYPES,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // GET: User's collaboration history
    if (action === "my_collabs") {
      const userId = url.searchParams.get("userId");
      if (!userId) {
        return new Response(
          JSON.stringify({ error: "userId is required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { data: collabs } = await supabase
        .from("app_analytics")
        .select("*")
        .eq("source", "music-collaboration")
        .order("created_at", { ascending: false })
        .limit(100);

      const userCollabs = (collabs ?? []).filter((c: Record<string, unknown>) => {
        const ed = c.event_data as Record<string, unknown>;
        const members = (ed?.collaborators as string[]) ?? [];
        return ed?.creatorId === userId || members.includes(userId);
      });

      return new Response(
        JSON.stringify({
          collaborations: userCollabs.map((c: Record<string, unknown>) => ({
            ...(c.event_data as Record<string, unknown>),
            createdAt: c.created_at,
          })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // POST actions
    if (req.method === "POST") {
      const body = await req.json();
      const postAction = body.action ?? action;

      // Create a collaboration session
      if (postAction === "create_session") {
        const { creatorId, title, sessionType, maxCollaborators, description, bpm, key } = body;

        if (!creatorId || !title) {
          return new Response(
            JSON.stringify({ error: "creatorId and title are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        const sessionId = crypto.randomUUID();
        const inviteCode = Math.random().toString(36).substring(2, 8).toUpperCase();

        const { error: createErr } = await supabase.from("app_analytics").insert({
          source: "music-collaboration",
          event_type: "collab_session",
          event_data: {
            sessionId,
            creatorId,
            title,
            sessionType: sessionType ?? "jam",
            status: "active",
            maxCollaborators: Math.min(maxCollaborators ?? 4, MAX_COLLABORATORS),
            collaborators: [creatorId],
            description: description ?? "",
            bpm: bpm ?? 120,
            key: key ?? "C",
            inviteCode,
            tracks: [],
            createdAt: new Date().toISOString(),
          },
        });

        if (createErr) {
          return new Response(
            JSON.stringify({ error: createErr.message }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        return new Response(
          JSON.stringify({ success: true, sessionId, inviteCode }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Join a collaboration session
      if (postAction === "join_session") {
        const { inviteCode, userId } = body;

        if (!inviteCode || !userId) {
          return new Response(
            JSON.stringify({ error: "inviteCode and userId are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        const { error: joinErr } = await supabase.from("app_analytics").insert({
          source: "music-collaboration",
          event_type: "collab_joined",
          event_data: {
            inviteCode,
            userId,
            joinedAt: new Date().toISOString(),
          },
        });

        if (joinErr) {
          return new Response(
            JSON.stringify({ error: joinErr.message }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        return new Response(
          JSON.stringify({ success: true, message: "セッションに参加しました" }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Add a track to collaboration
      if (postAction === "add_track") {
        const { sessionId, userId, trackName, instrument, durationSeconds } = body;

        const { error: trackErr } = await supabase.from("app_analytics").insert({
          source: "music-collaboration",
          event_type: "track_added",
          event_data: {
            sessionId,
            userId,
            trackName: trackName ?? "Track",
            instrument: instrument ?? "guitar",
            durationSeconds: durationSeconds ?? 0,
            addedAt: new Date().toISOString(),
          },
        });

        if (trackErr) {
          return new Response(
            JSON.stringify({ error: trackErr.message }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        return new Response(
          JSON.stringify({ success: true }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Share recording to social
      if (postAction === "share") {
        const { recordingId, platform, userId } = body;

        const shareLinks: Record<string, string> = {
          x: `https://twitter.com/intent/tweet?text=${encodeURIComponent("🎸 自分スタジオで録音しました！ #自分株式会社 #ギター録音")}&url=${encodeURIComponent("https://my-web-app-b67f4.web.app/guitar-studio")}`,
          line: `https://social-plugins.line.me/lineit/share?url=${encodeURIComponent("https://my-web-app-b67f4.web.app/guitar-studio")}`,
          facebook: `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent("https://my-web-app-b67f4.web.app/guitar-studio")}`,
        };

        const { error: shareErr } = await supabase.from("app_analytics").insert({
          source: "music-collaboration",
          event_type: "recording_shared",
          event_data: { recordingId, platform, userId, sharedAt: new Date().toISOString() },
        });

        if (shareErr) {
          return new Response(
            JSON.stringify({ error: shareErr.message }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        return new Response(
          JSON.stringify({
            success: true,
            shareUrl: shareLinks[platform ?? "x"] ?? shareLinks["x"],
            platform: platform ?? "x",
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({ error: "Unknown POST action" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        error: "Unknown action",
        validActions: ["feed", "sessions", "my_collabs"],
        postActions: ["create_session", "join_session", "add_track", "share"],
      }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
