// enterprise-hub — 業務・エンタープライズ機能統合EF
// Merges (42 EFs): leave-management, performance-review, compensation-manager,
//   recruitment-job-board, compliance-checker, legal-compliance-manager, audit-trail,
//   ci-cd-pipeline, code-playground, api-docs-generator, api-key-manager,
//   dns-domain-manager, code-review-issues, ab-testing-manager, feature-flags,
//   custom-dashboard-builder, data-pipeline, data-visualization, analytics-export,
//   search-analytics, cohort-analysis, revenue-forecaster, sitemap-analytics,
//   user-onboarding, crm-sales-pipeline, github-pr-manager, user-growth-analytics,
//   gantt-timeline-manager, task-dependency, workflow-templates, spreadsheet-database,
//   wiki-database, knowledge-base, integration-connector, email-template-builder,
//   edge-function-test-runner, edge-function-ui-checker, ai-writing-assistant,
//   ai-workflow-automation, gemini-election-analysis, competitor-feature-sync
//
// GET/POST ?action=<action> or body { action: "..." }

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  createSupabaseIntegrationRegistryStore,
  handleIntegrationRegistryAction,
} from "./integration_registry.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Max-Age": "86400",
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
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return null;
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  return user?.id ?? null;
}

async function listItems(
  admin: SupabaseClient,
  source: string,
  userId: string,
  limit = 50,
) {
  const { data, error } = await admin.from("hub_data")
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
  const { data, error } = await admin.from("hub_data")
    .insert({ source, metadata: { ...meta, user_id: userId } })
    .select("id, metadata, created_at").single();
  if (error) throw new Error(error.message);
  return data;
}

function monitoringMetricsFor(
  platform: string,
): Array<Record<string, unknown>> {
  const normalized = platform.toLowerCase();
  const metrics: Array<Record<string, unknown>> = [
    {
      key: "availability",
      label: "Availability",
      unit: "%",
      warning_threshold: 99,
      critical_threshold: 95,
      sample_value: 99.9,
    },
    {
      key: "error_rate",
      label: "Error rate",
      unit: "%",
      warning_threshold: 1,
      critical_threshold: 5,
      sample_value: 0.2,
    },
    {
      key: "p95_latency",
      label: "p95 latency",
      unit: "ms",
      warning_threshold: 800,
      critical_threshold: 1500,
      sample_value: 240,
    },
    {
      key: "cpu_or_invocations",
      label: "CPU / invocations",
      unit: "score",
      warning_threshold: 75,
      critical_threshold: 90,
      sample_value: 38,
    },
  ];
  if (normalized.includes("edge") || normalized.includes("lambda")) {
    metrics.push({
      key: "cold_start",
      label: "Cold start",
      unit: "ms",
      warning_threshold: 1200,
      critical_threshold: 2500,
      sample_value: 410,
    });
  }
  if (normalized.includes("ecs") || normalized.includes("generic")) {
    metrics.push({
      key: "memory_pressure",
      label: "Memory pressure",
      unit: "%",
      warning_threshold: 80,
      critical_threshold: 92,
      sample_value: 47,
    });
  }
  return metrics;
}

function buildDeploymentMonitoringRecord(
  body: Record<string, unknown>,
): Record<string, unknown> {
  const serviceName = textValue(body.service_name, "new-service");
  const platform = textValue(body.platform, "Generic API Service");
  const provider = textValue(body.provider, "Built-in dashboard");
  const environment = textValue(body.environment, "production");
  const autoMonitoringEnabled = body.auto_monitoring_enabled !== false;
  const metrics = autoMonitoringEnabled
    ? (Array.isArray(body.metrics) && body.metrics.length > 0
      ? body.metrics
      : monitoringMetricsFor(platform))
    : [];
  const dashboardWidgets = Array.isArray(body.dashboard_widgets)
    ? body.dashboard_widgets
    : autoMonitoringEnabled
    ? [
      "Health summary",
      "Latency and error trend",
      "Recent incidents",
      "Alert threshold table",
    ]
    : ["Opt-out audit trail", "Manual monitoring reminder"];
  const setupSteps = Array.isArray(body.setup_steps)
    ? body.setup_steps
    : autoMonitoringEnabled
    ? [
      "Create default health check target",
      "Attach metric thresholds to the service record",
      "Show metrics on the deployment monitoring dashboard",
    ]
    : [
      "Record opt-out reason before production release",
      "Create a WBS follow-up if the service becomes customer-facing",
    ];

  return {
    service_name: serviceName,
    platform,
    provider,
    environment,
    auto_monitoring_enabled: autoMonitoringEnabled,
    metrics,
    dashboard_widgets: dashboardWidgets,
    setup_steps: setupSteps,
    status_label: autoMonitoringEnabled
      ? "Monitoring auto-enabled"
      : "Monitoring opt-out",
    created_at: textValue(body.created_at, new Date().toISOString()),
  };
}

type TomeCompetitorRow = {
  Product: string;
  Feature: string;
  Price: string;
  Risk: string;
  Countermove: string;
  Source: string;
};

function textValue(value: unknown, fallback = ""): string {
  if (value === null || value === undefined) return fallback;
  if (Array.isArray(value)) {
    return value.map((item) => textValue(item)).filter(Boolean).join(" / ");
  }
  return String(value).trim() || fallback;
}

function pickField(
  fields: Record<string, unknown>,
  keys: string[],
  fallback = "",
): string {
  for (const key of keys) {
    const value = fields[key] ?? fields[key.toLowerCase()] ??
      fields[key.toUpperCase()];
    const text = textValue(value);
    if (text) return text;
  }
  return fallback;
}

function csvCell(value: string): string {
  if (!/[",\n\r]/.test(value)) return value;
  return `"${value.replaceAll('"', '""')}"`;
}

function competitorRowsToCsv(rows: TomeCompetitorRow[]): string {
  const headers: Array<keyof TomeCompetitorRow> = [
    "Product",
    "Feature",
    "Price",
    "Risk",
    "Countermove",
    "Source",
  ];
  return [
    headers.join(","),
    ...rows.map((row) =>
      headers.map((header) => csvCell(row[header])).join(",")
    ),
  ].join("\n");
}

function buildTomeCompetitorMarkdown(
  topic: string,
  audience: string,
  rows: TomeCompetitorRow[],
  source: string,
): string {
  const topRows = rows.slice(0, 8);
  const lines = topRows.map((row) =>
    `- ${row.Product}: feature=${row.Feature || "-"} / risk=${
      row.Risk || "-"
    } / countermove=${row.Countermove || "-"}`
  );
  return [
    `# Tome Competitor Comparison (${new Date().toISOString().slice(0, 10)})`,
    "",
    `Audience: ${audience || "Product and marketing team"}`,
    `Source: ${source}`,
    "",
    "## KGI",
    `Keep ${
      topic || "competitor comparison"
    } fresh enough to guide weekly product decisions.`,
    "",
    "## CSF",
    "- Use Airtable or the competitors table as the structured source of facts",
    "- Separate factual comparison from strategic interpretation",
    "- Convert every high-risk finding into a WBS action",
    "",
    "## KPI",
    `- Source rows: ${rows.length}`,
    "- Weekly refreshes: 1",
    "- WBS actions per high-risk finding: 1",
    "",
    "## Competitor Summary",
    ...(lines.length > 0 ? lines : ["- No competitor rows available yet."]),
    "",
    "## Tome Prompt",
    "Create a concise Tome deck with a market map, comparison table, threat ranking, counter strategy, and automation cadence.",
  ].join("\n");
}

async function fetchAirtableCompetitorRows(): Promise<{
  configured: boolean;
  rows: TomeCompetitorRow[];
}> {
  const token = Deno.env.get("AIRTABLE_API_KEY") ??
    Deno.env.get("AIRTABLE_PAT") ?? "";
  const baseId = Deno.env.get("AIRTABLE_BASE_ID") ?? "";
  const tableName = Deno.env.get("AIRTABLE_TABLE_NAME") ??
    Deno.env.get("AIRTABLE_COMPETITOR_TABLE") ?? "";
  const view = Deno.env.get("AIRTABLE_VIEW") ?? "";
  if (!token || !baseId || !tableName) {
    return { configured: false, rows: [] };
  }

  const rows: TomeCompetitorRow[] = [];
  let offset = "";
  do {
    const url = new URL(
      `https://api.airtable.com/v0/${baseId}/${encodeURIComponent(tableName)}`,
    );
    url.searchParams.set("pageSize", "100");
    if (view) url.searchParams.set("view", view);
    if (offset) url.searchParams.set("offset", offset);

    const res = await fetch(url, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) {
      throw new Error(
        `Airtable request failed: ${res.status} ${await res.text()}`,
      );
    }
    const payload = await res.json() as {
      records?: Array<{ fields?: Record<string, unknown> }>;
      offset?: string;
    };
    for (const record of payload.records ?? []) {
      const fields = record.fields ?? {};
      rows.push({
        Product: pickField(
          fields,
          ["Product", "Name", "Competitor", "Company"],
          "Unknown",
        ),
        Feature: pickField(fields, [
          "Feature",
          "Key Feature",
          "Capability",
          "Description",
        ]),
        Price: pickField(fields, ["Price", "Pricing", "Plan"]),
        Risk: pickField(fields, ["Risk", "Threat", "Threat Level", "Overlap"]),
        Countermove: pickField(fields, [
          "Countermove",
          "Next Step",
          "Action",
          "WBS Action",
        ]),
        Source: "Airtable",
      });
    }
    offset = payload.offset ?? "";
  } while (offset && rows.length < 500);

  return { configured: true, rows };
}

async function fetchSupabaseCompetitorRows(
  admin: SupabaseClient,
): Promise<TomeCompetitorRow[]> {
  const { data, error } = await admin.from("competitors")
    .select(
      "id, display_name, name, category, description, funding_or_valuation, key_features, jp_strength, jp_weakness, threat_level, our_overlap_score",
    )
    .eq("is_active", true)
    .order("sort_order", { ascending: true })
    .limit(30);
  if (error) throw new Error(error.message);
  return (data ?? []).map((row: Record<string, unknown>) => {
    const product = textValue(
      row.name,
      textValue(row.display_name, textValue(row.id, "Unknown")),
    );
    const feature = textValue(
      row.key_features,
      textValue(row.description, textValue(row.category)),
    );
    const risk = [
      textValue(row.threat_level),
      textValue(row.our_overlap_score)
        ? `overlap ${row.our_overlap_score}/10`
        : "",
      textValue(row.jp_strength),
    ].filter(Boolean).join(" / ");
    return {
      Product: product,
      Feature: feature,
      Price: textValue(row.funding_or_valuation, "unknown"),
      Risk: risk,
      Countermove: textValue(row.jp_weakness, "Add WBS counter task"),
      Source: "Supabase competitors",
    };
  });
}

async function deleteItem(
  admin: SupabaseClient,
  source: string,
  userId: string,
  id: string,
) {
  const { error } = await admin.from("hub_data")
    .delete().eq("id", id).eq("source", source)
    .filter("metadata->>user_id", "eq", userId);
  if (error) throw new Error(error.message);
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const body: Record<string, unknown> = req.method === "POST"
      ? await req.json().catch(() => ({}))
      : {};
    const action = (body.action as string) ?? url.searchParams.get("action") ??
      "";
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });
    const userId = await getUserId(req);
    if (!userId) return json({ error: "Unauthorized" }, 401);

    const registryResponse = await handleIntegrationRegistryAction({
      action,
      body,
      userId,
      store: createSupabaseIntegrationRegistryStore(admin),
    });
    if (registryResponse) return registryResponse;

    switch (action) {
      // ── Leave Management ─────────────────────────────────────────────────────
      case "leave.list":
        return json({
          success: true,
          requests: await listItems(admin, "leave_request", userId),
        });
      case "leave.request": {
        const item = await addItem(admin, "leave_request", userId, {
          type: body.type ?? "paid",
          start_date: body.start_date,
          end_date: body.end_date,
          reason: body.reason,
          status: "pending",
          days: body.days,
        });
        return json({ success: true, request: item });
      }
      case "leave.approve": {
        const { error } = await admin.from("hub_data")
          .update({
            metadata: {
              user_id: userId,
              status: "approved",
              approved_by: userId,
              approved_at: new Date().toISOString(),
            },
          })
          .eq("id", String(body.id ?? "")).eq("source", "leave_request");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      // ── Performance Review ───────────────────────────────────────────────────
      case "review.list":
        return json({
          success: true,
          reviews: await listItems(admin, "performance_review", userId),
        });
      case "review.create": {
        const item = await addItem(admin, "performance_review", userId, {
          reviewee_id: body.reviewee_id,
          period: body.period,
          rating: body.rating,
          strengths: body.strengths,
          improvements: body.improvements,
          goals: body.goals,
        });
        return json({ success: true, review: item });
      }

      // ── Compensation Manager ─────────────────────────────────────────────────
      case "compensation.list":
        return json({
          success: true,
          records: await listItems(admin, "compensation", userId),
        });
      case "compensation.set": {
        const item = await addItem(admin, "compensation", userId, {
          employee_id: body.employee_id,
          base_salary: body.base_salary,
          bonus: body.bonus,
          effective_date: body.effective_date,
          currency: body.currency ?? "JPY",
        });
        return json({ success: true, record: item });
      }

      // ── Recruitment ──────────────────────────────────────────────────────────
      case "recruit.list_jobs":
        return json({
          success: true,
          jobs: await listItems(admin, "job_posting", userId),
        });
      case "recruit.post_job": {
        const item = await addItem(admin, "job_posting", userId, {
          title: body.title,
          description: body.description,
          requirements: body.requirements,
          salary_range: body.salary_range,
          status: "open",
        });
        return json({ success: true, job: item });
      }
      case "recruit.list_applicants":
        return json({
          success: true,
          applicants: await listItems(admin, "job_applicant", userId),
        });
      case "recruit.add_applicant": {
        const item = await addItem(admin, "job_applicant", userId, {
          job_id: body.job_id,
          name: body.name,
          email: body.email,
          resume_url: body.resume_url,
          status: "pending",
        });
        return json({ success: true, applicant: item });
      }

      // ── Compliance ───────────────────────────────────────────────────────────
      case "compliance.check": {
        const item = await addItem(admin, "compliance_check", userId, {
          domain: body.domain,
          items: body.items ?? [],
          result: body.result ?? "pass",
          notes: body.notes,
          checked_at: new Date().toISOString(),
        });
        return json({ success: true, check: item });
      }
      case "compliance.list":
        return json({
          success: true,
          checks: await listItems(admin, "compliance_check", userId),
        });
      case "legal.list":
        return json({
          success: true,
          documents: await listItems(admin, "legal_doc", userId),
        });
      case "legal.add": {
        const item = await addItem(admin, "legal_doc", userId, {
          title: body.title,
          type: body.type,
          content: body.content,
          effective_date: body.effective_date,
        });
        return json({ success: true, document: item });
      }
      case "legal-assistant.harvey.complete": {
        const task = await addItem(admin, "legal_task", userId, {
          prompt: body.prompt,
          response: "[Harvey AI]",
          completed_at: new Date().toISOString(),
        });
        return json({ success: true, result: task });
      }

      // ── Audit Trail ──────────────────────────────────────────────────────────
      case "audit.log": {
        const item = await addItem(admin, "audit_trail", userId, {
          action: body.audit_action,
          resource: body.resource,
          details: body.details,
          ip: req.headers.get("x-forwarded-for") ?? "unknown",
          timestamp: new Date().toISOString(),
        });
        return json({ success: true, entry: item });
      }
      case "audit.list":
        return json({
          success: true,
          entries: await listItems(admin, "audit_trail", userId, 100),
        });

      // ── CI/CD Pipeline ───────────────────────────────────────────────────────
      case "cicd.list_pipelines":
        return json({
          success: true,
          pipelines: await listItems(admin, "cicd_pipeline", userId),
        });
      case "cicd.create_pipeline": {
        const item = await addItem(admin, "cicd_pipeline", userId, {
          name: body.name,
          repo: body.repo,
          stages: body.stages ?? [],
          trigger: body.trigger ?? "push",
        });
        return json({ success: true, pipeline: item });
      }
      case "cicd.run": {
        const item = await addItem(admin, "cicd_run", userId, {
          pipeline_id: body.pipeline_id,
          status: "running",
          started_at: new Date().toISOString(),
        });
        return json({ success: true, run: item });
      }

      // ── Code Playground ──────────────────────────────────────────────────────
      case "playground.save": {
        const item = await addItem(admin, "code_snippet", userId, {
          title: body.title,
          language: body.language ?? "dart",
          code: body.code,
          output: body.output,
          is_public: body.is_public ?? false,
        });
        return json({ success: true, snippet: item });
      }
      case "playground.list":
        return json({
          success: true,
          snippets: await listItems(admin, "code_snippet", userId),
        });

      // ── API Docs ─────────────────────────────────────────────────────────────
      case "apidocs.generate": {
        const item = await addItem(admin, "api_doc", userId, {
          title: body.title,
          spec: body.spec,
          format: body.format ?? "openapi",
          version: body.version ?? "1.0.0",
        });
        return json({ success: true, doc: item });
      }
      case "apidocs.list":
        return json({
          success: true,
          docs: await listItems(admin, "api_doc", userId),
        });

      // ── API Key Manager ──────────────────────────────────────────────────────
      case "apikey.list":
        return json({
          success: true,
          keys: await listItems(admin, "api_key_entry", userId),
        });
      case "apikey.create": {
        const key = crypto.randomUUID().replace(/-/g, "");
        const item = await addItem(admin, "api_key_entry", userId, {
          name: body.name,
          key_hash: key.slice(0, 8) + "****",
          scopes: body.scopes ?? ["read"],
          expires_at: body.expires_at,
        });
        return json({ success: true, key, entry: item });
      }
      case "apikey.revoke": {
        await deleteItem(admin, "api_key_entry", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── DNS/Domain Manager ───────────────────────────────────────────────────
      case "dns.list":
        return json({
          success: true,
          records: await listItems(admin, "dns_record", userId),
        });
      case "dns.add": {
        const item = await addItem(admin, "dns_record", userId, {
          domain: body.domain,
          type: body.type ?? "A",
          value: body.value,
          ttl: body.ttl ?? 3600,
        });
        return json({ success: true, record: item });
      }

      case "dns.list_records":
        return json({
          success: true,
          records: (await listItems(admin, "dns_record", userId)).filter((
            r: Record<string, unknown>,
          ) => r.domain_id === body.domain_id),
        });
      case "dns.ssl_status":
        return json({
          success: true,
          domains: await listItems(admin, "ssl_certificate", userId),
        });
      case "dns.add_record": {
        const item = await addItem(admin, "dns_record", userId, {
          domain_id: body.domain_id,
          name: body.name,
          type: body.type ?? "A",
          value: body.value,
          ttl: body.ttl ?? 3600,
        });
        return json({ success: true, record: item });
      }
      case "dns.delete_record": {
        await admin.from("hub_data").delete().eq("id", body.record_id).eq(
          "user_id",
          userId,
        );
        return json({ success: true });
      }

      // ── A/B Testing ──────────────────────────────────────────────────────────
      case "ab.create": {
        const variants =
          Array.isArray(body.variants) && body.variants.length > 0
            ? body.variants
            : [body.variant_a, body.variant_b].filter((v) =>
              v !== undefined && v !== null
            );
        const item = await addItem(admin, "ab_test", userId, {
          name: body.name,
          variants,
          variant_a: body.variant_a ?? variants[0] ?? null,
          variant_b: body.variant_b ?? variants[1] ?? null,
          metric: body.metric ?? null,
          status: "running",
        });
        return json({ success: true, test: item });
      }
      case "ab.list": {
        const raw = await listItems(admin, "ab_test", userId);
        const tests = (raw ?? []).map((r: Record<string, unknown>) => ({
          id: r.id,
          ...(r.metadata as Record<string, unknown>),
          createdAt: r.created_at,
        }));
        return json({ success: true, tests });
      }
      case "ab.record": {
        const item = await addItem(admin, "ab_event", userId, {
          test_id: body.test_id,
          variant: body.variant,
          converted: body.converted ?? false,
        });
        return json({ success: true, event: item });
      }
      case "integration.mapping_profiles": {
        return json({
          success: true,
          profiles: await listItems(
            admin,
            "integration_mapping_profile",
            userId,
          ),
        });
      }
      case "integration.mapping_profile.save": {
        const profile = (body.profile ?? {}) as Record<string, unknown>;
        const mappings = Array.isArray(profile.mappings)
          ? profile.mappings
          : [];
        const item = await addItem(
          admin,
          "integration_mapping_profile",
          userId,
          {
            profile: {
              id: String(profile.id ?? "custom"),
              label: String(profile.label ?? "Custom mapping"),
              delimiter: String(profile.delimiter ?? ","),
              mappings,
            },
            format_id: String(profile.id ?? "custom"),
            mapping_count: mappings.length,
            saved_at: new Date().toISOString(),
          },
        );
        return json({ success: true, profile: item });
      }

      // ── Deployment Monitoring ────────────────────────────────────────────────
      case "deployment.monitoring_setups": {
        return json({
          success: true,
          setups: await listItems(
            admin,
            "deployment_monitoring_setup",
            userId,
          ),
        });
      }
      case "deployment.monitoring.setup": {
        const record = buildDeploymentMonitoringRecord(body);
        const item = await addItem(
          admin,
          "deployment_monitoring_setup",
          userId,
          {
            ...record,
            saved_at: new Date().toISOString(),
          },
        );
        return json({
          success: true,
          setup: item,
          monitoring: record,
        });
      }

      // ── Feature Flags ────────────────────────────────────────────────────────
      case "flags.list": {
        const { data } = await admin.from("hub_data")
          .select("id, metadata, created_at").eq("source", "feature_flag")
          .order("created_at", { ascending: false });
        return json({ success: true, flags: data ?? [] });
      }
      case "flags.set": {
        const item = await addItem(admin, "feature_flag", userId, {
          name: body.name,
          enabled: body.enabled ?? false,
          rollout_pct: body.rollout_pct ?? 100,
          conditions: body.conditions ?? {},
        });
        return json({ success: true, flag: item });
      }
      case "flags.check": {
        const { data } = await admin.from("hub_data")
          .select("metadata").eq("source", "feature_flag")
          .filter("metadata->>name", "eq", String(body.name ?? ""))
          .order("created_at", { ascending: false }).limit(1).single();
        const enabled = (data?.metadata as Record<string, unknown>)?.enabled ??
          false;
        return json({ success: true, name: body.name, enabled });
      }

      // ── Custom Dashboard Builder ─────────────────────────────────────────────
      case "dashboard.list":
        return json({
          success: true,
          dashboards: await listItems(admin, "custom_dashboard", userId),
        });
      case "dashboard.create": {
        const item = await addItem(admin, "custom_dashboard", userId, {
          name: body.name,
          widgets: body.widgets ?? [],
          layout: body.layout ?? [],
        });
        return json({ success: true, dashboard: item });
      }
      case "dashboard.update": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { ...body, user_id: userId } })
          .eq("id", String(body.id ?? "")).eq("source", "custom_dashboard");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      // ── Data Pipeline ────────────────────────────────────────────────────────
      case "pipeline.list":
        return json({
          success: true,
          pipelines: await listItems(admin, "data_pipeline", userId),
        });
      case "pipeline.create": {
        const item = await addItem(admin, "data_pipeline", userId, {
          name: body.name,
          source: body.source,
          destination: body.destination,
          transform: body.transform ?? [],
          schedule: body.schedule,
        });
        return json({ success: true, pipeline: item });
      }
      case "pipeline.run": {
        const item = await addItem(admin, "pipeline_run", userId, {
          pipeline_id: body.pipeline_id,
          status: "running",
          rows_processed: 0,
          started_at: new Date().toISOString(),
        });
        return json({ success: true, run: item });
      }

      // ── Analytics & Cohorts ──────────────────────────────────────────────────
      case "analytics.export": {
        const { data } = await admin.from("hub_data")
          .select("*").gte("created_at", String(body.from ?? "2020-01-01"))
          .limit(1000);
        return json({
          success: true,
          rows: data?.length ?? 0,
          data: data ?? [],
        });
      }
      case "analytics.export_options":
        return json({
          success: true,
          options: await listItems(admin, "analytics_export_option", userId),
        });
      case "analytics.export_history":
        return json({
          success: true,
          history: await listItems(admin, "analytics_export", userId),
        });
      case "cohort.create": {
        const item = await addItem(admin, "cohort", userId, {
          name: body.name,
          criteria: body.criteria,
          size: body.size ?? 0,
        });
        return json({ success: true, cohort: item });
      }
      case "cohort.list":
        return json({
          success: true,
          cohorts: await listItems(admin, "cohort", userId),
        });
      case "search_analytics.list":
        return json({
          success: true,
          queries: await listItems(admin, "search_query", userId),
        });
      case "search_analytics.record": {
        const item = await addItem(admin, "search_query", userId, {
          query: body.query,
          results_count: body.results_count ?? 0,
          clicked: body.clicked ?? false,
        });
        return json({ success: true, record: item });
      }

      // ── Revenue Forecaster ───────────────────────────────────────────────────
      case "forecast.create": {
        const item = await addItem(admin, "revenue_forecast", userId, {
          period: body.period,
          amount: body.amount,
          model: body.model ?? "linear",
          assumptions: body.assumptions ?? {},
        });
        return json({ success: true, forecast: item });
      }
      case "forecast.list":
        return json({
          success: true,
          forecasts: await listItems(admin, "revenue_forecast", userId),
        });

      // ── Sitemap Analytics ─────────────────────────────────────────────────────
      case "sitemap.analyze": {
        const sitemapUrl = String(body.url ?? "");
        const res = await fetch(sitemapUrl).catch(() => null);
        const urls = res?.ok
          ? (await res.text()).match(/https?:\/\/[^\s<>]+/g) ?? []
          : [];
        return json({
          success: true,
          url_count: urls.length,
          urls: urls.slice(0, 100),
        });
      }

      // ── User Onboarding ──────────────────────────────────────────────────────
      case "onboarding.get": {
        const steps = await listItems(admin, "onboarding_step", userId, 20);
        return json({ success: true, completed_steps: steps.length, steps });
      }
      case "onboarding.complete_step": {
        const item = await addItem(admin, "onboarding_step", userId, {
          step: body.step,
          completed_at: new Date().toISOString(),
        });
        return json({ success: true, step: item });
      }

      // ── CRM / Sales Pipeline ─────────────────────────────────────────────────
      case "crm.list_leads":
        return json({
          success: true,
          leads: await listItems(admin, "crm_lead", userId),
        });
      case "crm.add_lead": {
        const item = await addItem(admin, "crm_lead", userId, {
          name: body.name,
          company: body.company,
          email: body.email,
          stage: body.stage ?? "prospect",
          value: body.value,
          notes: body.notes,
        });
        return json({ success: true, lead: item });
      }
      case "crm.update_stage": {
        const { error } = await admin.from("hub_data")
          .update({
            metadata: {
              user_id: userId,
              stage: body.stage,
              updated_at: new Date().toISOString(),
            },
          })
          .eq("id", String(body.id ?? "")).eq("source", "crm_lead");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      // ── GitHub PR Manager ────────────────────────────────────────────────────
      case "github.list_prs": {
        const token = Deno.env.get("GITHUB_PAT") ?? "";
        const repo = String(body.repo ?? "");
        if (!token || !repo) {
          return json({ error: "GITHUB_PAT and repo required" }, 400);
        }
        const res = await fetch(
          `https://api.github.com/repos/${repo}/pulls?state=open`,
          {
            headers: {
              Authorization: `Bearer ${token}`,
              Accept: "application/vnd.github+json",
            },
          },
        );
        const prs = await res.json();
        return json({ success: true, prs });
      }
      case "github.list_issues": {
        const token = Deno.env.get("GITHUB_PAT") ?? "";
        const repo = String(body.repo ?? "");
        if (!token || !repo) {
          return json({ error: "GITHUB_PAT and repo required" }, 400);
        }
        const res = await fetch(
          `https://api.github.com/repos/${repo}/issues?state=open&per_page=30`,
          {
            headers: {
              Authorization: `Bearer ${token}`,
              Accept: "application/vnd.github+json",
            },
          },
        );
        const issues = await res.json();
        return json({ success: true, issues });
      }
      case "github.configure": {
        await admin.from("hub_data").upsert({
          user_id: userId,
          source: "github_config",
          metadata: { token: body.token, repo: body.repo },
        }, { onConflict: "user_id,source" });
        return json({ success: true });
      }
      case "calendar.status": {
        const { data } = await admin.from("hub_data").select("metadata").eq(
          "source",
          "calendar_config",
        ).eq("user_id", userId).maybeSingle();
        return json({
          success: true,
          connected: !!(data?.metadata as Record<string, unknown>)
            ?.access_token,
          status: data ? "connected" : "disconnected",
        });
      }
      case "calendar.sync":
        return json({ success: true, synced: 0, message: "Sync scheduled" });
      case "calendar.connect_url":
        return json({ success: true, url: "/oauth/google-calendar" });

      // ── User Growth Analytics ─────────────────────────────────────────────────
      case "growth.user_stats": {
        const { count } = await admin.from("profiles").select("*", {
          count: "exact",
          head: true,
        });
        const recent = await admin.from("profiles")
          .select("created_at").gte(
            "created_at",
            new Date(Date.now() - 7 * 86400000).toISOString(),
          );
        return json({
          success: true,
          total_users: count ?? 0,
          new_this_week: recent.data?.length ?? 0,
        });
      }

      // ── Gantt / Task Dependency ──────────────────────────────────────────────
      case "gantt.list":
        return json({
          success: true,
          tasks: await listItems(admin, "gantt_task", userId),
        });
      case "gantt.create_task": {
        const item = await addItem(admin, "gantt_task", userId, {
          name: body.name,
          start_date: body.start_date,
          end_date: body.end_date,
          progress: body.progress ?? 0,
          dependencies: body.dependencies ?? [],
          assignee: body.assignee,
        });
        return json({ success: true, task: item });
      }
      case "gantt.update": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { ...body, user_id: userId } })
          .eq("id", String(body.id ?? "")).eq("source", "gantt_task");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "dependency.add": {
        const item = await addItem(admin, "task_dependency", userId, {
          task_id: body.task_id,
          depends_on: body.depends_on,
          type: body.type ?? "finish-to-start",
        });
        return json({ success: true, dependency: item });
      }

      // ── Spreadsheet Database ──────────────────────────────────────────────────
      case "sheet.list":
        return json({
          success: true,
          sheets: await listItems(admin, "spreadsheet", userId),
        });
      case "sheet.create": {
        const item = await addItem(admin, "spreadsheet", userId, {
          name: body.name,
          columns: body.columns ?? [],
          rows: body.rows ?? [],
        });
        return json({ success: true, sheet: item });
      }
      case "sheet.add_row": {
        const item = await addItem(admin, "sheet_row", userId, {
          sheet_id: body.sheet_id,
          data: body.data,
        });
        return json({ success: true, row: item });
      }

      // ── Wiki / Knowledge Base ─────────────────────────────────────────────────
      case "wiki.list": {
        const { data } = await admin.from("hub_data")
          .select("id, metadata, created_at").eq("source", "wiki_page")
          .order("created_at", { ascending: false }).limit(50);
        return json({ success: true, pages: data ?? [] });
      }
      case "wiki.create": {
        const item = await addItem(admin, "wiki_page", userId, {
          title: body.title,
          content: body.content,
          category: body.category,
          tags: body.tags ?? [],
          is_public: body.is_public ?? false,
        });
        return json({ success: true, page: item });
      }
      case "wiki.update": {
        const { error } = await admin.from("hub_data")
          .update({
            metadata: {
              ...body,
              user_id: userId,
              updated_at: new Date().toISOString(),
            },
          })
          .eq("id", String(body.id ?? "")).eq("source", "wiki_page");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "kb.search": {
        const query = String(body.query ?? "");
        const { data } = await admin.from("hub_data")
          .select("id, metadata, created_at")
          .eq("source", "wiki_page")
          .ilike("metadata->>title", `%${query}%`)
          .limit(20);
        return json({ success: true, results: data ?? [] });
      }

      // ── Integration Connector ─────────────────────────────────────────────────
      case "integration.list":
        return json({
          success: true,
          integrations: await listItems(admin, "integration", userId),
        });
      case "integration.add": {
        const item = await addItem(admin, "integration", userId, {
          name: body.name,
          type: body.type,
          config: body.config,
          status: "active",
        });
        return json({ success: true, integration: item });
      }
      case "integration.webhook": {
        const item = await addItem(admin, "webhook_event", userId, {
          integration_id: body.integration_id,
          event: body.event,
          payload: body.payload,
        });
        return json({ success: true, event: item });
      }

      // ── Email Template Builder ────────────────────────────────────────────────
      case "email_template.list":
        return json({
          success: true,
          templates: await listItems(admin, "email_template", userId),
        });
      case "email_template.create": {
        const item = await addItem(admin, "email_template", userId, {
          name: body.name,
          subject: body.subject,
          html: body.html,
          variables: body.variables ?? [],
        });
        return json({ success: true, template: item });
      }
      case "email_template.use": {
        const { data } = await admin.from("hub_data").select("*").eq(
          "id",
          body.template_id,
        ).maybeSingle();
        return json({ success: true, template: data });
      }
      case "search.semantic": {
        const { data } = await admin.from("hub_data").select("*").ilike(
          "content",
          "%" + String(body.query ?? "") + "%",
        ).limit(Number(body.limit ?? 20));
        return json({ success: true, results: data ?? [] });
      }

      // ── Workflow Templates ─────────────────────────────────────────────────────
      case "workflow.list":
        return json({
          success: true,
          workflows: await listItems(admin, "workflow_template", userId),
        });
      case "workflow.create": {
        const item = await addItem(admin, "workflow_template", userId, {
          name: body.name,
          steps: body.steps ?? [],
          triggers: body.triggers ?? [],
        });
        return json({ success: true, workflow: item });
      }

      // ── AI Writing Assistant ──────────────────────────────────────────────────
      case "ai_write.generate": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) {
          return json({ error: "GEMINI_API_KEY not configured" }, 503);
        }
        const prompt = String(body.prompt ?? "");
        const tone = String(body.tone ?? "professional");
        const res = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              contents: [{ parts: [{ text: `Tone: ${tone}\n\n${prompt}` }] }],
            }),
          },
        );
        const result = await res.json() as {
          candidates?: Array<
            { content?: { parts?: Array<{ text?: string }> } }
          >;
        };
        const text = result.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
        await addItem(admin, "ai_write", userId, {
          prompt,
          tone,
          result: text,
        });
        return json({ success: true, text });
      }

      // ── AI Workflow Automation ─────────────────────────────────────────────────
      case "ai_workflow.create": {
        const item = await addItem(admin, "ai_workflow", userId, {
          name: body.name,
          trigger: body.trigger,
          steps: body.steps ?? [],
          ai_model: body.ai_model ?? "gemini-2.5-flash",
          status: "active",
        });
        return json({ success: true, workflow: item });
      }
      case "ai_workflow.list":
        return json({
          success: true,
          workflows: await listItems(admin, "ai_workflow", userId),
        });
      case "ai_workflow.run": {
        const run = await addItem(admin, "ai_workflow_run", userId, {
          workflow_id: body.workflow_id,
          input: body.input,
          started_at: new Date().toISOString(),
        });
        return json({ success: true, run });
      }

      // ── Election Intelligence ──────────────────────────────────────────────────
      case "election.search": {
        const query = String(body.query ?? "選挙");
        const res = await fetch(
          `https://newsapi.org/v2/everything?q=${
            encodeURIComponent(query)
          }&language=ja&sortBy=publishedAt&pageSize=10&apiKey=${
            Deno.env.get("NEWS_API_KEY") ?? ""
          }`,
        )
          .catch(() => null);
        if (!res || !res.ok) {
          return json({ error: "News API unavailable" }, 502);
        }
        const data = await res.json();
        return json({ success: true, articles: data });
      }
      case "election.analyze": {
        const item = await addItem(admin, "election_analysis", userId, {
          region: body.region,
          candidates: body.candidates ?? [],
          analysis: body.analysis,
        });
        return json({ success: true, analysis: item });
      }

      // ── Competitor Feature Sync ────────────────────────────────────────────────
      case "competitor.sync": {
        const { data } = await admin.from("hub_data")
          .select("metadata, created_at")
          .eq("source", "competitor_feature")
          .order("created_at", { ascending: false })
          .limit(50);
        return json({ success: true, features: data ?? [] });
      }
      case "competitor.reports": {
        const reports = await listItems(admin, "competitor_report", userId, 12);
        return json({ success: true, reports });
      }
      case "tome.competitor_airtable_deck": {
        const topic = String(
          body.topic ?? "Competitor comparison and weekly product decision",
        );
        const audience = String(body.audience ?? "Product and marketing team");
        let source = "Airtable";
        let warning = "";
        let rows: TomeCompetitorRow[] = [];
        try {
          const airtable = await fetchAirtableCompetitorRows();
          if (airtable.configured && airtable.rows.length > 0) {
            rows = airtable.rows;
          } else {
            source = "Supabase competitors";
            warning = airtable.configured
              ? "Airtable returned no records; fallback competitors table was used."
              : "Airtable secrets are not fully configured; fallback competitors table was used.";
            rows = await fetchSupabaseCompetitorRows(admin);
          }
        } catch (error) {
          source = "Supabase competitors";
          warning = `Airtable sync failed (${
            error instanceof Error ? error.message : String(error)
          }); fallback competitors table was used.`;
          rows = await fetchSupabaseCompetitorRows(admin);
        }

        const csv = competitorRowsToCsv(rows);
        const markdown = buildTomeCompetitorMarkdown(
          topic,
          audience,
          rows,
          source,
        );
        const report = await addItem(admin, "tome_competitor_deck", userId, {
          topic,
          audience,
          source,
          warning,
          row_count: rows.length,
          csv,
          markdown,
          generated_at: new Date().toISOString(),
        });
        return json({
          success: true,
          source,
          warning,
          rowCount: rows.length,
          csv,
          markdown,
          report,
        });
      }
      case "competitor.weekly_manus_report": {
        const { data } = await admin.from("hub_data")
          .select("metadata, created_at")
          .eq("source", "competitor_feature")
          .filter("metadata->>user_id", "eq", userId)
          .order("created_at", { ascending: false })
          .limit(80);
        const rows = data ?? [];
        const byCompetitor = new Map<
          string,
          { total: number; statuses: Map<string, number>; latest: string[] }
        >();
        for (const row of rows) {
          const meta = (row.metadata ?? {}) as Record<string, unknown>;
          const competitor = String(meta.competitor ?? "unknown");
          const status = String(meta.status ?? "detected");
          const feature = String(meta.feature ?? "(feature)");
          const current = byCompetitor.get(competitor) ?? {
            total: 0,
            statuses: new Map<string, number>(),
            latest: [],
          };
          current.total += 1;
          current.statuses.set(status, (current.statuses.get(status) ?? 0) + 1);
          if (current.latest.length < 5) current.latest.push(feature);
          byCompetitor.set(competitor, current);
        }
        const generatedAt = new Date().toISOString();
        const reportId = `manus-weekly-${generatedAt.slice(0, 10)}`;
        const competitorSummaries = Array.from(byCompetitor.entries()).map((
          [name, value],
        ) => ({
          name,
          total: value.total,
          statuses: Object.fromEntries(value.statuses.entries()),
          latest: value.latest,
        }));
        const topLines = competitorSummaries.length === 0
          ? [
            "- No competitor features recorded yet. Start by adding detected features from the sync screen.",
          ]
          : competitorSummaries.map((c) =>
            `- ${c.name}: ${c.total}件 / ${
              Object.entries(c.statuses).map(([k, v]) => `${k}:${v}`).join(", ")
            } / latest: ${c.latest.slice(0, 3).join("、")}`
          );
        const reportMarkdown = [
          `# Manus Weekly Competitor Report (${generatedAt.slice(0, 10)})`,
          "",
          "## KGI",
          "競合の新機能・訴求・運用変化を週次で把握し、自社の次の改善タスクへ接続する。",
          "",
          "## CSF",
          "- 競合ごとの変化量を比較する",
          "- 未対応の差分をプロダクト/マーケ/営業タスクへ落とす",
          "- 週次で同じ観点を継続観測する",
          "",
          "## KPI",
          `- 監視対象フィーチャー: ${rows.length}件`,
          `- 競合数: ${competitorSummaries.length}件`,
          "- 次回実行: 7日後",
          "",
          "## Competitor Summary",
          ...topLines,
          "",
          "## Manus Action Plan",
          "1. 変化量が多い競合を1社選び、差分機能を自社WBSへ追加する。",
          "2. 既存機能で代替できる差分はUI/導線改善として小さく実装する。",
          "3. 差分が大きいものはAI大学/AI組織OS/ライフマネジメントのどれに効くか分類する。",
        ].join("\n");
        const report = await addItem(admin, "competitor_report", userId, {
          report_id: reportId,
          generated_at: generatedAt,
          engine: "manus_like",
          cadence: "weekly",
          feature_count: rows.length,
          competitor_count: competitorSummaries.length,
          competitor_summaries: competitorSummaries,
          report_markdown: reportMarkdown,
        });
        return json({ success: true, report });
      }
      case "competitor.add_feature": {
        const item = await addItem(admin, "competitor_feature", userId, {
          competitor: body.competitor,
          feature: body.feature,
          status: body.status ?? "detected",
          detected_at: new Date().toISOString(),
        });
        return json({ success: true, feature: item });
      }

      // ── Edge Function Utilities ─────────────────────────────────────────────────
      case "ef.list_deployed": {
        const { data } = await admin.from("hub_data")
          .select("metadata, created_at").eq("source", "ef_deployment")
          .order("created_at", { ascending: false }).limit(100);
        return json({ success: true, deployments: data ?? [] });
      }
      case "ef.test": {
        const efName = String(body.ef_name ?? "");
        const efUrl = `${SUPABASE_URL}/functions/v1/${efName}`;
        const res = await fetch(efUrl, {
          method: "GET",
          headers: { Authorization: `Bearer ${SERVICE_ROLE_KEY}` },
        }).catch(() => null);
        const ok = res ? res.status < 500 : false;
        await addItem(admin, "ef_test", userId, {
          ef_name: efName,
          status: ok ? "ok" : "fail",
          tested_at: new Date().toISOString(),
        });
        return json({
          success: true,
          ef_name: efName,
          reachable: ok,
          http_status: res?.status ?? 0,
        });
      }
      case "ef.ui_check": {
        const item = await addItem(admin, "ef_ui_check", userId, {
          ef_name: body.ef_name,
          ui_connected: body.ui_connected ?? false,
          notes: body.notes,
        });
        return json({ success: true, check: item });
      }

      // ── AI Agent Hub ────────────────────────────────────────────────────────────
      case "agent.departments": {
        const departments = await listItems(admin, "agent_department", userId);
        return json({ success: true, departments });
      }
      case "agent.performance": {
        const ranking = await listItems(admin, "agent_performance", userId);
        return json({ success: true, ranking });
      }
      case "agent.routing": {
        const items = await listItems(admin, "agent_routing", userId, 1);
        const routing = items[0]?.metadata ??
          { rules: [], default_agent: "general" };
        return json({ success: true, ...routing });
      }

      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
