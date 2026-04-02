import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
};

// Guitar tuning frequencies (Hz)
const TUNINGS: Record<string, Record<string, number>> = {
  standard: { E2: 82.41, A2: 110.0, D3: 146.83, G3: 196.0, B3: 246.94, E4: 329.63 },
  drop_d: { D2: 73.42, A2: 110.0, D3: 146.83, G3: 196.0, B3: 246.94, E4: 329.63 },
  open_g: { D2: 73.42, G2: 98.0, D3: 146.83, G3: 196.0, B3: 246.94, D4: 293.66 },
  open_d: { D2: 73.42, A2: 110.0, D3: 146.83, "F#3": 185.0, A3: 220.0, D4: 293.66 },
  dadgad: { D2: 73.42, A2: 110.0, D3: 146.83, G3: 196.0, A3: 220.0, D4: 293.66 },
};

// Chord library for reference
const CHORD_LIBRARY: Record<string, { frets: number[]; fingers: string }> = {
  C: { frets: [0, 3, 2, 0, 1, 0], fingers: "x32010" },
  D: { frets: [-1, -1, 0, 2, 3, 2], fingers: "xx0232" },
  E: { frets: [0, 2, 2, 1, 0, 0], fingers: "022100" },
  F: { frets: [1, 3, 3, 2, 1, 1], fingers: "133211" },
  G: { frets: [3, 2, 0, 0, 0, 3], fingers: "320003" },
  A: { frets: [0, 0, 2, 2, 2, 0], fingers: "002220" },
  B: { frets: [-1, 2, 4, 4, 4, 2], fingers: "x24442" },
  Am: { frets: [0, 0, 2, 2, 1, 0], fingers: "002210" },
  Em: { frets: [0, 2, 2, 0, 0, 0], fingers: "022000" },
  Dm: { frets: [-1, -1, 0, 2, 3, 1], fingers: "xx0231" },
  "C7": { frets: [0, 3, 2, 3, 1, 0], fingers: "032310" },
  "G7": { frets: [3, 2, 0, 0, 0, 1], fingers: "320001" },
  "A7": { frets: [0, 0, 2, 0, 2, 0], fingers: "002020" },
  "Cmaj7": { frets: [0, 3, 2, 0, 0, 0], fingers: "032000" },
  "Fmaj7": { frets: [1, 3, 3, 2, 1, 0], fingers: "133210" },
};

// Genre-specific recording presets
const RECORDING_PRESETS: Record<string, { bpm: number; timeSignature: string; effects: string[]; description: string }> = {
  acoustic_fingerpicking: { bpm: 80, timeSignature: "4/4", effects: ["reverb_hall", "compressor_light"], description: "繊細なフィンガーピッキング向け" },
  rock_rhythm: { bpm: 120, timeSignature: "4/4", effects: ["distortion_medium", "reverb_room"], description: "ロックリズムギター向け" },
  blues_lead: { bpm: 90, timeSignature: "12/8", effects: ["overdrive", "delay_slap", "reverb_spring"], description: "ブルースリードギター向け" },
  jazz_clean: { bpm: 110, timeSignature: "4/4", effects: ["chorus", "reverb_plate", "compressor_medium"], description: "ジャズクリーントーン向け" },
  metal_heavy: { bpm: 160, timeSignature: "4/4", effects: ["distortion_heavy", "noise_gate", "compressor_heavy"], description: "ヘビーメタル向け" },
  classical: { bpm: 70, timeSignature: "3/4", effects: ["reverb_cathedral"], description: "クラシックギター向け" },
  funk_rhythm: { bpm: 100, timeSignature: "4/4", effects: ["wah_auto", "compressor_heavy", "phaser"], description: "ファンクリズム向け" },
  ambient: { bpm: 60, timeSignature: "4/4", effects: ["delay_long", "reverb_shimmer", "chorus", "tremolo"], description: "アンビエント・ポストロック向け" },
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    const url = new URL(req.url);
    const action = url.searchParams.get("action") ?? "dashboard";

    // ---- GET actions ----

    // Dashboard: recording studio overview
    if (action === "dashboard" && req.method === "GET") {
      const userId = url.searchParams.get("userId");

      // Get user's recordings
      const { data: recordings } = await supabase
        .from("app_analytics")
        .select("*")
        .eq("source", "guitar-recording-studio")
        .eq("metadata->>event_type", "recording_saved")
        .order("created_at", { ascending: false })
        .limit(50);

      // Get user-specific recordings if userId provided
      const userRecordings = userId
        ? (recordings ?? []).filter((r: Record<string, unknown>) => {
            const ed = r.metadata as Record<string, unknown>;
            return ed?.userId === userId;
          })
        : [];

      // Get total recording stats
      const totalRecordings = (recordings ?? []).length;
      const totalDuration = (recordings ?? []).reduce((sum: number, r: Record<string, unknown>) => {
        const ed = r.metadata as Record<string, unknown>;
        return sum + ((ed?.durationSeconds as number) ?? 0);
      }, 0);

      return new Response(
        JSON.stringify({
          studio: {
            name: "自分スタジオ",
            description: "スマホでギター演奏を録音・編集・共有",
            version: "1.0.0",
          },
          stats: {
            totalRecordings,
            totalDurationMinutes: Math.round(totalDuration / 60),
            userRecordingCount: userRecordings.length,
          },
          tunings: Object.keys(TUNINGS),
          presets: Object.entries(RECORDING_PRESETS).map(([key, preset]) => ({
            id: key,
            ...preset,
          })),
          chordLibrary: Object.keys(CHORD_LIBRARY),
          features: [
            "スマホ録音 (Web Audio API)",
            "チューナー機能",
            "メトロノーム",
            "エフェクト (リバーブ/ディストーション/ディレイ等)",
            "録音プリセット (8ジャンル)",
            "コード辞典",
            "マルチトラック重ね録り",
            "録音の共有・コラボレーション",
            "練習記録・統計",
          ],
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Tuner data
    if (action === "tuner") {
      const tuning = url.searchParams.get("tuning") ?? "standard";
      const tuningData = TUNINGS[tuning] ?? TUNINGS["standard"];

      return new Response(
        JSON.stringify({
          tuning,
          strings: Object.entries(tuningData).map(([note, freq]) => ({
            note,
            frequency: freq,
            tolerance: 2, // Hz tolerance for "in tune"
          })),
          availableTunings: Object.keys(TUNINGS),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Chord lookup
    if (action === "chord") {
      const chordName = url.searchParams.get("name");
      if (chordName && chordName in CHORD_LIBRARY) {
        return new Response(
          JSON.stringify({
            name: chordName,
            ...CHORD_LIBRARY[chordName],
            stringNames: ["E2", "A2", "D3", "G3", "B3", "E4"],
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({
          chords: Object.entries(CHORD_LIBRARY).map(([name, data]) => ({
            name,
            ...data,
          })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Recording presets
    if (action === "presets") {
      return new Response(
        JSON.stringify({
          presets: Object.entries(RECORDING_PRESETS).map(([key, preset]) => ({
            id: key,
            ...preset,
          })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Metronome config
    if (action === "metronome") {
      const bpm = parseInt(url.searchParams.get("bpm") ?? "120");
      const timeSignature = url.searchParams.get("timeSignature") ?? "4/4";
      const [beats, beatValue] = timeSignature.split("/").map(Number);

      return new Response(
        JSON.stringify({
          bpm: Math.max(30, Math.min(300, bpm)),
          timeSignature,
          beats,
          beatValue,
          intervalMs: Math.round(60000 / bpm),
          accentPattern: Array.from({ length: beats }, (_, i) => i === 0 ? "accent" : "normal"),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // User's recording history
    if (action === "recordings") {
      const userId = url.searchParams.get("userId");
      if (!userId) {
        return new Response(
          JSON.stringify({ error: "userId is required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { data: recordings } = await supabase
        .from("app_analytics")
        .select("*")
        .eq("source", "guitar-recording-studio")
        .eq("metadata->>event_type", "recording_saved")
        .order("created_at", { ascending: false })
        .limit(100);

      const userRecordings = (recordings ?? [])
        .filter((r: Record<string, unknown>) => {
          const ed = r.metadata as Record<string, unknown>;
          return ed?.userId === userId;
        })
        .map((r: Record<string, unknown>) => ({
          ...(r.metadata as Record<string, unknown>),
          createdAt: r.created_at,
        }));

      return new Response(
        JSON.stringify({
          recordings: userRecordings,
          totalCount: userRecordings.length,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Practice stats
    if (action === "practice_stats") {
      const userId = url.searchParams.get("userId");
      if (!userId) {
        return new Response(
          JSON.stringify({ error: "userId is required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { data: sessions } = await supabase
        .from("app_analytics")
        .select("*")
        .eq("source", "guitar-recording-studio")
        .in("metadata->>event_type", ["recording_saved", "practice_session"])
        .order("created_at", { ascending: false })
        .limit(500);

      const userSessions = (sessions ?? []).filter((s: Record<string, unknown>) => {
        const ed = s.metadata as Record<string, unknown>;
        return ed?.userId === userId;
      });

      const totalMinutes = userSessions.reduce((sum: number, s: Record<string, unknown>) => {
        const ed = s.metadata as Record<string, unknown>;
        return sum + ((ed?.durationSeconds as number) ?? 0) / 60;
      }, 0);

      // Weekly breakdown
      const now = new Date();
      const weeklyData: Array<{ week: string; minutes: number; sessions: number }> = [];
      for (let w = 3; w >= 0; w--) {
        const weekStart = new Date(now.getTime() - (w + 1) * 7 * 86400000);
        const weekEnd = new Date(now.getTime() - w * 7 * 86400000);
        const weekSessions = userSessions.filter((s: Record<string, unknown>) =>
          (s.created_at as string) >= weekStart.toISOString() &&
          (s.created_at as string) < weekEnd.toISOString()
        );
        const minutes = weekSessions.reduce((sum: number, s: Record<string, unknown>) => {
          const ed = s.metadata as Record<string, unknown>;
          return sum + ((ed?.durationSeconds as number) ?? 0) / 60;
        }, 0);
        weeklyData.push({
          week: weekStart.toISOString().split("T")[0],
          minutes: Math.round(minutes),
          sessions: weekSessions.length,
        });
      }

      return new Response(
        JSON.stringify({
          totalSessions: userSessions.length,
          totalMinutes: Math.round(totalMinutes),
          streakDays: calculateStreak(userSessions),
          weeklyBreakdown: weeklyData,
          favoritePreset: findFavoritePreset(userSessions),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ---- POST actions ----

    if (req.method === "POST") {
      const body = await req.json();
      const postAction = body.action ?? action;

      // Save a recording
      if (postAction === "save_recording") {
        const { userId, title, durationSeconds, preset, tuning, bpm, tracks, tags, isPublic } = body;

        if (!userId || !title) {
          return new Response(
            JSON.stringify({ error: "userId and title are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        const recordingId = crypto.randomUUID();
        const recording = {
          source: "guitar-recording-studio",
          metadata: {
            event_type: "recording_saved",
            recordingId,
            userId,
            title,
            durationSeconds: durationSeconds ?? 0,
            preset: preset ?? "acoustic_fingerpicking",
            tuning: tuning ?? "standard",
            bpm: bpm ?? 120,
            trackCount: tracks ?? 1,
            tags: tags ?? [],
            isPublic: isPublic ?? false,
            likes: 0,
            plays: 0,
            createdAt: new Date().toISOString(),
          },
        };

        const { error: insertError } = await supabase
          .from("app_analytics")
          .insert(recording);

        if (insertError) {
          return new Response(
            JSON.stringify({ error: insertError.message }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        return new Response(
          JSON.stringify({ success: true, recordingId, recording: recording.metadata }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Log a practice session
      if (postAction === "log_practice") {
        const { userId, durationSeconds, preset, exercises, notes } = body;

        if (!userId) {
          return new Response(
            JSON.stringify({ error: "userId is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        const { error: practiceErr } = await supabase.from("app_analytics").insert({
          source: "guitar-recording-studio",
          metadata: {
            event_type: "practice_session",
            userId,
            durationSeconds: durationSeconds ?? 0,
            preset: preset ?? null,
            exercises: exercises ?? [],
            notes: notes ?? "",
            practicedAt: new Date().toISOString(),
          },
        });

        if (practiceErr) {
          return new Response(
            JSON.stringify({ error: practiceErr.message }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        return new Response(
          JSON.stringify({ success: true }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Like a recording
      if (postAction === "like_recording") {
        const { recordingId, userId } = body;

        const { error: likeErr } = await supabase.from("app_analytics").insert({
          source: "guitar-recording-studio",
          metadata: { event_type: "recording_liked", recordingId, userId, likedAt: new Date().toISOString() },
        });

        if (likeErr) {
          return new Response(
            JSON.stringify({ error: likeErr.message }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        return new Response(
          JSON.stringify({ success: true }),
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
        validActions: ["dashboard", "tuner", "chord", "presets", "metronome", "recordings", "practice_stats"],
        postActions: ["save_recording", "log_practice", "like_recording"],
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

function calculateStreak(sessions: Record<string, unknown>[]): number {
  if (sessions.length === 0) return 0;
  const dates = [...new Set(
    sessions.map((s) => (s.created_at as string).split("T")[0])
  )].sort().reverse();

  let streak = 0;
  const today = new Date().toISOString().split("T")[0];
  const yesterday = new Date(Date.now() - 86400000).toISOString().split("T")[0];

  // Allow streak to start from today or yesterday
  const startOffset = dates[0] === today ? 0 : dates[0] === yesterday ? 1 : -1;
  if (startOffset === -1) return 0;

  for (let i = 0; i < dates.length; i++) {
    const expected = new Date(Date.now() - (i + startOffset) * 86400000).toISOString().split("T")[0];
    if (dates[i] === expected) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

function findFavoritePreset(sessions: Record<string, unknown>[]): string {
  const counts: Record<string, number> = {};
  for (const s of sessions) {
    const ed = s.metadata as Record<string, unknown>;
    const preset = (ed?.preset as string) ?? "unknown";
    counts[preset] = (counts[preset] ?? 0) + 1;
  }
  const sorted = Object.entries(counts).sort((a, b) => b[1] - a[1]);
  return sorted.length > 0 ? sorted[0][0] : "none";
}
