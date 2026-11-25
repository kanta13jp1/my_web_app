import {
  AI_COMPLIANCE_SOURCE,
  areAllChecklistItemsComplete,
  buildComplianceChecklist,
  canInvokeProvider,
  COMPLIANCE_STATUS_LABELS,
  COMPLIANCE_STATUSES,
  isChecklistApproveEligible,
  normalizeComplianceStatus,
  type ComplianceChecklist,
  type ComplianceStatus,
} from "../_shared/ai_compliance_guard.ts";

const DEFAULT_REPO_SLUG = "kanta13jp1/my_web_app";
const DEFAULT_LIMIT = 50;

export class AiComplianceError extends Error {
  status: number;
  payload: Record<string, unknown>;

  constructor(
    message: string,
    status = 400,
    payload: Record<string, unknown> = {},
  ) {
    super(message);
    this.name = "AiComplianceError";
    this.status = status;
    this.payload = payload;
  }
}

export interface HubDataRow {
  id: string;
  metadata: Record<string, unknown> | null;
  created_at?: string;
}

type DbError = {
  code?: string;
  message?: string;
};

type DbResult<T> = {
  data: T | null;
  error?: DbError | null;
};

export type HubQuery<T = unknown> = PromiseLike<DbResult<T>> & {
  select(columns: string): HubQuery<T>;
  insert(values: Record<string, unknown>): HubQuery<T>;
  update(values: Record<string, unknown>): HubQuery<T>;
  eq(column: string, value: unknown): HubQuery<T>;
  filter(column: string, operator: string, value: unknown): HubQuery<T>;
  order(
    column: string,
    options?: { ascending?: boolean },
  ): HubQuery<T>;
  limit(count: number): HubQuery<T>;
  single(): PromiseLike<DbResult<T>>;
  maybeSingle(): PromiseLike<DbResult<T | null>>;
};

export interface AiComplianceDb {
  from(table: string): unknown;
}

export interface GitHubIssueCreateResult {
  issue_created: boolean;
  dispatch_status: "created" | "skipped_no_token" | "failed_non_blocking";
  issue_number: number | null;
  issue_url: string | null;
  error?: string;
}

export interface AiComplianceDeps {
  createGitHubIssue?: (params: {
    providerName: string;
    providerKey: string;
    modelId: string;
    termsUrl: string;
    notes: string;
  }) => Promise<GitHubIssueCreateResult>;
  envGetter?: (key: string) => string | undefined;
  nowIso?: () => string;
}

export interface FormattedComplianceRecord {
  id: string;
  provider_key: string;
  model_id: string;
  provider_name: string;
  terms_url: string;
  review_notes: string;
  status: ComplianceStatus;
  status_label: string;
  checklist: ComplianceChecklist;
  checklist_completed_count: number;
  human_approved_by: string | null;
  approved_at: string | null;
  approval_note: string;
  github_issue_number: number | null;
  github_issue_url: string | null;
  issue_dispatch_status: string;
  invoke_allowed: boolean;
  invoke_guard_code: string;
  created_at: string;
  updated_at: string;
}

export interface ComplianceSummary {
  total: number;
  unverified: number;
  in_review: number;
  approved: number;
}

function asHubTable(admin: AiComplianceDb): HubQuery<unknown> {
  return admin.from("hub_data") as HubQuery<unknown>;
}

function sanitizeHttpUrl(raw: unknown): string {
  if (typeof raw !== "string") return "";
  const trimmed = raw.trim().slice(0, 500);
  if (!trimmed) return "";
  try {
    const parsed = new URL(trimmed);
    if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
      return "";
    }
    return parsed.toString();
  } catch {
    return "";
  }
}

function countCompletedChecklist(c: ComplianceChecklist): number {
  let count = 0;
  if (c.terms_reviewed) count += 1;
  if (c.data_retention_checked) count += 1;
  if (c.pii_leakage_checked) count += 1;
  if (c.security_controls_verified) count += 1;
  return count;
}

function formatRow(row: HubDataRow): FormattedComplianceRecord {
  const meta = (row.metadata ?? {}) as Record<string, unknown>;
  const status = normalizeComplianceStatus(meta.status);
  const checklist = buildComplianceChecklist(meta.checklist);
  const approver = typeof meta.human_approved_by === "string" &&
      meta.human_approved_by.trim()
    ? meta.human_approved_by.trim()
    : null;
  const guard = canInvokeProvider({
    provider_key: String(meta.provider_key ?? ""),
    model_id: String(meta.model_id ?? ""),
    status,
    checklist,
    human_approved_by: approver,
  });

  const issueNum = typeof meta.github_issue_number === "number" &&
      Number.isInteger(meta.github_issue_number)
    ? meta.github_issue_number
    : null;

  return {
    id: row.id,
    provider_key: String(meta.provider_key ?? ""),
    model_id: String(meta.model_id ?? ""),
    provider_name: String(meta.provider_name ?? ""),
    terms_url: String(meta.terms_url ?? ""),
    review_notes: String(meta.review_notes ?? ""),
    status,
    status_label: COMPLIANCE_STATUS_LABELS[status],
    checklist,
    checklist_completed_count: countCompletedChecklist(checklist),
    human_approved_by: approver,
    approved_at: typeof meta.approved_at === "string" ? meta.approved_at : null,
    approval_note: String(meta.approval_note ?? ""),
    github_issue_number: issueNum,
    github_issue_url: typeof meta.github_issue_url === "string"
      ? meta.github_issue_url
      : null,
    issue_dispatch_status: String(meta.issue_dispatch_status ?? "none"),
    invoke_allowed: guard.allowed,
    invoke_guard_code: guard.code,
    created_at: row.created_at ?? "",
    updated_at: String(meta.updated_at ?? row.created_at ?? ""),
  };
}

function buildSummary(
  records: readonly FormattedComplianceRecord[],
): ComplianceSummary {
  let unverified = 0;
  let inReview = 0;
  let approved = 0;
  for (const r of records) {
    if (r.status === "approved") approved += 1;
    else if (r.status === "in_review") inReview += 1;
    else unverified += 1;
  }
  return {
    total: records.length,
    unverified,
    in_review: inReview,
    approved,
  };
}

async function fetchUserRecords(
  admin: AiComplianceDb,
  userId: string,
  limit = DEFAULT_LIMIT,
): Promise<FormattedComplianceRecord[]> {
  const safeLimit = Math.min(100, Math.max(1, Math.floor(limit)));
  const { data, error } = await asHubTable(admin)
    .select("id, metadata, created_at")
    .eq("source", AI_COMPLIANCE_SOURCE)
    .filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false })
    .limit(safeLimit);
  if (error) {
    throw new AiComplianceError(
      error.message ?? "Failed to load compliance records",
      500,
    );
  }
  const rows = (Array.isArray(data) ? data : []) as HubDataRow[];
  return rows.map(formatRow);
}

async function fetchOwnedRow(
  admin: AiComplianceDb,
  userId: string,
  id: string,
): Promise<HubDataRow | null> {
  const { data, error } = await asHubTable(admin)
    .select("id, metadata, created_at")
    .eq("id", id)
    .eq("source", AI_COMPLIANCE_SOURCE)
    .filter("metadata->>user_id", "eq", userId)
    .maybeSingle();
  if (error) {
    throw new AiComplianceError(
      error.message ?? "Failed to fetch compliance record",
      500,
    );
  }
  return data as HubDataRow | null;
}

function defaultEnvGetter(key: string): string | undefined {
  return Deno.env.get(key);
}

async function defaultCreateGitHubIssue(
  params: {
    providerName: string;
    providerKey: string;
    modelId: string;
    termsUrl: string;
    notes: string;
  },
  envGetter: (key: string) => string | undefined,
): Promise<GitHubIssueCreateResult> {
  const authVal = (
    envGetter("GITHUB_PAT") ??
      envGetter("GITHUB_TOKEN") ??
      envGetter("GH_TOKEN") ??
      ""
  ).trim();
  if (!authVal) {
    return {
      issue_created: false,
      dispatch_status: "skipped_no_token",
      issue_number: null,
      issue_url: null,
    };
  }
  const repoRaw = (envGetter("GITHUB_REPOSITORY") ?? DEFAULT_REPO_SLUG).trim();
  const repo = /^[\w.-]+\/[\w.-]+$/.test(repoRaw)
    ? repoRaw
    : DEFAULT_REPO_SLUG;

  const title =
    `[Compliance] ${params.providerName} (${params.modelId}) 法務・セキュリティ確認`;
  const body = [
    "## 新規AIモデル導入 コンプライアンス・セキュリティ確認タスク",
    "",
    `- **プロバイダー**: ${params.providerName} (\`${params.providerKey}\`)`,
    `- **モデルID**: \`${params.modelId}\``,
    `- **利用規約URL**: ${params.termsUrl || "未入力（担当者確認要）"}`,
    `- **備考**: ${params.notes || "なし"}`,
    "",
    "### 人間による必須確認項目",
    "- [ ] 利用規約・商用条件・学習データ権利の確認",
    "- [ ] データ保持期間・学習オプトアウト設定の確認",
    "- [ ] PII・機密情報漏洩リスク対策の確認",
    "- [ ] セキュリティ統制（通信暗号化・監査ログ）の確認",
    "",
    "> システムによる自動承認は行いません。4項目確認後に管理UIから手動承認してください。",
  ].join("\n");

  try {
    const resp = await fetch(`https://api.github.com/repos/${repo}/issues`, {
      method: "POST",
      headers: {
        Accept: "application/vnd.github+json",
        Authorization: `Bearer ${authVal}`,
        "Content-Type": "application/json",
        "User-Agent": "my-web-app-ai-compliance",
      },
      body: JSON.stringify({
        title,
        body,
        labels: ["security", "compliance"],
      }),
    });
    if (!resp.ok) {
      return {
        issue_created: false,
        dispatch_status: "failed_non_blocking",
        issue_number: null,
        issue_url: null,
        error: `HTTP ${resp.status}`,
      };
    }
    const created = (await resp.json()) as Record<string, unknown>;
    const issueNum = typeof created.number === "number" ? created.number : null;
    const issueUrl = typeof created.html_url === "string"
      ? created.html_url
      : null;
    return {
      issue_created: Boolean(issueUrl || issueNum),
      dispatch_status: "created",
      issue_number: issueNum,
      issue_url: issueUrl,
    };
  } catch (err) {
    return {
      issue_created: false,
      dispatch_status: "failed_non_blocking",
      issue_number: null,
      issue_url: null,
      error: err instanceof Error ? err.message : String(err),
    };
  }
}

export async function handleAiComplianceAction(params: {
  action: string;
  admin: AiComplianceDb;
  body: Record<string, unknown>;
  userId: string;
  deps?: AiComplianceDeps;
}): Promise<Record<string, unknown>> {
  const { action, admin, body, userId, deps } = params;
  if (!userId) {
    throw new AiComplianceError("Unauthorized", 401);
  }
  const nowIso = deps?.nowIso ? deps.nowIso() : new Date().toISOString();
  const envGetter = deps?.envGetter ?? defaultEnvGetter;

  switch (action) {
    case "ai_compliance.list": {
      const limit = Number(body.limit ?? DEFAULT_LIMIT);
      const all = await fetchUserRecords(
        admin,
        userId,
        Number.isFinite(limit) ? limit : DEFAULT_LIMIT,
      );
      const statusFilter = typeof body.status === "string"
        ? body.status.trim()
        : "";
      const query = typeof body.query === "string"
        ? body.query.trim().toLowerCase()
        : "";

      const filtered = all.filter((rec) => {
        if (
          statusFilter &&
          statusFilter !== "all" &&
          (COMPLIANCE_STATUSES as readonly string[]).includes(statusFilter) &&
          rec.status !== statusFilter
        ) {
          return false;
        }
        if (query) {
          const hay = [
            rec.provider_name,
            rec.provider_key,
            rec.model_id,
            rec.review_notes,
          ].join(" ").toLowerCase();
          if (!hay.includes(query)) return false;
        }
        return true;
      });

      return {
        records: filtered,
        summary: buildSummary(all),
      };
    }

    case "ai_compliance.seed_defaults": {
      const existing = await fetchUserRecords(admin, userId, 100);
      if (existing.length > 0) {
        return {
          already_seeded: true,
          seeded_count: 0,
          records: existing,
          summary: buildSummary(existing),
        };
      }

      const starters = [
        {
          provider_key: "candidate-frontier-2026q2",
          model_id: "frontier-reasoner-preview",
          provider_name: "新規評価候補A (Q2新興LLM)",
          terms_url: "",
          review_notes: "規約確認前の未検証候補。承認済になるまで呼出遮断。",
          status: "unverified",
          checklist: buildComplianceChecklist({}),
        },
        {
          provider_key: "candidate-openweight-host",
          model_id: "openweight-70b-hosted",
          provider_name: "新規評価候補B (外部推論ホスト)",
          terms_url: "",
          review_notes: "データ保持期間・PII漏洩対策チェック待ち。",
          status: "in_review",
          checklist: buildComplianceChecklist({
            terms_reviewed: true,
            data_retention_checked: false,
            pii_leakage_checked: false,
            security_controls_verified: false,
          }),
        },
      ];

      for (const item of starters) {
        const { error } = await asHubTable(admin)
          .insert({
            source: AI_COMPLIANCE_SOURCE,
            metadata: {
              ...item,
              human_approved_by: null,
              approved_at: null,
              approval_note: "",
              github_issue_number: null,
              github_issue_url: null,
              issue_dispatch_status: "none",
              user_id: userId,
              updated_at: nowIso,
            },
          })
          .select("id, metadata, created_at")
          .single();
        if (error) {
          throw new AiComplianceError(
            error.message ?? "Failed to seed compliance candidates",
            500,
          );
        }
      }

      const all = await fetchUserRecords(admin, userId, 100);
      return {
        already_seeded: false,
        seeded_count: starters.length,
        records: all,
        summary: buildSummary(all),
      };
    }

    case "ai_compliance.submit_review": {
      const providerKey = typeof body.provider_key === "string"
        ? body.provider_key.trim().slice(0, 80)
        : "";
      const modelId = typeof body.model_id === "string"
        ? body.model_id.trim().slice(0, 120)
        : "";
      const providerName = typeof body.provider_name === "string"
        ? body.provider_name.trim().slice(0, 120)
        : providerKey;
      if (!providerKey || !modelId) {
        throw new AiComplianceError("provider_key and model_id are required");
      }
      const rawTermsUrl = typeof body.terms_url === "string"
        ? body.terms_url.trim()
        : "";
      const termsUrl = rawTermsUrl ? sanitizeHttpUrl(rawTermsUrl) : "";
      if (rawTermsUrl && !termsUrl) {
        throw new AiComplianceError("terms_url must be a valid HTTP/HTTPS URL");
      }
      const notes = typeof body.review_notes === "string"
        ? body.review_notes.trim().slice(0, 500)
        : "";
      const checklist = buildComplianceChecklist(body.checklist);

      const issueCreator = deps?.createGitHubIssue ??
        ((p) => defaultCreateGitHubIssue(p, envGetter));
      const issueRes = await issueCreator({
        providerName: providerName || providerKey,
        providerKey,
        modelId,
        termsUrl,
        notes,
      });

      // Always enter in "in_review" (never auto-approve) with cleared approver.
      const meta: Record<string, unknown> = {
        provider_key: providerKey,
        model_id: modelId,
        provider_name: providerName || providerKey,
        terms_url: termsUrl,
        review_notes: notes,
        status: "in_review",
        checklist,
        human_approved_by: null,
        approved_at: null,
        approval_note: "",
        github_issue_number: issueRes.issue_number,
        github_issue_url: issueRes.issue_url,
        issue_dispatch_status: issueRes.dispatch_status,
        user_id: userId,
        updated_at: nowIso,
      };

      const { data, error } = await asHubTable(admin)
        .insert({
          source: AI_COMPLIANCE_SOURCE,
          metadata: meta,
        })
        .select("id, metadata, created_at")
        .single();
      if (error || !data) {
        throw new AiComplianceError(
          error?.message ?? "Failed to submit compliance review",
          500,
        );
      }

      const all = await fetchUserRecords(admin, userId, 100);
      return {
        record: formatRow(data as HubDataRow),
        issue_dispatch: issueRes,
        records: all,
        summary: buildSummary(all),
      };
    }

    case "ai_compliance.update_checklist": {
      const id = typeof body.id === "string" ? body.id.trim() : "";
      if (!id) {
        throw new AiComplianceError("id is required");
      }
      const existing = await fetchOwnedRow(admin, userId, id);
      if (!existing) {
        throw new AiComplianceError("Compliance record not found", 404);
      }
      const prevMeta = (existing.metadata ?? {}) as Record<string, unknown>;
      const prevChecklist = buildComplianceChecklist(prevMeta.checklist);
      const rawPatch =
        typeof body.checklist === "object" && body.checklist !== null
          ? (body.checklist as Record<string, unknown>)
          : body;

      const nextChecklist: ComplianceChecklist = {
        terms_reviewed: "terms_reviewed" in rawPatch
          ? rawPatch.terms_reviewed === true
          : prevChecklist.terms_reviewed,
        data_retention_checked: "data_retention_checked" in rawPatch
          ? rawPatch.data_retention_checked === true
          : prevChecklist.data_retention_checked,
        pii_leakage_checked: "pii_leakage_checked" in rawPatch
          ? rawPatch.pii_leakage_checked === true
          : prevChecklist.pii_leakage_checked,
        security_controls_verified: "security_controls_verified" in rawPatch
          ? rawPatch.security_controls_verified === true
          : prevChecklist.security_controls_verified,
      };

      let nextTermsUrl = String(prevMeta.terms_url ?? "");
      if (typeof body.terms_url === "string") {
        const clean = body.terms_url.trim();
        if (clean) {
          const safe = sanitizeHttpUrl(clean);
          if (!safe) {
            throw new AiComplianceError(
              "terms_url must be a valid HTTP/HTTPS URL",
            );
          }
          nextTermsUrl = safe;
        } else {
          nextTermsUrl = "";
        }
      }

      const prevStatus = normalizeComplianceStatus(prevMeta.status);
      // Never auto-promote to approved; revoke approval if checks drop.
      let nextStatus: ComplianceStatus = prevStatus;
      let nextApprover = prevMeta.human_approved_by ?? null;
      let nextApprovedAt = prevMeta.approved_at ?? null;
      if (
        prevStatus === "unverified" &&
        countCompletedChecklist(nextChecklist) > 0
      ) {
        nextStatus = "in_review";
      }
      if (
        prevStatus === "approved" &&
        !areAllChecklistItemsComplete(nextChecklist)
      ) {
        nextStatus = "in_review";
        nextApprover = null;
        nextApprovedAt = null;
      }

      const nextMeta: Record<string, unknown> = {
        ...prevMeta,
        terms_url: nextTermsUrl,
        review_notes: typeof body.review_notes === "string"
          ? body.review_notes.trim().slice(0, 500)
          : String(prevMeta.review_notes ?? ""),
        checklist: nextChecklist,
        status: nextStatus,
        human_approved_by: nextApprover,
        approved_at: nextApprovedAt,
        updated_at: nowIso,
        user_id: userId,
      };

      const { data: updated, error } = await asHubTable(admin)
        .update({ metadata: nextMeta })
        .eq("id", id)
        .eq("source", AI_COMPLIANCE_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .select("id, metadata, created_at")
        .maybeSingle();
      if (error || !updated) {
        throw new AiComplianceError(
          error?.message ?? "Failed to update compliance checklist",
          500,
        );
      }

      const all = await fetchUserRecords(admin, userId, 100);
      return {
        record: formatRow(updated as HubDataRow),
        records: all,
        summary: buildSummary(all),
      };
    }

    case "ai_compliance.approve": {
      const id = typeof body.id === "string" ? body.id.trim() : "";
      if (!id) {
        throw new AiComplianceError("id is required");
      }
      const existing = await fetchOwnedRow(admin, userId, id);
      if (!existing) {
        throw new AiComplianceError("Compliance record not found", 404);
      }
      const prevMeta = (existing.metadata ?? {}) as Record<string, unknown>;
      const mergedChecklist = body.checklist
        ? buildComplianceChecklist(body.checklist)
        : buildComplianceChecklist(prevMeta.checklist);
      const reviewerName = typeof body.reviewer_name === "string"
        ? body.reviewer_name.trim().slice(0, 120)
        : "";
      const humanConfirmed = body.human_confirmed === true;

      const eligible = isChecklistApproveEligible({
        checklist: mergedChecklist,
        reviewerName,
        humanConfirmed,
      });
      if (!eligible.ok) {
        throw new AiComplianceError(
          eligible.reason ?? "Compliance approval preconditions not met",
          400,
        );
      }

      const nextMeta: Record<string, unknown> = {
        ...prevMeta,
        checklist: mergedChecklist,
        status: "approved",
        human_confirmed: true,
        human_approved_by: reviewerName,
        approved_at: nowIso,
        approval_note: typeof body.approval_note === "string"
          ? body.approval_note.trim().slice(0, 500)
          : "",
        updated_at: nowIso,
        user_id: userId,
      };

      const { data: updated, error } = await asHubTable(admin)
        .update({ metadata: nextMeta })
        .eq("id", id)
        .eq("source", AI_COMPLIANCE_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .select("id, metadata, created_at")
        .maybeSingle();
      if (error || !updated) {
        throw new AiComplianceError(
          error?.message ?? "Failed to approve compliance record",
          500,
        );
      }

      const all = await fetchUserRecords(admin, userId, 100);
      return {
        record: formatRow(updated as HubDataRow),
        records: all,
        summary: buildSummary(all),
      };
    }

    case "ai_compliance.check_invoke_guard": {
      const id = typeof body.id === "string" ? body.id.trim() : "";
      const providerKey = typeof body.provider_key === "string"
        ? body.provider_key.trim()
        : "";
      const modelId = typeof body.model_id === "string"
        ? body.model_id.trim()
        : "";

      let target: FormattedComplianceRecord | undefined;
      if (id) {
        const row = await fetchOwnedRow(admin, userId, id);
        if (row) target = formatRow(row);
      } else {
        const all = await fetchUserRecords(admin, userId, 100);
        target = all.find((r) =>
          (providerKey && r.provider_key === providerKey) &&
          (!modelId || r.model_id === modelId)
        );
      }

      const guard = canInvokeProvider(target);
      if (body.enforce === true && !guard.allowed) {
        throw new AiComplianceError(guard.reason, 403, {
          code: guard.code,
          allowed: false,
          status: guard.status,
        });
      }
      return {
        ...guard,
        record: target ?? null,
      };
    }

    default:
      throw new AiComplianceError(`Unsupported action: ${action}`, 400);
  }
}
