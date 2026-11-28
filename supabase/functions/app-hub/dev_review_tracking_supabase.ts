import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  type DevReviewChecklistItem,
  type DevReviewGithubSnapshot,
  type DevReviewPhase,
  type DevReviewPhaseHistory,
  type DevReviewSession,
  type DevReviewStore,
} from "./dev_review_tracking.ts";

const SOURCE_DEV_REVIEW_SESSION = "dev_review_session";

function asMeta(raw: unknown): Record<string, unknown> {
  if (raw !== null && typeof raw === "object" && !Array.isArray(raw)) {
    return raw as Record<string, unknown>;
  }
  return {};
}

function mapSessionRow(row: {
  id: string;
  metadata: unknown;
  created_at: string;
}): DevReviewSession {
  const meta = asMeta(row.metadata);
  const rawItems = Array.isArray(meta.items) ? meta.items : [];
  const items: DevReviewChecklistItem[] = rawItems.map((item) => {
    const r = asMeta(item);
    return {
      id: String(r.id ?? ""),
      kind: (r.kind as DevReviewChecklistItem["kind"]) ?? "checklist",
      title: String(r.title ?? ""),
      category: String(r.category ?? ""),
      status: (r.status as DevReviewChecklistItem["status"]) ?? "pending",
      assignee: String(r.assignee ?? "unassigned"),
      note: String(r.note ?? ""),
      updatedAt: String(r.updatedAt ?? ""),
    };
  });
  const rawHistory = Array.isArray(meta.phase_history)
    ? meta.phase_history
    : [];
  const phaseHistory: DevReviewPhaseHistory[] = rawHistory.map((h) => {
    const r = asMeta(h);
    return {
      fromPhase: (r.fromPhase as DevReviewPhase) ?? "intake",
      toPhase: (r.toPhase as DevReviewPhase) ?? "design",
      actorUserId: String(r.actorUserId ?? ""),
      decidedAt: String(r.decidedAt ?? ""),
      note: String(r.note ?? ""),
    };
  });
  const rawSnap = meta.github_snapshot
    ? asMeta(meta.github_snapshot)
    : null;
  const githubSnapshot: DevReviewGithubSnapshot | null = rawSnap
    ? {
      provider: "github",
      repo: String(rawSnap.repo ?? ""),
      targetType: rawSnap.targetType === "pr" ? "pr" : "issue",
      number: Number(rawSnap.number ?? 0),
      url: String(rawSnap.url ?? ""),
      state: (rawSnap.state as DevReviewGithubSnapshot["state"]) ?? "open",
      reviewDecision:
        (rawSnap.reviewDecision as DevReviewGithubSnapshot["reviewDecision"]) ??
          "none",
      syncedAt: String(rawSnap.syncedAt ?? ""),
    }
    : null;

  return {
    id: String(row.id),
    userId: String(meta.user_id ?? ""),
    title: String(meta.title ?? ""),
    targetType: meta.target_type === "pr" ? "pr" : "issue",
    githubRepo: String(meta.github_repo ?? ""),
    targetNumber: Number(meta.target_number ?? 0),
    currentPhase: (meta.current_phase as DevReviewPhase) ?? "intake",
    approver: String(meta.approver ?? ""),
    items,
    githubSnapshot,
    phaseHistory,
    createdAt: String(row.created_at),
    updatedAt: String(meta.updated_at ?? row.created_at),
  };
}

function serializeMetadata(session: {
  userId: string;
  title: string;
  targetType: "issue" | "pr";
  githubRepo: string;
  targetNumber: number;
  currentPhase: DevReviewPhase;
  approver: string;
  items: DevReviewChecklistItem[];
  githubSnapshot: DevReviewGithubSnapshot | null;
  phaseHistory: DevReviewPhaseHistory[];
  updatedAt: string;
}): Record<string, unknown> {
  return {
    user_id: session.userId,
    title: session.title,
    target_type: session.targetType,
    github_repo: session.githubRepo,
    target_number: session.targetNumber,
    current_phase: session.currentPhase,
    approver: session.approver,
    items: session.items,
    github_snapshot: session.githubSnapshot,
    phase_history: session.phaseHistory,
    updated_at: session.updatedAt,
  };
}

export function createSupabaseDevReviewStore(
  admin: SupabaseClient,
): DevReviewStore {
  return {
    async listSessions(userId, limit) {
      const { data, error } = await admin
        .from("hub_data")
        .select("id, metadata, created_at")
        .eq("source", SOURCE_DEV_REVIEW_SESSION)
        .filter("metadata->>user_id", "eq", userId)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (error) throw new Error(error.message);
      return (data ?? []).map(mapSessionRow);
    },

    async getSession(sessionId, userId) {
      const { data, error } = await admin
        .from("hub_data")
        .select("id, metadata, created_at")
        .eq("id", sessionId)
        .eq("source", SOURCE_DEV_REVIEW_SESSION)
        .filter("metadata->>user_id", "eq", userId)
        .maybeSingle();
      if (error) throw new Error(error.message);
      return data ? mapSessionRow(data) : null;
    },

    async findSessionsByGithubTarget(githubRepo, targetNumber) {
      const { data, error } = await admin
        .from("hub_data")
        .select("id, metadata, created_at")
        .eq("source", SOURCE_DEV_REVIEW_SESSION)
        .filter("metadata->>github_repo", "eq", githubRepo)
        .filter("metadata->>target_number", "eq", String(targetNumber))
        .limit(20);
      if (error) throw new Error(error.message);
      return (data ?? []).map(mapSessionRow);
    },

    async createSession(input) {
      const nowIso = new Date().toISOString();
      const { data, error } = await admin
        .from("hub_data")
        .insert({
          source: SOURCE_DEV_REVIEW_SESSION,
          metadata: serializeMetadata({
            userId: input.userId,
            title: input.title,
            targetType: input.targetType,
            githubRepo: input.githubRepo,
            targetNumber: input.targetNumber,
            currentPhase: input.currentPhase,
            approver: input.approver,
            items: input.items,
            githubSnapshot: input.githubSnapshot,
            phaseHistory: [],
            updatedAt: nowIso,
          }),
        })
        .select("id, metadata, created_at")
        .single();
      if (error || !data) {
        throw new Error(error?.message ?? "Failed to create review session");
      }
      return mapSessionRow(data);
    },

    async updateSession(sessionId, userId, session) {
      const { data, error } = await admin
        .from("hub_data")
        .update({
          metadata: serializeMetadata({
            userId: session.userId,
            title: session.title,
            targetType: session.targetType,
            githubRepo: session.githubRepo,
            targetNumber: session.targetNumber,
            currentPhase: session.currentPhase,
            approver: session.approver,
            items: session.items,
            githubSnapshot: session.githubSnapshot,
            phaseHistory: session.phaseHistory,
            updatedAt: session.updatedAt,
          }),
        })
        .eq("id", sessionId)
        .eq("source", SOURCE_DEV_REVIEW_SESSION)
        .filter("metadata->>user_id", "eq", userId)
        .select("id, metadata, created_at")
        .maybeSingle();
      if (error) throw new Error(error.message);
      return data ? mapSessionRow(data) : null;
    },
  };
}
