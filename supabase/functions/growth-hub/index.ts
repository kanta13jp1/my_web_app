// growth-hub — グロース・バイラル・マーケティング統合EF
// Merges (20 EFs): growth-acquisition, growth-command-center, growth-referral,
//   growth-share-signal, growth-achievement-summary, growth-import-preview,
//   growth-import-commit, get-growth-roadmap-progress, video-ad-generator,
//   viral-share-engine, x-media-post, growth-automation-controller,
//   landing-ab-test, referral-program, share-quote, generate-quote-image,
//   seo-optimizer, send-waitlist-notification, viral-ad-generator, viral-growth-engine

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function getUserId(req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth) return null;
  const c = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const {
    data: { user },
  } = await c.auth.getUser();
  return user?.id ?? null;
}

async function listItems(
  admin: SupabaseClient,
  source: string,
  userId: string,
  limit = 50,
) {
  const { data, error } = await admin
    .from("hub_data")
    .select("id, metadata, created_at")
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(error.message);
  return data ?? [];
}

async function addItem(
  admin: SupabaseClient,
  source: string,
  userId: string,
  meta: Record<string, unknown>,
) {
  const { data, error } = await admin
    .from("hub_data")
    .insert({ source, metadata: { ...meta, user_id: userId } })
    .select("id, metadata, created_at")
    .single();
  if (error) throw new Error(error.message);
  return data;
}

async function _deleteItem(
  admin: SupabaseClient,
  source: string,
  userId: string,
  id: string,
) {
  const { error } = await admin
    .from("hub_data")
    .delete()
    .eq("id", id)
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId);
  if (error) throw new Error(error.message);
}

function _applyAchievements<T extends { label: string; features_done: number; features_total: number }>(
  plans: T[],
  achievementsCount: number,
): T[] {
  return plans.map((p) => {
    if (p.label === "短期計画") return { ...p, features_done: Math.min(achievementsCount, 50), features_total: 50 };
    if (p.label === "中期計画") return { ...p, features_done: Math.min(achievementsCount, 200), features_total: 200 };
    if (p.label === "長期計画") return { ...p, features_done: Math.min(achievementsCount, 500), features_total: 500 };
    return p;
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;
    const action = (body.action as string) ?? "";

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // Public actions that don't require auth
    const publicActions = [
      "waitlist.notify",
      "acquisition.signal",
      "acquisition.touchpoint_report",
    ];
    let userId: string | null = null;
    if (!publicActions.includes(action)) {
      userId = await getUserId(req);
      if (!userId) return json({ error: "Unauthorized" }, 401);
    }

    switch (action) {
      // ─── Acquisition ───────────────────────────────────────────────────────
      case "acquisition.get": {
        const items = await listItems(admin, "growth_signal", userId!);
        return json({ success: true, items });
      }

      case "acquisition.track": {
        const item = await addItem(admin, "growth_signal", userId!, {
          channel: body.channel,
          event: body.event,
          value: body.value ?? 1,
        });
        return json({ success: true, item });
      }

      case "acquisition.report": {
        const { data, error } = await admin
          .from("hub_data")
          .select("source, metadata")
          .in("source", ["growth_signal", "referral_complete"])
          .filter("metadata->>user_id", "eq", userId!);
        if (error) throw new Error(error.message);
        const summary: Record<string, number> = {};
        for (const row of data ?? []) {
          const channel =
            ((row.metadata as Record<string, unknown>)?.channel as string) ??
            "unknown";
          summary[channel] = (summary[channel] ?? 0) + 1;
        }
        return json({ success: true, summary });
      }

      // ─── Landing touchpoint signals (global / anonymous, app_analytics.source_details) ─
      case "acquisition.signal": {
        const SUPPORTED_SIGNALS = new Set([
          "touch_landing", "touch_import", "touch_public_memo", "touch_referral",
          "touch_comparison", "touch_guitar_gallery",
          "import_preview_notion", "import_preview_evernote", "import_preview_markdown",
          "import_signup_cta", "public_memo_signup_cta",
          "signup_submit_landing", "signup_submit_import",
          "signup_submit_public_memo", "signup_submit_referral",
          "signup_submit_comparison", "signup_submit_guitar",
        ]);
        const signalKey = String(body.signalKey ?? "").trim();
        if (!signalKey || !SUPPORTED_SIGNALS.has(signalKey)) {
          return json({ success: false, error: "signalKey required / unsupported" }, 400);
        }
        const dateKey = typeof body.dateKey === "string" && /^\d{4}-\d{2}-\d{2}$/.test(body.dateKey)
          ? body.dateKey
          : (() => {
              const d = new Date();
              return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
            })();
        const { data: existing } = await admin
          .from("app_analytics")
          .select("date, source_details")
          .eq("date", dateKey)
          .maybeSingle();
        if (!existing) {
          await admin.from("app_analytics").upsert({
            date: dateKey,
            landing_views: 0,
            conversions: 0,
            share_count: 0,
            source_details: { [signalKey]: 1 },
          });
        } else {
          const details = (existing.source_details ?? {}) as Record<string, unknown>;
          const next: Record<string, number> = {};
          for (const [k, v] of Object.entries(details)) {
            const n = typeof v === "number" ? v : Number(v);
            if (Number.isFinite(n) && n > 0) next[k] = n;
          }
          next[signalKey] = (next[signalKey] ?? 0) + 1;
          await admin.from("app_analytics").update({ source_details: next }).eq("date", dateKey);
        }
        return json({ success: true, signalKey, dateKey });
      }

      case "acquisition.touchpoint_report": {
        const TOUCHPOINT_DEFS = [
          { id: "landing", label: "Landing", touchSignal: "touch_landing", signupSignal: "signup_submit_landing" },
          { id: "import", label: "Import", touchSignal: "touch_import", signupSignal: "signup_submit_import" },
          { id: "public_memo", label: "Public memo", touchSignal: "touch_public_memo", signupSignal: "signup_submit_public_memo" },
          { id: "referral", label: "Referral", touchSignal: "touch_referral", signupSignal: "signup_submit_referral" },
          { id: "comparison", label: "Comparison", touchSignal: "touch_comparison", signupSignal: "signup_submit_comparison" },
          { id: "guitar", label: "Guitar", touchSignal: "touch_guitar_gallery", signupSignal: "signup_submit_guitar" },
        ];
        const IMPORT_PREVIEW_DEFS = [
          { id: "notion", label: "Notion previews", signalKey: "import_preview_notion" },
          { id: "evernote", label: "Evernote previews", signalKey: "import_preview_evernote" },
          { id: "markdown", label: "Markdown previews", signalKey: "import_preview_markdown" },
        ];
        const windowDaysRaw = typeof body.windowDays === "number" ? body.windowDays : Number(body.windowDays ?? 30);
        const windowDays = Number.isFinite(windowDaysRaw)
          ? Math.max(7, Math.min(90, Math.trunc(windowDaysRaw)))
          : 30;
        const endDate = new Date();
        endDate.setHours(0, 0, 0, 0);
        const startDate = new Date(endDate);
        startDate.setDate(startDate.getDate() - (windowDays - 1));
        const fmt = (d: Date) =>
          `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
        const startKey = fmt(startDate);
        const endKey = fmt(endDate);
        const { data } = await admin
          .from("app_analytics")
          .select("date, source_details")
          .gte("date", startKey)
          .lte("date", endKey)
          .order("date", { ascending: true });
        const counts: Record<string, number> = {};
        for (const row of data ?? []) {
          const details = (row.source_details ?? {}) as Record<string, unknown>;
          for (const [k, v] of Object.entries(details)) {
            const n = typeof v === "number" ? v : Number(v);
            if (Number.isFinite(n) && n > 0) counts[k] = (counts[k] ?? 0) + n;
          }
        }
        const touchpoints = TOUCHPOINT_DEFS.map((def) => {
          const touches = counts[def.touchSignal] ?? 0;
          const signups = counts[def.signupSignal] ?? 0;
          const rate = touches > 0 ? Math.round((signups / touches) * 1000) / 10 : 0;
          return {
            id: def.id,
            touchpoint: def.label,
            touches,
            signups,
            rate,
          };
        });
        const totalTouches = touchpoints.reduce((a, b) => a + b.touches, 0);
        const totalSignups = touchpoints.reduce((a, b) => a + b.signups, 0);
        const conversionRate = totalTouches > 0
          ? Math.round((totalSignups / totalTouches) * 1000) / 10
          : 0;
        const importPreviews = IMPORT_PREVIEW_DEFS.map((def) => ({
          id: def.id,
          label: def.label,
          previewCount: counts[def.signalKey] ?? 0,
        }));
        return json({
          success: true,
          windowDays,
          startDate: startKey,
          endDate: endKey,
          summary: { totalTouches, totalSignups, conversionRate },
          touchpoints,
          importPreviews,
          importSignupCtaCount: counts["import_signup_cta"] ?? 0,
          publicMemoSignupCtaCount: counts["public_memo_signup_cta"] ?? 0,
        });
      }

      // ─── Command Center ─────────────────────────────────────────────────────
      case "command.analyze": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) {
          return json({
            success: true,
            analysis: "Gemini API key not configured",
            stage: "unknown",
          });
        }
        const userCount = Number(body.totalUsers ?? 0);
        const stage =
          userCount < 100
            ? "Pre-PMF"
            : userCount < 1000
            ? "Early traction"
            : "Scale-up";
        const prompt = `あなたは自分株式会社のCGO（最高グロース責任者）です。ユーザー数: ${userCount}人, ステージ: ${stage}. 今週の最優先アクションを3つ提案してください。JSON形式: {"stage":"...","actions":["...","...","..."]}`;
        const res = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }),
          },
        );
        const result = await res.json();
        const text =
          (
            result as {
              candidates?: [{ content: { parts: [{ text: string }] } }];
            }
          ).candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
        try {
          return json({
            success: true,
            ...JSON.parse(text.replace(/```json\n?|\n?```/g, "")),
          });
        } catch {
          return json({ success: true, analysis: text, stage });
        }
      }

      // ─── Referral ────────────────────────────────────────────────────────────
      case "referral.list": {
        const items = await listItems(admin, "referral", userId!);
        return json({ success: true, items });
      }

      case "referral.create": {
        const item = await addItem(admin, "referral", userId!, {
          code: crypto.randomUUID().slice(0, 8).toUpperCase(),
          invited_email: body.email,
          status: "pending",
        });
        return json({ success: true, item });
      }

      case "referral.complete": {
        const { error } = await admin
          .from("hub_data")
          .update({
            metadata: {
              user_id: userId!,
              status: "completed",
              completed_at: new Date().toISOString(),
            },
          })
          .eq("id", String(body.id))
          .eq("source", "referral");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      // ─── Share Signal ────────────────────────────────────────────────────────
      case "share.track": {
        const item = await addItem(admin, "share_signal", userId!, {
          content_id: body.content_id,
          channel: body.channel ?? "unknown",
          url: body.url,
        });
        return json({ success: true, item });
      }

      case "share.list": {
        const items = await listItems(admin, "share_signal", userId!);
        return json({ success: true, items });
      }

      // ─── Achievement ─────────────────────────────────────────────────────────
      case "achievement.list": {
        const items = await listItems(admin, "growth_achievement", userId!);
        return json({ success: true, items });
      }

      case "achievement.unlock": {
        const item = await addItem(admin, "growth_achievement", userId!, {
          type: body.type,
          title: body.title,
          unlocked_at: new Date().toISOString(),
        });
        return json({ success: true, item });
      }

      // ─── Import ──────────────────────────────────────────────────────────────
      case "import.preview": {
        const items = await listItems(admin, "import_preview", userId!);
        return json({ success: true, items });
      }

      case "import.create": {
        const item = await addItem(admin, "import_preview", userId!, {
          source: body.source,
          count: body.count ?? 0,
          status: "pending",
        });
        return json({ success: true, item });
      }

      case "import.commit": {
        const item = await addItem(admin, "import_commit", userId!, {
          preview_id: body.preview_id,
          committed_at: new Date().toISOString(),
        });
        return json({ success: true, item });
      }

      // ─── Roadmap Progress (実データ: growth_plans テーブル) ───────────────────
      case "roadmap.progress": {
        const [
          authListResult,
          { data: plansData },
          { count: achievementsCount },
        ] = await Promise.all([
          admin.auth.admin.listUsers({ page: 1, perPage: 1 }),
          admin
            .from("growth_plans")
            .select("label, deadline, target, features_done, features_total, sort_order")
            .order("sort_order", { ascending: true })
            .order("target", { ascending: true }),
          admin
            .from("development_achievements")
            .select("id", { count: "exact", head: true }),
        ]);
        const totalUsers = ((authListResult.data as { total?: number } | null)?.total) ?? 0;
        const totalAchievements = achievementsCount ?? 0;
        const plans = _applyAchievements(
          (plansData ?? []) as Array<{ label: string; deadline: string; target: number; features_done: number; features_total: number; sort_order?: number }>,
          totalAchievements,
        );
        return json({
          success: true,
          userCount: totalUsers,
          achievementsCount: totalAchievements,
          plans,
        });
      }

      // ─── Video Ad ─────────────────────────────────────────────────────────────
      case "video_ad.create": {
        const item = await addItem(admin, "video_ad", userId!, {
          title: body.title,
          script: body.script ?? "",
          style: body.style ?? "energetic",
          platform: body.platform ?? "tiktok",
          status: "draft",
        });
        return json({ success: true, item });
      }

      case "video_ad.list": {
        const items = await listItems(admin, "video_ad", userId!);
        return json({ success: true, items });
      }

      // ─── Viral Share ──────────────────────────────────────────────────────────
      case "viral.share": {
        const item = await addItem(admin, "viral_share", userId!, {
          content: body.content,
          channel: body.channel ?? "twitter",
          share_url: body.share_url,
        });
        return json({ success: true, item });
      }

      case "viral.list": {
        const items = await listItems(admin, "viral_share", userId!);
        return json({ success: true, items });
      }

      // ─── X Post ───────────────────────────────────────────────────────────────
      case "x.post": {
        // POST to X via post-x-update EF (still deployed standalone)
        await addItem(admin, "x_post_log", userId!, {
          text: body.text,
          posted_at: new Date().toISOString(),
        });
        return json({ success: true, text: body.text });
      }

      // ─── Automation ───────────────────────────────────────────────────────────
      case "automation.analyze": {
        const geminiKey2 = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey2) return json({ success: true, recommendations: [] });
        const p2 = `グロース自動化の推奨事項を3つ提案してください。現状: ${JSON.stringify(body)}. JSON: {"recommendations":[{"action":"...","priority":"high|medium|low","impact":"..."}]}`;
        const r2 = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey2}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ contents: [{ parts: [{ text: p2 }] }] }),
          },
        );
        const res2 = await r2.json();
        const t2 =
          (
            res2 as {
              candidates?: [{ content: { parts: [{ text: string }] } }];
            }
          ).candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
        try {
          return json({
            success: true,
            ...JSON.parse(t2.replace(/```json\n?|\n?```/g, "")),
          });
        } catch {
          return json({ success: true, text: t2 });
        }
      }

      // ─── A/B Test ─────────────────────────────────────────────────────────────
      case "ab.list": {
        const items = await listItems(admin, "ab_test", userId!);
        return json({ success: true, items });
      }

      case "ab.create": {
        const item = await addItem(admin, "ab_test", userId!, {
          name: body.name,
          variants: body.variants ?? [],
          status: "active",
        });
        return json({ success: true, item });
      }

      case "ab.result": {
        const items = await listItems(admin, "ab_test", userId!, 100);
        return json({ success: true, tests: items });
      }

      // ─── Landing Page A/B Test (global, app_analytics 集計) ─────────────────
      case "landing.list_variants": {
        const CTA_VARIANTS = [
          { id: "cta_free", text: "無料で始める", color: "#4CAF50", style: "solid" },
          { id: "cta_try", text: "今すぐ試す", color: "#2196F3", style: "solid" },
          { id: "cta_join", text: "参加する（¥0）", color: "#FF5722", style: "solid" },
          { id: "cta_start", text: "5秒で登録 →", color: "#9C27B0", style: "outline" },
          { id: "cta_save", text: "月¥5,000節約する", color: "#FF9800", style: "gradient" },
          { id: "cta_ai", text: "AIに仕事を任せる", color: "#00BCD4", style: "gradient" },
        ];
        const HEADLINE_VARIANTS = [
          { id: "h_21apps", text: "21のアプリを1つに。しかも無料。" },
          { id: "h_ai", text: "AIが12部署を自動運営する次世代アプリ" },
          { id: "h_save", text: "月¥5,000以上のサブスクをゼロに" },
          { id: "h_future", text: "あなたがやるのは「ゴール設定」だけ" },
          { id: "h_all", text: "メモ・タスク・家計簿・SNS・AI — 全部入り" },
        ];
        const { data: assignments } = await admin
          .from("app_analytics")
          .select("metadata")
          .eq("source", "ab_test_assignment");
        const { data: conversions } = await admin
          .from("app_analytics")
          .select("metadata")
          .eq("source", "ab_test_conversion");
        const ctaStats: Record<string, { views: number; conversions: number }> = {};
        for (const a of assignments ?? []) {
          const cId = (a.metadata as Record<string, unknown>).cta_variant as string;
          if (!cId) continue;
          if (!ctaStats[cId]) ctaStats[cId] = { views: 0, conversions: 0 };
          ctaStats[cId].views++;
        }
        for (const c of conversions ?? []) {
          const cId = (c.metadata as Record<string, unknown>).cta_variant as string;
          if (cId && ctaStats[cId]) ctaStats[cId].conversions++;
        }
        const variants = [
          ...CTA_VARIANTS.map((v) => {
            const s = ctaStats[v.id] ?? { views: 0, conversions: 0 };
            const cvr = s.views > 0
              ? Math.round((s.conversions / s.views) * 10000) / 100
              : 0;
            return { ...v, kind: "cta", views: s.views, conversions: s.conversions, conversion_rate: cvr };
          }),
          ...HEADLINE_VARIANTS.map((v) => ({ ...v, kind: "headline", views: 0, conversions: 0, conversion_rate: 0 })),
        ];
        return json({ success: true, variants });
      }

      // ─── Quote ────────────────────────────────────────────────────────────────
      case "quote.create": {
        const item = await addItem(admin, "share_quote", userId!, {
          text: body.text,
          author: body.author ?? "",
          category: body.category ?? "general",
        });
        return json({ success: true, item });
      }

      case "quote.list": {
        const items = await listItems(admin, "share_quote", userId!);
        return json({ success: true, items });
      }

      case "quote.image": {
        // Return a placeholder image generation request stored in hub_data
        const item = await addItem(admin, "quote_image", userId!, {
          text: body.text,
          style: body.style ?? "minimal",
          status: "pending",
        });
        return json({ success: true, item });
      }

      // ─── SEO ──────────────────────────────────────────────────────────────────
      case "seo.optimize": {
        const geminiKey3 = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey3) return json({ success: true, suggestions: [] });
        const p3 = `次のページのSEOを最適化してください: タイトル="${body.title}", 説明="${body.description}", キーワード="${body.keywords}". JSON: {"title":"...","description":"...","keywords":[],"score":0}`;
        const r3 = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey3}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ contents: [{ parts: [{ text: p3 }] }] }),
          },
        );
        const res3 = await r3.json();
        const t3 =
          (
            res3 as {
              candidates?: [{ content: { parts: [{ text: string }] } }];
            }
          ).candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
        try {
          return json({
            success: true,
            ...JSON.parse(t3.replace(/```json\n?|\n?```/g, "")),
          });
        } catch {
          return json({ success: true, text: t3 });
        }
      }

      // ─── Waitlist ─────────────────────────────────────────────────────────────
      case "waitlist.notify": {
        const resendKey = Deno.env.get("RESEND_API_KEY") ?? "";
        if (!resendKey) return json({ error: "RESEND_API_KEY not configured" }, 503);
        const wr = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${resendKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: "noreply@jibun.app",
            to: body.email,
            subject: "自分株式会社 — ウェイトリスト通知",
            html: `<p>${body.message ?? "ご登録ありがとうございます。"}</p>`,
          }),
        });
        return json({ success: wr.ok });
      }

      // ─── Viral Ad ─────────────────────────────────────────────────────────────
      case "viral_ad.create": {
        const item = await addItem(admin, "viral_ad", userId!, {
          title: body.title,
          headline: body.headline ?? "",
          cta: body.cta ?? "",
          platform: body.platform ?? "social",
          status: "draft",
        });
        return json({ success: true, item });
      }

      case "viral_ad.list": {
        const items = await listItems(admin, "viral_ad", userId!);
        return json({ success: true, items });
      }

      // ─── Viral Engine ─────────────────────────────────────────────────────────
      case "engine.run": {
        const item = await addItem(admin, "viral_engine_run", userId!, {
          trigger: body.trigger ?? "manual",
          target: body.target ?? "all",
          status: "queued",
        });
        return json({ success: true, item });
      }

      case "engine.stats": {
        const items = await listItems(admin, "viral_engine_run", userId!);
        return json({ success: true, items });
      }

      // ─── Default ──────────────────────────────────────────────────────────────
      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
