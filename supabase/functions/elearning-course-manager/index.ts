// E-Learning Course Manager Edge Function
// eラーニング・コース管理 (Google Classroom/Udemy競合)
// - コース作成 (セクション/レッスン/クイズ)
// - 学習進捗追跡
// - 修了証発行
// - スキルギャップ分析
//
// GET  → コース一覧 / レッスン / 進捗 / 証明書 / スキル分析
// POST → コース作成 / レッスン追加 / 進捗更新 / クイズ回答

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const SKILL_CATEGORIES = ["programming", "design", "marketing", "management", "finance", "communication", "ai_ml", "data_science"];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: "Authorization required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");
      const courseId = url.searchParams.get("course_id");

      if (view === "skills") {
        return new Response(JSON.stringify({ success: true, skillCategories: SKILL_CATEGORIES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "lessons" && courseId) {
        const { data: lessons } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "course_lesson").eq("metadata->>course_id", courseId)
          .order("created_at", { ascending: true });
        // Get progress
        const { data: progress } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "lesson_progress").eq("metadata->>course_id", courseId);
        const completedLessons = new Set((progress ?? []).filter((p) => (p.metadata as Record<string, unknown>).completed).map((p) => (p.metadata as Record<string, unknown>).lesson_id as string));

        return new Response(JSON.stringify({
          success: true,
          lessons: (lessons ?? []).map((l) => {
            const meta = l.metadata as Record<string, unknown>;
            return { ...meta, completed: completedLessons.has(meta.lesson_id as string), createdAt: l.created_at };
          }),
          progress: { total: (lessons ?? []).length, completed: completedLessons.size, percent: (lessons ?? []).length > 0 ? Math.round(completedLessons.size / (lessons ?? []).length * 100) : 0 },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "certificates") {
        const { data: certs } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "course_certificate")
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          certificates: (certs ?? []).map((c) => ({ ...(c.metadata as Record<string, unknown>), issuedAt: c.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "skill_gap") {
        // Get completed courses and their skills
        const { data: certs } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "course_certificate");
        const acquiredSkills = new Map<string, number>();
        for (const c of certs ?? []) {
          const skills = ((c.metadata as Record<string, unknown>).skills as string[]) ?? [];
          for (const s of skills) {
            acquiredSkills.set(s, (acquiredSkills.get(s) ?? 0) + 1);
          }
        }
        const gaps = SKILL_CATEGORIES.filter((s) => !acquiredSkills.has(s));
        return new Response(JSON.stringify({
          success: true,
          acquiredSkills: Object.fromEntries(acquiredSkills),
          skillGaps: gaps,
          recommendation: gaps.length > 0 ? `次のスキルを強化しましょう: ${gaps.slice(0, 3).join(", ")}` : "全カテゴリのスキルを習得済みです！",
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: course list
      const { data: courses } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "course")
        .order("created_at", { ascending: false });
      return new Response(JSON.stringify({
        success: true,
        courses: (courses ?? []).map((c) => ({ ...(c.metadata as Record<string, unknown>), createdAt: c.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create_course") {
        const { title, description, skills, difficulty, estimated_hours } = body;
        if (!title) {
          return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const courseId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "course",
          metadata: { course_id: courseId, title, description: description ?? null, skills: skills ?? [], difficulty: difficulty ?? "beginner", estimated_hours: estimated_hours ?? 1, status: "draft" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, courseId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_lesson") {
        const { course_id, title, content, type, quiz_questions, order } = body;
        if (!course_id || !title) {
          return new Response(JSON.stringify({ success: false, error: "course_id and title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const lessonId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "course_lesson",
          metadata: { lesson_id: lessonId, course_id, title, content: content ?? null, type: type ?? "text", quiz_questions: quiz_questions ?? null, order: order ?? 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, lessonId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "complete_lesson") {
        const { course_id, lesson_id, quiz_score } = body;
        if (!course_id || !lesson_id) {
          return new Response(JSON.stringify({ success: false, error: "course_id and lesson_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "lesson_progress",
          metadata: { course_id, lesson_id, completed: true, quiz_score: quiz_score ?? null, completed_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });

        // Check if all lessons completed → issue certificate
        const { data: allLessons } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "course_lesson").eq("metadata->>course_id", course_id);
        const { data: allProgress } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "lesson_progress").eq("metadata->>course_id", course_id);
        const completedIds = new Set((allProgress ?? []).filter((p) => (p.metadata as Record<string, unknown>).completed).map((p) => (p.metadata as Record<string, unknown>).lesson_id as string));
        const allDone = (allLessons ?? []).every((l) => completedIds.has((l.metadata as Record<string, unknown>).lesson_id as string));

        let certificateId = null;
        if (allDone && (allLessons ?? []).length > 0) {
          // Get course info
          const { data: course } = await adminClient.from("app_analytics").select("metadata")
            .eq("user_id", user.id).eq("source", "course").eq("metadata->>course_id", course_id).maybeSingle();
          const courseMeta = course?.metadata as Record<string, unknown> ?? {};
          certificateId = crypto.randomUUID();
          await adminClient.from("app_analytics").insert({
            user_id: user.id, source: "course_certificate",
            metadata: { certificate_id: certificateId, course_id, course_title: courseMeta.title, skills: courseMeta.skills ?? [], issued_at: new Date().toISOString() },
            created_at: new Date().toISOString(),
          });
        }

        return new Response(JSON.stringify({ success: true, completed: true, courseCompleted: allDone, certificateId }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
