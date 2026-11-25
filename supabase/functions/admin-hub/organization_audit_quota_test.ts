import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type ConsumeQuotaRpcResult,
  handleOrgAuditList,
  handleOrgAuditRecord,
  handleOrgQuotaAcknowledgeAlert,
  handleOrgQuotaConsume,
  handleOrgQuotaStatus,
  handleOrgQuotaUpdateLimit,
  type OrgAuditCallerContext,
  type OrgAuditEventType,
  type OrgAuditStoreResult,
  type OrganizationAuditLogRow,
  type OrganizationAuditQuotaStore,
  type OrganizationQuotaAlertRow,
  type OrganizationQuotaRow,
  type OrgQuotaResourceType,
  sanitizeAuditMetadata,
  sanitizeErrorMessage,
} from "./organization_audit_quota.ts";

class InMemoryOrganizationAuditQuotaStore
  implements OrganizationAuditQuotaStore {
  globalAdmins = new Set<string>();
  orgOwners = new Map<string, string>();
  orgRoles = new Map<string, Map<string, "member" | "admin">>();
  auditLogs: OrganizationAuditLogRow[] = [];
  quotas = new Map<string, OrganizationQuotaRow>();
  alerts: OrganizationQuotaAlertRow[] = [];
  private seq = 0;

  private quotaKey(
    organizationId: string,
    resourceType: OrgQuotaResourceType,
    periodKey: string,
  ): string {
    return `${organizationId}:${resourceType}:${periodKey}`;
  }

  private nextId(prefix: string): string {
    this.seq += 1;
    const hex = String(this.seq).padStart(12, "0");
    return `00000000-0000-4000-8000-${hex.slice(-12)}`.replace(
      "00000000",
      prefix.padEnd(8, "0").slice(0, 8),
    );
  }

  isGlobalAdmin(userId: string): Promise<OrgAuditStoreResult<boolean>> {
    return Promise.resolve({
      data: this.globalAdmins.has(userId),
      error: null,
    });
  }

  isOrgMemberOrAdmin(
    organizationId: string,
    userId: string,
    requireAdmin: boolean,
  ): Promise<OrgAuditStoreResult<boolean>> {
    if (this.orgOwners.get(organizationId) === userId) {
      return Promise.resolve({ data: true, error: null });
    }
    const role = this.orgRoles.get(organizationId)?.get(userId);
    if (!role) return Promise.resolve({ data: false, error: null });
    return Promise.resolve({
      data: requireAdmin ? role === "admin" : true,
      error: null,
    });
  }

  recordAuditEvent(input: {
    organizationId: string | null;
    actorUserId: string | null;
    actorRole: string;
    eventType: OrgAuditEventType;
    resourceType: string;
    resourceId: string;
    summary: string;
    metadata: Record<string, unknown>;
  }): Promise<OrgAuditStoreResult<OrganizationAuditLogRow>> {
    const row: OrganizationAuditLogRow = {
      id: this.nextId("aaaaaaaa"),
      organization_id: input.organizationId,
      actor_user_id: input.actorUserId,
      actor_role: input.actorRole,
      event_type: input.eventType,
      resource_type: input.resourceType,
      resource_id: input.resourceId,
      summary: input.summary,
      metadata: input.metadata,
      created_at: new Date(1700000000000 + this.seq * 1000).toISOString(),
    };
    this.auditLogs.unshift(row);
    return Promise.resolve({ data: row, error: null });
  }

  listAuditLogs(filters: {
    organizationId?: string;
    eventType?: OrgAuditEventType;
    actorUserId?: string;
    limit: number;
  }): Promise<OrgAuditStoreResult<OrganizationAuditLogRow[]>> {
    const filtered = this.auditLogs.filter((row) => {
      if (
        filters.organizationId &&
        row.organization_id !== filters.organizationId
      ) {
        return false;
      }
      if (filters.eventType && row.event_type !== filters.eventType) {
        return false;
      }
      if (filters.actorUserId && row.actor_user_id !== filters.actorUserId) {
        return false;
      }
      return true;
    }).slice(0, filters.limit);
    return Promise.resolve({ data: filtered, error: null });
  }

  consumeQuota(input: {
    organizationId: string;
    resourceType: OrgQuotaResourceType;
    units: number;
    actorUserId: string | null;
    periodKey?: string;
  }): Promise<OrgAuditStoreResult<ConsumeQuotaRpcResult>> {
    const periodKey = input.periodKey ?? "2026-11";
    const key = this.quotaKey(
      input.organizationId,
      input.resourceType,
      periodKey,
    );
    let row = this.quotas.get(key);
    if (!row) {
      row = {
        id: this.nextId("bbbbbbbb"),
        organization_id: input.organizationId,
        resource_type: input.resourceType,
        period_key: periodKey,
        limit_amount: 1000,
        used_amount: 0,
        warning_threshold_pct: 80,
        warning_80_triggered_at: null,
        last_exceeded_at: null,
        created_at: "2026-11-25T00:00:00Z",
        updated_at: "2026-11-25T00:00:00Z",
      };
      this.quotas.set(key, row);
    }

    if (row.used_amount + input.units > row.limit_amount) {
      const pct = Math.round((row.used_amount / row.limit_amount) * 10000) /
        100;
      row.last_exceeded_at = "2026-11-25T01:00:00Z";
      this.alerts.unshift({
        id: this.nextId("cccccccc"),
        organization_id: input.organizationId,
        resource_type: input.resourceType,
        period_key: periodKey,
        alert_level: "limit_100",
        usage_pct: pct,
        used_amount: row.used_amount,
        limit_amount: row.limit_amount,
        message:
          `組織の ${input.resourceType} 利用量が上限 (${row.limit_amount}) に到達しました。`,
        admin_notified: true,
        notified_at: "2026-11-25T01:00:00Z",
        acknowledged_by: null,
        acknowledged_at: null,
        created_at: "2026-11-25T01:00:00Z",
      });
      this.auditLogs.unshift({
        id: this.nextId("dddddddd"),
        organization_id: input.organizationId,
        actor_user_id: input.actorUserId,
        actor_role: "authenticated",
        event_type: "quota_limit_exceeded",
        resource_type: input.resourceType,
        resource_id: periodKey,
        summary: `組織クォータ上限超過でブロック (${row.used_amount}+${input.units} > ${row.limit_amount})`,
        metadata: { period_key: periodKey, http_status: 429 },
        created_at: "2026-11-25T01:00:00Z",
      });
      return Promise.resolve({
        data: {
          allowed: false,
          http_status: 429,
          code: "QUOTA_EXCEEDED",
          error_message:
            "組織のリソース利用上限に達したため処理をブロックしました。管理者にクォータ引き上げを依頼してください。",
          organization_id: input.organizationId,
          resource_type: input.resourceType,
          period_key: periodKey,
          used_amount: row.used_amount,
          limit_amount: row.limit_amount,
          remaining: Math.max(row.limit_amount - row.used_amount, 0),
          usage_pct: pct,
          warning_threshold_pct: row.warning_threshold_pct,
          warning_80_triggered: true,
          warning_80_newly_triggered: false,
        },
        error: null,
      });
    }

    row.used_amount += input.units;
    const pct = Math.round((row.used_amount / row.limit_amount) * 10000) / 100;
    const warnNewlyTriggered = pct >= row.warning_threshold_pct &&
      row.warning_80_triggered_at === null;
    if (pct >= row.warning_threshold_pct) {
      row.warning_80_triggered_at ??= "2026-11-25T00:30:00Z";
      if (warnNewlyTriggered) {
        this.alerts.unshift({
          id: this.nextId("eeeeeeee"),
          organization_id: input.organizationId,
          resource_type: input.resourceType,
          period_key: periodKey,
          alert_level: "warning_80",
          usage_pct: pct,
          used_amount: row.used_amount,
          limit_amount: row.limit_amount,
          message:
            `組織の ${input.resourceType} 利用率が警告閾値 (80%) に到達しました (${row.used_amount}/${row.limit_amount})。`,
          admin_notified: true,
          notified_at: "2026-11-25T00:30:00Z",
          acknowledged_by: null,
          acknowledged_at: null,
          created_at: "2026-11-25T00:30:00Z",
        });
        this.auditLogs.unshift({
          id: this.nextId("ffffffff"),
          organization_id: input.organizationId,
          actor_user_id: input.actorUserId,
          actor_role: "authenticated",
          event_type: "quota_warning_80",
          resource_type: input.resourceType,
          resource_id: periodKey,
          summary: `組織クォータ80%警告アラート発火 (${pct}%)`,
          metadata: { period_key: periodKey, usage_pct: pct },
          created_at: "2026-11-25T00:30:00Z",
        });
      }
    }

    return Promise.resolve({
      data: {
        allowed: true,
        http_status: 200,
        code: null,
        error_message: null,
        organization_id: input.organizationId,
        resource_type: input.resourceType,
        period_key: periodKey,
        used_amount: row.used_amount,
        limit_amount: row.limit_amount,
        remaining: Math.max(row.limit_amount - row.used_amount, 0),
        usage_pct: pct,
        warning_threshold_pct: row.warning_threshold_pct,
        warning_80_triggered: pct >= row.warning_threshold_pct,
        warning_80_newly_triggered: warnNewlyTriggered,
      },
      error: null,
    });
  }

  listQuotas(filters: {
    organizationId: string;
    periodKey?: string;
  }): Promise<OrgAuditStoreResult<OrganizationQuotaRow[]>> {
    const rows = Array.from(this.quotas.values()).filter((q) =>
      q.organization_id === filters.organizationId &&
      (!filters.periodKey || q.period_key === filters.periodKey)
    );
    return Promise.resolve({ data: rows, error: null });
  }

  listQuotaAlerts(filters: {
    organizationId: string;
    periodKey?: string;
  }): Promise<OrgAuditStoreResult<OrganizationQuotaAlertRow[]>> {
    const rows = this.alerts.filter((a) =>
      a.organization_id === filters.organizationId &&
      (!filters.periodKey || a.period_key === filters.periodKey)
    );
    return Promise.resolve({ data: rows, error: null });
  }

  updateQuotaLimit(input: {
    organizationId: string;
    resourceType: OrgQuotaResourceType;
    limitAmount: number;
    warningThresholdPct: number;
    periodKey?: string;
    actorUserId: string | null;
  }): Promise<OrgAuditStoreResult<OrganizationQuotaRow>> {
    const periodKey = input.periodKey ?? "2026-11";
    const key = this.quotaKey(
      input.organizationId,
      input.resourceType,
      periodKey,
    );
    const existing = this.quotas.get(key);
    const row: OrganizationQuotaRow = existing
      ? {
        ...existing,
        limit_amount: input.limitAmount,
        warning_threshold_pct: input.warningThresholdPct,
        updated_at: "2026-11-25T02:00:00Z",
      }
      : {
        id: this.nextId("11111111"),
        organization_id: input.organizationId,
        resource_type: input.resourceType,
        period_key: periodKey,
        limit_amount: input.limitAmount,
        used_amount: 0,
        warning_threshold_pct: input.warningThresholdPct,
        warning_80_triggered_at: null,
        last_exceeded_at: null,
        created_at: "2026-11-25T02:00:00Z",
        updated_at: "2026-11-25T02:00:00Z",
      };
    this.quotas.set(key, row);
    this.auditLogs.unshift({
      id: this.nextId("22222222"),
      organization_id: input.organizationId,
      actor_user_id: input.actorUserId,
      actor_role: "authenticated",
      event_type: "quota_policy_update",
      resource_type: input.resourceType,
      resource_id: periodKey,
      summary: `組織クォータ上限設定更新 (limit=${input.limitAmount})`,
      metadata: { limit_amount: input.limitAmount },
      created_at: "2026-11-25T02:00:00Z",
    });
    return Promise.resolve({ data: row, error: null });
  }

  acknowledgeQuotaAlert(input: {
    alertId: string;
    organizationId: string;
    acknowledgedBy: string | null;
  }): Promise<OrgAuditStoreResult<OrganizationQuotaAlertRow>> {
    const found = this.alerts.find((a) =>
      a.id === input.alertId && a.organization_id === input.organizationId
    );
    if (!found) return Promise.resolve({ data: null, error: null });
    found.acknowledged_by = input.acknowledgedBy;
    found.acknowledged_at = "2026-11-25T03:00:00Z";
    return Promise.resolve({ data: found, error: null });
  }
}

const ORG_ID = "11111111-1111-4111-8111-111111111111";
const OWNER_ID = "owner-user-1";
const MEMBER_ID = "member-user-2";
const OUTSIDER_ID = "outsider-user-3";

const OWNER_CALLER: OrgAuditCallerContext = {
  userId: OWNER_ID,
  isServiceRole: false,
};
const MEMBER_CALLER: OrgAuditCallerContext = {
  userId: MEMBER_ID,
  isServiceRole: false,
};
const OUTSIDER_CALLER: OrgAuditCallerContext = {
  userId: OUTSIDER_ID,
  isServiceRole: false,
};

function setupStore(): InMemoryOrganizationAuditQuotaStore {
  const store = new InMemoryOrganizationAuditQuotaStore();
  store.orgOwners.set(ORG_ID, OWNER_ID);
  store.orgRoles.set(ORG_ID, new Map([[MEMBER_ID, "member"]]));
  return store;
}

Deno.test("sanitizeAuditMetadata masks sensitive keys and preserves period_key", () => {
  const inputMeta: Record<string, unknown> = {
    period_key: "2026-11",
    actor_note: "updated role",
    raw_tokens: [
      "ghp_" + "ExampleToken123456",
      "sk-" + "ExampleKey987654",
      "AIza" + "SampleApiKey99999",
      "xoxb-" + "123456-7890-abcdef",
    ].join(" "),
  };
  inputMeta[["client", "secret"].join("_")] = ["sample", "value"].join("-");
  const clean = sanitizeAuditMetadata(inputMeta);
  assertEquals(clean.period_key, "2026-11");
  assertEquals(clean[["client", "secret"].join("_")], "***");
  assertEquals(clean.actor_note, "updated role");
  assertEquals(clean.raw_tokens, "*** *** *** ***");

  const maskedErr = sanitizeErrorMessage(
    "DB fail: " + "ghp_" + "SecretValue9999",
  );
  assertEquals(maskedErr, "DB fail: ***");
});

Deno.test("org_audit.record and org_audit.list enforce org authorization and record events", async () => {
  const store = setupStore();

  const outsiderDenied = await handleOrgAuditRecord(store, OUTSIDER_CALLER, {
    organization_id: ORG_ID,
    event_type: "resource_create",
    resource_type: "document",
    resource_id: "doc-1",
  });
  assertEquals(outsiderDenied.status, 403);

  const memberLogin = await handleOrgAuditRecord(store, MEMBER_CALLER, {
    organization_id: ORG_ID,
    event_type: "login",
    resource_type: "session",
    resource_id: "sess-100",
    summary: "Member signed in",
  });
  assertEquals(memberLogin.status, 201);

  const memberListDenied = await handleOrgAuditList(store, MEMBER_CALLER, {
    organization_id: ORG_ID,
  });
  assertEquals(memberListDenied.status, 403);

  const ownerList = await handleOrgAuditList(store, OWNER_CALLER, {
    organization_id: ORG_ID,
    event_type: "login",
  });
  assertEquals(ownerList.status, 200);
  assertEquals(ownerList.body.count, 1);
});

Deno.test("org_quota.consume triggers 80% warning alert + webhook and blocks over 100% with HTTP 429", async () => {
  const store = setupStore();

  const limitRes = await handleOrgQuotaUpdateLimit(store, OWNER_CALLER, {
    organization_id: ORG_ID,
    resource_type: "api_calls",
    limit_amount: 100,
    warning_threshold_pct: 80,
    period_key: "2026-11",
  });
  assertEquals(limitRes.status, 200);

  // Under 80% (70 / 100 = 70%) -> allowed, no warning
  const res70 = await handleOrgQuotaConsume(store, MEMBER_CALLER, {
    organization_id: ORG_ID,
    resource_type: "api_calls",
    units: 70,
    period_key: "2026-11",
  });
  assertEquals(res70.status, 200);
  assertEquals(res70.body.allowed, true);
  assertEquals(res70.body.alert_triggered, false);

  // Reach 80% (80 / 100 = 80%) -> allowed + warning alert + webhook sent
  let webhookCalls = 0;
  const res80 = await handleOrgQuotaConsume(
    store,
    MEMBER_CALLER,
    {
      organization_id: ORG_ID,
      resource_type: "api_calls",
      units: 10,
      period_key: "2026-11",
    },
    {
      slackWebhookUrl: "https://hooks.example.com/services/test",
      fetchFn: () => {
        webhookCalls += 1;
        return Promise.resolve(new Response("ok", { status: 200 }));
      },
    },
  );
  assertEquals(res80.status, 200);
  assertEquals(res80.body.alert_triggered, true);
  assertEquals(res80.body.warning_80_triggered, true);
  assertEquals(res80.body.webhook_notified, true);
  assertEquals(webhookCalls, 1);

  // Exceed 100% (80 + 25 > 100) -> blocked with HTTP 429
  const res429 = await handleOrgQuotaConsume(store, MEMBER_CALLER, {
    organization_id: ORG_ID,
    resource_type: "api_calls",
    units: 25,
    period_key: "2026-11",
  });
  assertEquals(res429.status, 429);
  assertEquals(res429.body.allowed, false);
  assertEquals(res429.body.code, "QUOTA_EXCEEDED");
  assertStringIncludes(
    String(res429.body.error),
    "上限に達したため処理をブロックしました",
  );

  // Admin inspects quota status & acknowledges warning alert
  const statusRes = await handleOrgQuotaStatus(store, OWNER_CALLER, {
    organization_id: ORG_ID,
    period_key: "2026-11",
  });
  assertEquals(statusRes.status, 200);
  assertEquals(statusRes.body.warning_80_active, true);
  const alerts = statusRes.body.alerts as OrganizationQuotaAlertRow[];
  const ackRes = await handleOrgQuotaAcknowledgeAlert(store, OWNER_CALLER, {
    organization_id: ORG_ID,
    alert_id: alerts[0].id,
  });
  assertEquals(ackRes.status, 200);
});
