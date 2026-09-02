import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import {
  createClient,
  type SupabaseClient,
  type User,
} from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Max-Age": "86400",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";

const RECORDING_BUCKET = "guitar-recordings";
const SHARE_BASE_URL =
  "https://my-web-app-b67f4.web.app/#/guitar-recording-studio";
const APP_URL = "https://my-web-app-b67f4.web.app/";

type Json = Record<string, unknown>;

type GuitarRecordingRow = {
  id: string;
  user_id: string;
  title: string;
  duration_seconds: number;
  preset: string;
  tuning: string;
  bpm: number;
  track_count: number;
  tags: string[] | null;
  is_public: boolean;
  likes: number;
  plays: number;
  file_url: string | null;
  file_path: string | null;
  file_mime_type: string | null;
  file_size_bytes: number | null;
  export_format: string;
  duration_display: string | null;
  ai_feedback: string | null;
  ai_feedback_source: string | null;
  created_at: string;
  updated_at: string;
};

type AuthContext = {
  adminClient: SupabaseClient;
  userClient: SupabaseClient | null;
  user: User | null;
};

const TUNINGS: Record<string, Record<string, number>> = {
  standard: {
    E2: 82.41,
    A2: 110.0,
    D3: 146.83,
    G3: 196.0,
    B3: 246.94,
    E4: 329.63,
  },
  drop_d: {
    D2: 73.42,
    A2: 110.0,
    D3: 146.83,
    G3: 196.0,
    B3: 246.94,
    E4: 329.63,
  },
  open_g: {
    D2: 73.42,
    G2: 98.0,
    D3: 146.83,
    G3: 196.0,
    B3: 246.94,
    D4: 293.66,
  },
  open_d: {
    D2: 73.42,
    A2: 110.0,
    D3: 146.83,
    "F#3": 185.0,
    A3: 220.0,
    D4: 293.66,
  },
  dadgad: {
    D2: 73.42,
    A2: 110.0,
    D3: 146.83,
    G3: 196.0,
    A3: 220.0,
    D4: 293.66,
  },
};

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
  C7: { frets: [0, 3, 2, 3, 1, 0], fingers: "032310" },
  G7: { frets: [3, 2, 0, 0, 0, 1], fingers: "320001" },
  A7: { frets: [0, 0, 2, 0, 2, 0], fingers: "002020" },
  Cmaj7: { frets: [0, 3, 2, 0, 0, 0], fingers: "032000" },
  Fmaj7: { frets: [1, 3, 3, 2, 1, 0], fingers: "133210" },
};

const RECORDING_PRESETS: Record<
  string,
  { bpm: number; timeSignature: string; effects: string[]; description: string }
> = {
  acoustic_fingerpicking: {
    bpm: 80,
    timeSignature: "4/4",
    effects: ["reverb_hall", "compressor_light"],
    description: "アコースティックの粒立ちを活かすフィンガーピッキング向け",
  },
  rock_rhythm: {
    bpm: 120,
    timeSignature: "4/4",
    effects: ["distortion_medium", "reverb_room"],
    description: "ロックの刻みと厚みを作るリズムギター向け",
  },
  blues_lead: {
    bpm: 90,
    timeSignature: "12/8",
    effects: ["overdrive", "delay_slap", "reverb_spring"],
    description: "ブルースの粘りと歌い回しを出すリード向け",
  },
  jazz_clean: {
    bpm: 110,
    timeSignature: "4/4",
    effects: ["chorus", "reverb_plate", "compressor_medium"],
    description: "ジャズのクリーントーンでコード感を残す向け",
  },
  metal_heavy: {
    bpm: 160,
    timeSignature: "4/4",
    effects: ["distortion_heavy", "noise_gate", "compressor_heavy"],
    description: "ヘヴィな刻みと高密度のゲイン向け",
  },
  classical: {
    bpm: 70,
    timeSignature: "3/4",
    effects: ["reverb_cathedral"],
    description: "クラシックギターの空気感を残す向け",
  },
  funk_rhythm: {
    bpm: 100,
    timeSignature: "4/4",
    effects: ["wah_auto", "compressor_heavy", "phaser"],
    description: "カッティングの粒とグルーヴを作る向け",
  },
  ambient: {
    bpm: 60,
    timeSignature: "4/4",
    effects: ["delay_long", "reverb_shimmer", "chorus", "tremolo"],
    description: "空間系で広がりを作るアンビエント向け",
  },
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const auth = await getAuthContext(req);
    const url = new URL(req.url);
    const body = await readJsonBody(req);
    const action = normalizeString(body.action) ??
      url.searchParams.get("action") ??
      "dashboard";

    switch (action) {
      case "dashboard":
        return jsonResponse(await buildDashboard(auth.adminClient, auth.user));
      case "tuner":
        return jsonResponse(buildTunerPayload(url));
      case "chord":
        return jsonResponse(buildChordPayload(url));
      case "presets":
        return jsonResponse({
          presets: Object.entries(RECORDING_PRESETS).map(([id, preset]) => ({
            id,
            ...preset,
          })),
        });
      case "metronome":
        return jsonResponse(buildMetronomePayload(url));
      case "recordings":
        return jsonResponse({
          recordings: await listUserRecordings(auth),
        });
      case "practice_stats":
        return jsonResponse(await buildPracticeStats(auth));
      case "public_recording":
        return jsonResponse(
          await getPublicRecording(
            auth.adminClient,
            url.searchParams.get("recordingId"),
          ),
        );
      case "public_gallery":
        return jsonResponse(
          await listPublicRecordings(auth.adminClient, url, body),
        );
      case "save_recording":
        return jsonResponse(await saveRecording(auth, body));
      case "delete_recording":
        return jsonResponse(await deleteRecording(auth, body));
      case "like_recording":
        return jsonResponse(await likeRecording(auth, body));
      case "increment_play":
        return jsonResponse(await incrementPlay(auth.adminClient, body));
      case "log_practice":
        return jsonResponse(await logPracticeSession(auth, body));
      case "ai_analyze":
        return jsonResponse(await buildAiAnalysis(auth, body));
      case "share_to_x":
        return jsonResponse(await shareRecordingToX(auth, body));
      default:
        return jsonResponse(
          {
            success: false,
            error: "Unknown action",
            validActions: [
              "dashboard",
              "tuner",
              "chord",
              "presets",
              "metronome",
              "recordings",
              "practice_stats",
              "public_recording",
              "public_gallery",
              "save_recording",
              "delete_recording",
              "like_recording",
              "increment_play",
              "log_practice",
              "ai_analyze",
              "share_to_x",
            ],
          },
          400,
        );
    }
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : (error as { message?: string }).message ?? JSON.stringify(error);
    console.error(
      "[guitar-recording-studio] unhandled error:",
      JSON.stringify(error),
    );
    return jsonResponse({ success: false, error: message }, 500);
  }
});

async function getAuthContext(req: Request): Promise<AuthContext> {
  const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !SUPABASE_ANON_KEY) {
    return { adminClient, userClient: null, user: null };
  }

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false },
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user },
  } = await userClient.auth.getUser();

  return { adminClient, userClient, user: user ?? null };
}

async function readJsonBody(req: Request): Promise<Json> {
  if (req.method === "GET" || req.method === "HEAD") {
    return {};
  }

  try {
    const body = await req.clone().json();
    return typeof body === "object" && body !== null ? body as Json : {};
  } catch {
    return {};
  }
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

function requireUser(auth: AuthContext): User {
  if (!auth.user) {
    throw new Error("Authentication required");
  }
  return auth.user;
}

async function buildDashboard(adminClient: SupabaseClient, user: User | null) {
  const { data: recordings } = await adminClient
    .from("guitar_recordings")
    .select("id, duration_seconds, user_id");

  const rows = (recordings ?? []) as Array<
    Pick<GuitarRecordingRow, "id" | "duration_seconds" | "user_id">
  >;
  const totalDurationSeconds = rows.reduce(
    (sum, row) => sum + (row.duration_seconds ?? 0),
    0,
  );
  const userRecordingCount = user
    ? rows.filter((row) => row.user_id === user.id).length
    : 0;

  return {
    success: true,
    studio: {
      name: "ギターレコーディングスタジオ",
      description:
        "ブラウザだけで録音・保存・共有・AIコーチングまで行えるギター練習スタジオ",
      version: "2.0.0",
    },
    stats: {
      totalRecordings: rows.length,
      totalDurationMinutes: Math.round(totalDurationSeconds / 60),
      userRecordingCount,
    },
    tunings: Object.keys(TUNINGS),
    presets: Object.entries(RECORDING_PRESETS).map(([id, preset]) => ({
      id,
      ...preset,
    })),
    chordLibrary: Object.keys(CHORD_LIBRARY),
    features: [
      "ブラウザ録音",
      "iPhone 再生互換の保存形式",
      "共有しやすいエクスポート",
      "コード辞典",
      "メトロノーム",
      "練習履歴と統計",
      "AI コーチング",
    ],
  };
}

function buildTunerPayload(url: URL) {
  const tuning = url.searchParams.get("tuning") ?? "standard";
  const tuningData = TUNINGS[tuning] ?? TUNINGS.standard;
  return {
    success: true,
    tuning,
    strings: Object.entries(tuningData).map(([note, frequency]) => ({
      note,
      frequency,
      tolerance: 2,
    })),
    availableTunings: Object.keys(TUNINGS),
  };
}

function buildChordPayload(url: URL) {
  const chordName = url.searchParams.get("name");
  if (chordName && CHORD_LIBRARY[chordName]) {
    return {
      success: true,
      name: chordName,
      ...CHORD_LIBRARY[chordName],
      stringNames: ["E2", "A2", "D3", "G3", "B3", "E4"],
    };
  }

  return {
    success: true,
    chords: Object.entries(CHORD_LIBRARY).map(([name, data]) => ({
      name,
      ...data,
    })),
  };
}

function buildMetronomePayload(url: URL) {
  const bpm = clampNumber(
    parseInt(url.searchParams.get("bpm") ?? "120", 10),
    30,
    300,
  );
  const timeSignature = url.searchParams.get("timeSignature") ?? "4/4";
  const [beats = 4, beatValue = 4] = timeSignature.split("/").map((value) =>
    parseInt(value, 10)
  );

  return {
    success: true,
    bpm,
    timeSignature,
    beats,
    beatValue,
    intervalMs: Math.round(60000 / bpm),
    accentPattern: Array.from(
      { length: beats },
      (_, index) => index === 0 ? "accent" : "normal",
    ),
  };
}

async function listUserRecordings(auth: AuthContext) {
  const user = requireUser(auth);
  const { data, error } = await auth.adminClient
    .from("guitar_recordings")
    .select("*")
    .eq("user_id", user.id)
    .order("created_at", { ascending: false })
    .limit(100);

  if (error) {
    throw error;
  }

  return ((data ?? []) as GuitarRecordingRow[]).map((row) =>
    mapRecordingRow(row)
  );
}

async function buildPracticeStats(auth: AuthContext) {
  const user = requireUser(auth);
  const { data, error } = await auth.adminClient
    .from("guitar_recordings")
    .select("id, preset, duration_seconds, created_at")
    .eq("user_id", user.id)
    .order("created_at", { ascending: false });

  if (error) {
    throw error;
  }

  const sessions = (data ?? []) as Array<{
    id: string;
    preset: string;
    duration_seconds: number;
    created_at: string;
  }>;

  const totalMinutes = Math.round(
    sessions.reduce((sum, row) => sum + ((row.duration_seconds ?? 0) / 60), 0),
  );
  const averageDurationSeconds = sessions.length > 0
    ? Math.round(
      sessions.reduce((sum, row) => sum + (row.duration_seconds ?? 0), 0) /
        sessions.length,
    )
    : 0;

  return {
    success: true,
    totalSessions: sessions.length,
    totalMinutes,
    averageDurationSeconds,
    streakDays: calculateStreak(sessions.map((row) => row.created_at)),
    weeklyBreakdown: buildWeeklyBreakdown(sessions),
    favoritePreset: findFavoritePreset(sessions.map((row) => row.preset)),
  };
}

async function listPublicRecordings(
  adminClient: SupabaseClient,
  url: URL,
  body: Json = {},
) {
  // Body params (Flutter invoke) take priority over URL query params
  const limitRaw = body.limit ?? url.searchParams.get("limit") ?? "20";
  const offsetRaw = body.offset ?? url.searchParams.get("offset") ?? "0";
  const sortByRaw =
    (body.sortBy ?? url.searchParams.get("sortBy") ?? "created_at") as string;
  const limit = Math.min(parseInt(String(limitRaw), 10), 50);
  const offset = parseInt(String(offsetRaw), 10);
  const sortBy = sortByRaw; // created_at | likes | plays
  const validSorts = ["created_at", "likes", "plays"];
  const orderColumn = validSorts.includes(sortBy) ? sortBy : "created_at";

  const { data, error, count } = await adminClient
    .from("guitar_recordings")
    .select("*", { count: "exact" })
    .eq("is_public", true)
    .order(orderColumn, { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) throw error;

  const recordings = ((data ?? []) as GuitarRecordingRow[]).map((row) =>
    mapRecordingRow(row)
  );

  return {
    success: true,
    recordings,
    total: count ?? 0,
    offset,
    limit,
  };
}

async function getPublicRecording(
  adminClient: SupabaseClient,
  recordingId: string | null,
) {
  if (!recordingId) {
    throw new Error("recordingId is required");
  }

  const { data, error } = await adminClient
    .from("guitar_recordings")
    .select("*")
    .eq("id", recordingId)
    .eq("is_public", true)
    .maybeSingle();

  if (error) {
    throw error;
  }
  if (!data) {
    throw new Error("Public recording not found");
  }

  const row = data as GuitarRecordingRow;
  const playbackUrl = row.file_path
    ? await createSignedUrl(adminClient, row.file_path, 60 * 60)
    : null;

  return {
    success: true,
    recording: mapRecordingRow(row, { playbackUrl }),
  };
}

async function saveRecording(auth: AuthContext, body: Json) {
  const user = requireUser(auth);
  const title = normalizeString(body.title);
  const filePath = normalizeString(body.filePath);
  const fileMimeType = normalizeString(body.fileMimeType);
  const exportFormat = normalizeString(body.exportFormat)?.toLowerCase() ??
    "wav";

  if (!title) {
    throw new Error("title is required");
  }
  if (!filePath) {
    throw new Error("filePath is required");
  }

  const recordingId = crypto.randomUUID();
  const now = new Date().toISOString();

  const row: Partial<GuitarRecordingRow> & {
    id: string;
    user_id: string;
    title: string;
  } = {
    id: recordingId,
    user_id: user.id,
    title,
    duration_seconds: parseInteger(body.durationSeconds, 0),
    preset: normalizeString(body.preset) ?? "acoustic_fingerpicking",
    tuning: normalizeString(body.tuning) ?? "standard",
    bpm: parseInteger(body.bpm, 120),
    track_count: parseInteger(body.tracks ?? body.trackCount, 1),
    tags: toStringArray(body.tags),
    is_public: Boolean(body.isPublic),
    likes: 0,
    plays: 0,
    file_path: filePath,
    file_mime_type: fileMimeType,
    file_size_bytes: parseInteger(body.fileSizeBytes, 0),
    export_format: exportFormat,
    duration_display: formatDuration(parseInteger(body.durationSeconds, 0)),
    ai_feedback: null,
    ai_feedback_source: null,
  };

  const recordingMeta = {
    title,
    duration_seconds: row.duration_seconds ?? 0,
    preset: row.preset ?? "acoustic_fingerpicking",
    tuning: row.tuning ?? "standard",
    bpm: row.bpm ?? 120,
    tags: row.tags ?? [],
    is_public: row.is_public ?? false,
    export_format: row.export_format ?? exportFormat,
  };

  const feedbackResult = GEMINI_API_KEY
    ? await generateRecordingFeedback(
      recordingMeta,
      auth.adminClient,
      filePath,
      fileMimeType,
    ).catch((e) => {
      console.error("[guitar-studio] generateRecordingFeedback failed:", e);
      return {
        text: buildFallbackRecordingFeedback(recordingMeta),
        source: "fallback",
      };
    })
    : {
      text: buildFallbackRecordingFeedback(recordingMeta),
      source: "fallback",
    };

  row.ai_feedback = feedbackResult.text;
  row.ai_feedback_source = feedbackResult.source;

  const { data, error } = await auth.adminClient
    .from("guitar_recordings")
    .insert(row)
    .select("*")
    .single();

  if (error) {
    throw error;
  }

  await auth.adminClient.from("app_analytics").insert({
    user_id: user.id,
    source: "guitar-recording-studio",
    metadata: {
      event_type: "recording_saved",
      recordingId,
      userId: user.id,
      title,
      durationSeconds: row.duration_seconds,
      preset: row.preset,
      tuning: row.tuning,
      bpm: row.bpm,
      trackCount: row.track_count,
      tags: row.tags,
      isPublic: row.is_public,
      likes: 0,
      plays: 0,
      filePath,
      fileMimeType,
      exportFormat,
      durationDisplay: row.duration_display,
      aiFeedback,
      createdAt: now,
    },
  });

  const savedRow = data as GuitarRecordingRow;

  // Auto-post to X when recording is made public
  if (savedRow.is_public) {
    postPublicRecordingToX(savedRow); // fire-and-forget
  }

  return {
    success: true,
    recordingId,
    publicShareUrl: savedRow.is_public ? buildShareUrl(savedRow.id) : null,
    recording: mapRecordingRow(savedRow),
    xPosted: savedRow.is_public,
  };
}

async function deleteRecording(auth: AuthContext, body: Json) {
  const user = requireUser(auth);
  const recordingId = normalizeString(body.recordingId);
  if (!recordingId) {
    throw new Error("recordingId is required");
  }

  const { data: existing, error: existingError } = await auth.adminClient
    .from("guitar_recordings")
    .select("*")
    .eq("id", recordingId)
    .eq("user_id", user.id)
    .maybeSingle();

  if (existingError) {
    throw existingError;
  }
  if (!existing) {
    throw new Error("Recording not found");
  }

  const row = existing as GuitarRecordingRow;
  if (row.file_path) {
    await auth.adminClient.storage.from(RECORDING_BUCKET).remove([
      row.file_path,
    ]);
  }

  const { error } = await auth.adminClient
    .from("guitar_recordings")
    .delete()
    .eq("id", recordingId)
    .eq("user_id", user.id);

  if (error) {
    throw error;
  }

  await auth.adminClient
    .from("app_analytics")
    .delete()
    .eq("source", "guitar-recording-studio")
    .eq("metadata->>event_type", "recording_saved")
    .eq("metadata->>recordingId", recordingId);

  return { success: true };
}

async function likeRecording(auth: AuthContext, body: Json) {
  const user = requireUser(auth);
  const recordingId = normalizeString(body.recordingId);
  if (!recordingId) {
    throw new Error("recordingId is required");
  }

  const { data: existing, error: existingError } = await auth.adminClient
    .from("guitar_recordings")
    .select("id, likes")
    .eq("id", recordingId)
    .maybeSingle();

  if (existingError) {
    throw existingError;
  }
  if (!existing) {
    throw new Error("Recording not found");
  }

  const nextLikes = ((existing as { likes?: number }).likes ?? 0) + 1;
  const { error } = await auth.adminClient
    .from("guitar_recordings")
    .update({ likes: nextLikes })
    .eq("id", recordingId);

  if (error) {
    throw error;
  }

  await auth.adminClient.from("app_analytics").insert({
    user_id: user.id,
    source: "guitar-recording-studio",
    metadata: {
      event_type: "recording_liked",
      recordingId,
      userId: user.id,
      likedAt: new Date().toISOString(),
    },
  });

  return {
    success: true,
    likes: nextLikes,
  };
}

async function incrementPlay(adminClient: SupabaseClient, body: Json) {
  const recordingId = normalizeString(body.recordingId);
  if (!recordingId) {
    throw new Error("recordingId is required");
  }

  const { data: existing, error: existingError } = await adminClient
    .from("guitar_recordings")
    .select("id, plays")
    .eq("id", recordingId)
    .maybeSingle();

  if (existingError) {
    throw existingError;
  }
  if (!existing) {
    throw new Error("Recording not found");
  }

  const nextPlays = ((existing as { plays?: number }).plays ?? 0) + 1;
  const { error } = await adminClient
    .from("guitar_recordings")
    .update({ plays: nextPlays })
    .eq("id", recordingId);

  if (error) {
    throw error;
  }

  return {
    success: true,
    plays: nextPlays,
  };
}

async function logPracticeSession(auth: AuthContext, body: Json) {
  const user = requireUser(auth);
  await auth.adminClient.from("app_analytics").insert({
    user_id: user.id,
    source: "guitar-recording-studio",
    metadata: {
      event_type: "practice_session",
      durationSeconds: parseInteger(body.durationSeconds, 0),
      preset: normalizeString(body.preset),
      exercises: toStringArray(body.exercises),
      notes: normalizeString(body.notes),
      practicedAt: new Date().toISOString(),
    },
  });

  return { success: true };
}

async function shareRecordingToX(auth: AuthContext, body: Json) {
  const user = requireUser(auth);
  const recordingId = normalizeString(body.recordingId);
  if (!recordingId) throw new Error("recordingId is required");

  const { data: row, error } = await auth.adminClient
    .from("guitar_recordings")
    .select("*")
    .eq("id", recordingId)
    .eq("user_id", user.id)
    .single();

  if (error || !row) throw new Error("Recording not found");

  const recording = row as GuitarRecordingRow;
  if (!recording.is_public) {
    throw new Error("Recording must be public to share");
  }

  await postPublicRecordingToX(recording);
  return { success: true, shareUrl: buildShareUrl(recording.id) };
}

async function buildAiAnalysis(auth: AuthContext, body: Json) {
  const user = requireUser(auth);
  const analysisType = normalizeString(body.analysisType) ?? "practice_menu";

  const { data, error } = await auth.adminClient
    .from("guitar_recordings")
    .select("*")
    .eq("user_id", user.id)
    .order("created_at", { ascending: false })
    .limit(50);

  if (error) {
    throw error;
  }

  const recordings = (data ?? []) as GuitarRecordingRow[];
  const metrics = summariseRecordings(recordings);

  if (recordings.length === 0) {
    return {
      success: true,
      analysis: {
        totalRecordings: 0,
        totalMinutes: 0,
        averageDurationSeconds: 0,
        averageBpm: 0,
        streak: 0,
        topPresets: [],
        topTags: [],
        tuningDistribution: {},
      },
      insights: [
        "まだ録音がありません。最初の 1 本を保存すると AI コーチングが有効になります。",
      ],
      recommendations: [
        "30 秒でも良いので 1 本録音して保存する",
        "よく弾くジャンルとテンポをタグで残す",
        "同じフレーズを 2 回録って比較する",
      ],
      practiceMenu: defaultPracticeMenu("acoustic_fingerpicking"),
    };
  }

  const fallback = buildFallbackAiPayload(metrics, analysisType);
  const aiPayload = GEMINI_API_KEY
    ? await generateGeminiCoaching(metrics, analysisType).catch(() => null)
    : null;

  return {
    success: true,
    ...fallback,
    ...(aiPayload ?? {}),
    analysis: {
      ...fallback.analysis,
      ...(aiPayload?.analysis ?? {}),
    },
  };
}

function summariseRecordings(recordings: GuitarRecordingRow[]) {
  const totalMinutes = Math.round(
    recordings.reduce((sum, row) => sum + (row.duration_seconds / 60), 0),
  );
  const averageDurationSeconds = recordings.length > 0
    ? Math.round(
      recordings.reduce((sum, row) => sum + row.duration_seconds, 0) /
        recordings.length,
    )
    : 0;
  const averageBpm = recordings.length > 0
    ? Math.round(
      recordings.reduce((sum, row) => sum + row.bpm, 0) / recordings.length,
    )
    : 0;

  const presetCounts: Record<string, number> = {};
  const tagCounts: Record<string, number> = {};
  const tuningDistribution: Record<string, number> = {};

  for (const row of recordings) {
    presetCounts[row.preset] = (presetCounts[row.preset] ?? 0) + 1;
    tuningDistribution[row.tuning] = (tuningDistribution[row.tuning] ?? 0) + 1;
    for (const tag of row.tags ?? []) {
      tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
    }
  }

  const topPresets = Object.entries(presetCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([preset, count]) => ({ preset, count }));

  const topTags = Object.entries(tagCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([tag, count]) => ({ tag, count }));

  return {
    recordings,
    totalMinutes,
    averageDurationSeconds,
    averageBpm,
    streak: calculateStreak(recordings.map((row) => row.created_at)),
    topPresets,
    topTags,
    tuningDistribution,
  };
}

function buildFallbackAiPayload(
  metrics: ReturnType<typeof summariseRecordings>,
  analysisType: string,
) {
  const insights: string[] = [];
  const recommendations: string[] = [];

  if (metrics.averageDurationSeconds < 45) {
    insights.push(
      `平均録音時間は ${metrics.averageDurationSeconds} 秒で短めです。比較録音向きですが、定着確認は少し不足しています。`,
    );
    recommendations.push(
      "同じフレーズを 60〜90 秒に伸ばして録音し、後半の安定感も確認する",
    );
  } else if (metrics.averageDurationSeconds > 180) {
    insights.push(
      `平均録音時間は ${
        Math.round(metrics.averageDurationSeconds / 60)
      } 分で長めです。集中して弾けています。`,
    );
    recommendations.push(
      "長い録音の中に 30 秒だけの比較テイクも混ぜると改善点が見つけやすくなります。",
    );
  } else {
    insights.push(
      `平均録音時間は ${metrics.averageDurationSeconds} 秒で、改善確認にちょうど良い長さです。`,
    );
  }

  if (metrics.topPresets.length > 0) {
    const mainPreset = metrics.topPresets[0].preset;
    insights.push(`最も使っているジャンルは ${mainPreset} です。`);
    if (metrics.topPresets.length === 1) {
      recommendations.push(
        "別ジャンルのプリセットを 1 本だけ混ぜて、右手とダイナミクスの引き出しを増やす",
      );
    }
  }

  if (metrics.averageBpm > 140) {
    insights.push(
      `平均テンポは ${metrics.averageBpm} BPM と速めです。勢いはありますが走りやすさに注意です。`,
    );
    recommendations.push(
      "1 段階遅いテンポでも同じフレーズを録音して、ピッキングの粒を比較する",
    );
  } else if (metrics.averageBpm > 0 && metrics.averageBpm < 80) {
    insights.push(
      `平均テンポは ${metrics.averageBpm} BPM とゆったりめです。音価のコントロール練習に向いています。`,
    );
    recommendations.push(
      "最後の 1 テイクだけ 10 BPM 上げて、フォームが崩れないか確認する",
    );
  }

  if (metrics.streak >= 7) {
    insights.push(
      `${metrics.streak} 日連続で録音できています。かなり良い習慣化です。`,
    );
  } else if (metrics.streak == 0) {
    recommendations.push("明日も 1 テイクだけ録って、連続日数を作り始める");
  }

  const mainPreset = metrics.topPresets[0]?.preset ?? "acoustic_fingerpicking";

  return {
    analysis: {
      totalRecordings: metrics.recordings.length,
      totalMinutes: metrics.totalMinutes,
      averageDurationSeconds: metrics.averageDurationSeconds,
      averageBpm: metrics.averageBpm,
      streak: metrics.streak,
      topPresets: metrics.topPresets,
      topTags: metrics.topTags,
      tuningDistribution: metrics.tuningDistribution,
    },
    insights,
    recommendations,
    practiceMenu: analysisType == "practice_menu"
      ? defaultPracticeMenu(mainPreset)
      : [],
  };
}

function buildFallbackRecordingFeedback(
  recording: {
    title: string;
    duration_seconds: number;
    preset: string;
    tuning: string;
    bpm: number;
    tags: string[];
    is_public: boolean;
    export_format: string;
  },
) {
  const presetLabel = RECORDING_PRESETS[recording.preset]?.description ??
    recording.preset;
  const durationSeconds = recording.duration_seconds ?? 0;
  const lead = durationSeconds < 45
    ? "フレーズの芯はつかめています。"
    : durationSeconds > 180
    ? "しっかり弾き切れていて、練習の密度も見えます。"
    : "まとまりのある録音になっています。";

  const tempo = recording.bpm >= 140
    ? "テンポが速めなので、ピッキングの粒立ちを少し意識するとさらに安定しそうです。"
    : recording.bpm > 0 && recording.bpm < 80
    ? "ゆっくり目なので、音の伸びとリズムの置き方を丁寧に確認するのに向いています。"
    : `BPM ${recording.bpm} 前後で、フォーム確認とグルーブ作りのバランスが取りやすい設定です。`;

  const tagLine = recording.tags.length > 0
    ? `今回のテーマは ${
      recording.tags.slice(0, 3).map((tag) => `#${tag}`).join(" ")
    } ですね。`
    : `${presetLabel} と ${recording.tuning} チューニングの相性を次回も比較すると改善点が見えやすくなります。`;

  const shareLine = recording.is_public
    ? `公開設定なので、${recording.export_format.toUpperCase()} のまま共有して反応を見てもよさそうです。`
    : "良いテイクが録れたら公開して、反応の良かったパターンを残していきましょう。";

  return [lead, tempo, tagLine, shareLine].join(" ");
}

function mapAudioMime(mimeType: string, exportFormat: string): string {
  const raw = (mimeType || exportFormat).toLowerCase();
  if (raw.includes("m4a") || raw.includes("mp4") || raw.includes("aac")) {
    return "audio/mp4";
  }
  if (raw.includes("mp3") || raw.includes("mpeg")) return "audio/mpeg";
  if (raw.includes("ogg")) return "audio/ogg";
  if (raw.includes("flac")) return "audio/flac";
  return "audio/wav";
}

async function generateRecordingFeedback(
  recording: {
    title: string;
    duration_seconds: number;
    preset: string;
    tuning: string;
    bpm: number;
    tags: string[];
    is_public: boolean;
    export_format: string;
  },
  adminClient: SupabaseClient,
  filePath: string,
  fileMimeType: string,
): Promise<{ text: string; source: string }> {
  const metaPrompt = `録音情報: ${
    JSON.stringify({
      タイトル: recording.title,
      長さ: `${recording.duration_seconds}秒`,
      プリセット: recording.preset,
      チューニング: recording.tuning,
      BPM: recording.bpm,
      タグ: recording.tags,
    })
  }`;

  // Try to download audio for real analysis (Gemini inline_data, max ~15MB)
  const INLINE_SIZE_LIMIT = 15 * 1024 * 1024;
  let audioPart: { inline_data: { mime_type: string; data: string } } | null =
    null;

  try {
    const { data: blob, error: dlErr } = await adminClient.storage
      .from(RECORDING_BUCKET)
      .download(filePath);
    if (!dlErr && blob) {
      const bytes = await blob.arrayBuffer();
      if (bytes.byteLength < INLINE_SIZE_LIMIT) {
        const b64 = btoa(String.fromCharCode(...new Uint8Array(bytes)));
        audioPart = {
          inline_data: {
            mime_type: mapAudioMime(fileMimeType, recording.export_format),
            data: b64,
          },
        };
      }
    }
  } catch (e) {
    console.error("[guitar-studio] audio download failed:", e);
  }

  const textPrompt = audioPart
    ? `あなたはギター練習コーチです。添付の録音音声を聴いて、タイミング・音色・ピッキングノイズ・ピッチ安定性・ダイナミクス・ミストーンの有無を踏まえ、日本語で 2-4 文の短いフィードバックを書いてください。励ましつつ、次に意識するとよい改善ポイントを 1 つ含めてください。Markdown や箇条書きは使わず、プレーンテキストだけを返してください。\n${metaPrompt}`
    : `あなたはギター練習コーチです。以下の録音メタデータをもとに、日本語で 2-4 文の短いフィードバックを書いてください。励ましつつ、次に意識するとよい改善ポイントを 1 つ含めてください。Markdown や箇条書きは使わず、プレーンテキストだけを返してください。\n${metaPrompt}`;

  const parts: unknown[] = [{ text: textPrompt }];
  if (audioPart) parts.push(audioPart);

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts }],
        generationConfig: { temperature: 0.6, maxOutputTokens: 250 },
      }),
    },
  );

  if (!response.ok) {
    throw new Error(
      `Gemini recording feedback request failed: ${response.status}`,
    );
  }

  const payload = await response.json();
  const raw = payload?.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
  if (!raw) {
    throw new Error("Gemini recording feedback was empty");
  }

  return {
    text: raw.replace(/\s+/g, " ").trim(),
    source: audioPart ? "gemini_audio" : "gemini_meta",
  };
}

async function generateGeminiCoaching(
  metrics: ReturnType<typeof summariseRecordings>,
  analysisType: string,
) {
  const prompt = `
あなたはギター練習コーチです。以下の録音メタデータを見て、日本語で短く実用的なコーチングを返してください。
必ず JSON のみで返してください。

{
  "recordingCount": ${metrics.recordings.length},
  "totalMinutes": ${metrics.totalMinutes},
  "averageDurationSeconds": ${metrics.averageDurationSeconds},
  "averageBpm": ${metrics.averageBpm},
  "streak": ${metrics.streak},
  "topPresets": ${JSON.stringify(metrics.topPresets)},
  "topTags": ${JSON.stringify(metrics.topTags)},
  "tuningDistribution": ${JSON.stringify(metrics.tuningDistribution)},
  "analysisType": ${JSON.stringify(analysisType)}
}

返却形式:
{
  "insights": ["3件まで"],
  "recommendations": ["3件まで"],
  "practiceMenu": [
    { "title": "短い項目名", "duration": "5分", "description": "具体的な練習内容" }
  ]
}
`;

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.4,
          maxOutputTokens: 1024,
        },
      }),
    },
  );

  if (!response.ok) {
    throw new Error("Gemini request failed");
  }

  const payload = await response.json();
  const raw = payload?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  const match = raw.match(/\{[\s\S]*\}/);
  if (!match) {
    throw new Error("Gemini response was not JSON");
  }

  return JSON.parse(match[0]);
}

function defaultPracticeMenu(mainPreset: string) {
  const presetLabel = RECORDING_PRESETS[mainPreset]?.description ?? mainPreset;
  return [
    {
      title: "ウォームアップ",
      duration: "5分",
      description: "クロマチックと開放弦で左右のフォームを整える",
    },
    {
      title: "弱点フレーズ反復",
      duration: "10分",
      description:
        `${presetLabel} を意識しつつ、気になる 1 フレーズだけを反復録音する`,
    },
    {
      title: "本番テイク",
      duration: "10分",
      description:
        "メトロノームあり 1 本、なし 1 本の 2 テイクを録って比較する",
    },
    {
      title: "クールダウン",
      duration: "5分",
      description: "ゆっくりのテンポで同じフレーズを弾き、力みを抜いて終える",
    },
  ];
}

function mapRecordingRow(
  row: GuitarRecordingRow,
  overrides: { playbackUrl?: string | null } = {},
) {
  return {
    id: row.id,
    recordingId: row.id,
    title: row.title,
    durationSeconds: row.duration_seconds,
    durationDisplay: row.duration_display ??
      formatDuration(row.duration_seconds),
    preset: row.preset,
    tuning: row.tuning,
    bpm: row.bpm,
    trackCount: row.track_count,
    tags: row.tags ?? [],
    isPublic: row.is_public,
    likes: row.likes,
    plays: row.plays,
    fileUrl: row.file_url,
    filePath: row.file_path,
    fileMimeType: row.file_mime_type,
    fileSizeBytes: row.file_size_bytes,
    exportFormat: row.export_format,
    aiFeedback: row.ai_feedback,
    shareUrl: row.is_public ? buildShareUrl(row.id) : null,
    playbackUrl: overrides.playbackUrl ?? null,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

async function createSignedUrl(
  adminClient: SupabaseClient,
  filePath: string,
  expiresInSeconds: number,
) {
  const { data, error } = await adminClient.storage
    .from(RECORDING_BUCKET)
    .createSignedUrl(filePath, expiresInSeconds);

  if (error) {
    return null;
  }

  return data?.signedUrl ?? null;
}

function calculateStreak(createdAtValues: string[]) {
  if (createdAtValues.length === 0) {
    return 0;
  }

  const uniqueDays = [
    ...new Set(
      createdAtValues.map((value) =>
        new Date(value).toISOString().slice(0, 10)
      ),
    ),
  ].sort().reverse();

  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);

  let streak = 0;
  for (let index = 0; index < uniqueDays.length; index++) {
    const expected = new Date(today);
    expected.setUTCDate(today.getUTCDate() - index);
    const expectedKey = expected.toISOString().slice(0, 10);
    if (uniqueDays[index] === expectedKey) {
      streak += 1;
      continue;
    }
    if (index === 0) {
      const yesterday = new Date(today);
      yesterday.setUTCDate(today.getUTCDate() - 1);
      if (uniqueDays[index] === yesterday.toISOString().slice(0, 10)) {
        streak = 1;
        continue;
      }
    }
    break;
  }

  return streak;
}

function buildWeeklyBreakdown(
  sessions: Array<{ created_at: string; duration_seconds: number }>,
) {
  const now = new Date();
  const weeks: Array<{ week: string; minutes: number; sessions: number }> = [];

  for (let offset = 3; offset >= 0; offset--) {
    const weekStart = new Date(now);
    weekStart.setUTCDate(now.getUTCDate() - ((offset + 1) * 7));
    weekStart.setUTCHours(0, 0, 0, 0);

    const weekEnd = new Date(now);
    weekEnd.setUTCDate(now.getUTCDate() - (offset * 7));
    weekEnd.setUTCHours(0, 0, 0, 0);

    const subset = sessions.filter((session) => {
      const createdAt = new Date(session.created_at).getTime();
      return createdAt >= weekStart.getTime() && createdAt < weekEnd.getTime();
    });

    weeks.push({
      week: weekStart.toISOString().slice(0, 10),
      minutes: Math.round(
        subset.reduce(
          (sum, session) => sum + (session.duration_seconds / 60),
          0,
        ),
      ),
      sessions: subset.length,
    });
  }

  return weeks;
}

function findFavoritePreset(presets: string[]) {
  if (presets.length === 0) {
    return "none";
  }

  const counts: Record<string, number> = {};
  for (const preset of presets) {
    counts[preset] = (counts[preset] ?? 0) + 1;
  }

  return Object.entries(counts).sort((a, b) => b[1] - a[1])[0][0];
}

function formatDuration(totalSeconds: number) {
  const safeSeconds = Math.max(0, totalSeconds);
  const minutes = Math.floor(safeSeconds / 60);
  const seconds = safeSeconds % 60;
  return `${minutes}:${String(seconds).padStart(2, "0")}`;
}

function buildShareUrl(recordingId: string) {
  return `${SHARE_BASE_URL}?share=${recordingId}`;
}

// Fire-and-forget: post a public recording announcement to X (@kanta13jp1).
// Failure is logged but never throws so it never blocks the main flow.
async function postPublicRecordingToX(
  recording: GuitarRecordingRow,
): Promise<void> {
  if (!SERVICE_ROLE_KEY || !SUPABASE_URL) return;

  const durationStr = recording.duration_display ??
    formatDuration(recording.duration_seconds);
  const preset = (recording.preset ?? "").replace(/_/g, " ");
  const shareUrl = buildShareUrl(recording.id);
  const appUrl = APP_URL;

  // Build tweet text ≤280 chars
  const lines = [
    `🎸 新しい録音を公開しました！`,
    `「${recording.title}」`,
    `${durationStr} / ${preset}`.trim(),
    ``,
    shareUrl,
    appUrl,
    `#buildinpublic #FlutterWeb #guitar`,
  ];
  let text = lines.join("\n");
  if (text.length > 280) {
    // Trim title if needed
    const shortTitle = recording.title.length > 20
      ? recording.title.slice(0, 20) + "…"
      : recording.title;
    text = [
      `🎸 「${shortTitle}」を公開しました！`,
      shareUrl,
      `#buildinpublic #guitar`,
    ].join("\n");
  }

  try {
    // 旧 post-x-update EF は削除済み (呼ぶと 404)。schedule-hub の x.post へ。
    // x.post は user レベルだが SERVICE_ROLE_KEY Bearer で service_role 扱いになる。
    const xPostUrl = `${SUPABASE_URL}/functions/v1/schedule-hub`;
    const resp = await fetch(xPostUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
      },
      body: JSON.stringify({
        action: "x.post",
        text,
        source: "guitar-recording-studio",
      }),
    });
    if (!resp.ok) {
      console.warn(`[guitar-recording-studio] X post failed: ${resp.status}`);
    } else {
      // hub は投稿失敗を HTTP 200 + success:false で返すことがある。
      // status だけ見ると失敗を握り潰すのでボディも確認する。
      const result = await resp.json().catch(() => null);
      if (!result || result.success !== true || result.posted !== true) {
        console.warn(
          `[guitar-recording-studio] X post rejected: ${
            result?.error ?? result?.warning ?? "not posted"
          }`,
        );
      }
    }
  } catch (e) {
    console.warn(`[guitar-recording-studio] X post error: ${e}`);
  }
}

function toStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .map((item) => normalizeString(item))
    .filter((item): item is string => Boolean(item));
}

function normalizeString(value: unknown) {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function parseInteger(value: unknown, fallback: number) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.round(value);
  }
  if (typeof value === "string") {
    const parsed = parseInt(value, 10);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return fallback;
}

function clampNumber(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value));
}
