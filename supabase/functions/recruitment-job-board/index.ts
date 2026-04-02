// Recruitment Job Board Edge Function
// 採用・求人管理 (ジョブカン競合)
// - 求人掲載 CRUD
// - 応募管理 (ATS)
// - 選考ステータス管理
// - 面接スケジュール
// - オファー管理
//
// GET  → 求人一覧 / 応募者一覧 / 選考状況 / 統計
// POST → 求人作成 / 応募 / ステータス更新 / 面接設定

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const APPLICATION_STATUSES = ["applied", "screening", "interview_1", "interview_2", "final_interview", "offer", "accepted", "rejected", "withdrawn"];
const JOB_TYPES = ["full_time", "part_time", "contract", "intern", "freelance"];

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

      if (view === "options") {
        return new Response(JSON.stringify({ success: true, statuses: APPLICATION_STATUSES, jobTypes: JOB_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "applicants") {
        const jobId = url.searchParams.get("job_id");
        let query = adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "job_application")
          .order("created_at", { ascending: false });
        if (jobId) query = query.eq("metadata->>job_id", jobId);
        const { data: apps } = await query.limit(100);
        return new Response(JSON.stringify({
          success: true,
          applicants: (apps ?? []).map((a) => ({ ...(a.metadata as Record<string, unknown>), appliedAt: a.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "pipeline") {
        const jobId = url.searchParams.get("job_id");
        if (!jobId) {
          return new Response(JSON.stringify({ success: false, error: "job_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: apps } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "job_application").eq("metadata->>job_id", jobId);
        const pipeline: Record<string, number> = {};
        for (const s of APPLICATION_STATUSES) pipeline[s] = 0;
        for (const a of apps ?? []) {
          const status = ((a.metadata as Record<string, unknown>).status as string) ?? "applied";
          pipeline[status] = (pipeline[status] ?? 0) + 1;
        }
        return new Response(JSON.stringify({ success: true, jobId, pipeline, totalApplicants: (apps ?? []).length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: jobs } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "job_posting");
        const { data: apps } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "job_application");
        const activeJobs = (jobs ?? []).filter((j) => (j.metadata as Record<string, unknown>).status === "active").length;
        const hires = (apps ?? []).filter((a) => (a.metadata as Record<string, unknown>).status === "accepted").length;
        return new Response(JSON.stringify({
          success: true,
          stats: { totalJobs: (jobs ?? []).length, activeJobs, totalApplications: (apps ?? []).length, hires, conversionRate: (apps ?? []).length > 0 ? Math.round(hires / (apps ?? []).length * 100) : 0 },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: job list
      const { data: jobs } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "job_posting")
        .order("created_at", { ascending: false }).limit(50);
      return new Response(JSON.stringify({
        success: true,
        jobs: (jobs ?? []).map((j) => ({ ...(j.metadata as Record<string, unknown>), createdAt: j.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create_job") {
        const { title, department, job_type, description, requirements, salary_range, location } = body;
        if (!title) {
          return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const jobId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "job_posting",
          metadata: {
            job_id: jobId, title, department: department ?? null,
            job_type: job_type ?? "full_time", description: description ?? null,
            requirements: requirements ?? [], salary_range: salary_range ?? null,
            location: location ?? "リモート", status: "active",
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, jobId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "apply") {
        const { job_id, name, email, resume_url, cover_letter } = body;
        if (!job_id || !name || !email) {
          return new Response(JSON.stringify({ success: false, error: "job_id, name, email required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const appId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "job_application",
          metadata: {
            application_id: appId, job_id, name, email,
            resume_url: resume_url ?? null, cover_letter: cover_letter ?? null,
            status: "applied", notes: [],
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, applicationId: appId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "update_status") {
        const { application_id, status, note } = body;
        if (!application_id || !status) {
          return new Response(JSON.stringify({ success: false, error: "application_id and status required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        if (!APPLICATION_STATUSES.includes(status)) {
          return new Response(JSON.stringify({ success: false, error: "Invalid status" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "job_application").eq("metadata->>application_id", application_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Application not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meta = existing.metadata as Record<string, unknown>;
        const notes = (meta.notes as Array<Record<string, unknown>>) ?? [];
        if (note) notes.push({ text: note, status, at: new Date().toISOString() });
        await adminClient.from("app_analytics").update({
          metadata: { ...meta, status, notes },
        }).eq("user_id", user.id).eq("source", "job_application").eq("metadata->>application_id", application_id);
        return new Response(JSON.stringify({ success: true, updated: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "schedule_interview") {
        const { application_id, interview_date, interviewers, location, type } = body;
        if (!application_id || !interview_date) {
          return new Response(JSON.stringify({ success: false, error: "application_id and interview_date required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const interviewId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "job_interview",
          metadata: { interview_id: interviewId, application_id, interview_date, interviewers: interviewers ?? [], location: location ?? "オンライン", type: type ?? "online", feedback: null },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, interviewId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
