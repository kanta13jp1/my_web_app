// autonomous-ops
//
// OMOCHA WORKS「自律オペレーションコンソール」向けの read-only データ EF。
// GitHub Actions の workflow run 一覧を取得し、4 列カンバン / 活動ログ /
// KPI / スループットの表示スナップショットへ変換して返す。
//
// セキュリティ:
//   - ブラウザ配信のため `--no-verify-jwt` でデプロイし、認証は本体で実施。
//   - **ログイン済みかつ user_profiles.is_admin=true のオーナーのみ許可**。
//     未認証 / 非オーナーは 401/403 を返し、クライアントはシミュレーション
//     表示にフォールバックする (公開訪問者に run 情報を出さない)。
//   - GitHub トークンは Function Secret (GH_ACTIONS_READ_TOKEN) からサーバ側
//     でのみ使用し、レスポンスには一切含めない。
//
// キャッシュ: GitHub 応答を ~30 秒メモリキャッシュし、レート/コストを抑える
// (クライアントは ~20 秒間隔でポーリングする想定)。

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse, requireEnv } from "../_shared/edge.ts";
import {
  externalFetch,
  isExternalFetchError,
} from "../_shared/external_fetch.ts";
import {
  buildSnapshot,
  type GitHubRun,
  type OpsSnapshot,
} from "./transform.ts";

const DEFAULT_REPO = "kanta13jp1/my_web_app";
const CACHE_TTL_MS = 30_000;
const RUNS_PER_PAGE = 50;

interface CacheEntry {
  at: number;
  repo: string;
  snapshot: OpsSnapshot;
}

// ウォームインスタンス内で共有されるメモリキャッシュ。
let cache: CacheEntry | null = null;

function emptySnapshot(repo: string): OpsSnapshot {
  return {
    generatedAt: new Date().toISOString(),
    repo,
    live: false,
    tasks: [],
    activities: [],
    kpis: {
      completedToday: 0,
      automatedHours: 0,
      revenueImpact: 0,
      slaCompliance: 100,
      throughput: 0,
    },
    throughputHistory: [],
  };
}

async function resolveOwner(authHeader: string): Promise<string | null> {
  const url = requireEnv("SUPABASE_URL");
  const anonKey = requireEnv("SUPABASE_ANON_KEY");
  const serviceKey = requireEnv("SERVICE_ROLE_KEY");

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return null;

  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await admin
    .from("user_profiles")
    .select("is_admin")
    .eq("user_id", user.id)
    .maybeSingle();
  if (error || data?.is_admin !== true) return null;
  return user.id;
}

async function fetchRuns(repo: string, token: string): Promise<GitHubRun[]> {
  const endpoint =
    `https://api.github.com/repos/${repo}/actions/runs?per_page=${RUNS_PER_PAGE}`;
  const res = await externalFetch("github-actions", endpoint, {
    headers: {
      "Authorization": `Bearer ${token}`,
      "Accept": "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "omocha-works-autonomous-ops",
    },
  }, { retries: 2, timeoutMs: 15_000 });

  if (!res.ok) {
    throw new Error(`GitHub API responded ${res.status}`);
  }
  const body = await res.json();
  const runs = Array.isArray(body?.workflow_runs) ? body.workflow_runs : [];
  return runs as GitHubRun[];
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST" && req.method !== "GET") {
    return jsonResponse({ ok: false, error: "Method not allowed." }, 405);
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (authHeader === "") {
      return jsonResponse({ ok: false, error: "Unauthorized." }, 401);
    }

    const ownerId = await resolveOwner(authHeader);
    if (ownerId === null) {
      // 未認証 or 非オーナー: 実データは出さない。
      return jsonResponse({ ok: false, error: "Forbidden." }, 403);
    }

    const repo = (Deno.env.get("GITHUB_REPO") ?? DEFAULT_REPO).trim() ||
      DEFAULT_REPO;
    const token = (Deno.env.get("GH_ACTIONS_READ_TOKEN") ??
      Deno.env.get("GITHUB_PAT") ?? "").trim();

    // トークン未設定: オーナーだが未構成。空スナップショットでシミュレーション継続。
    if (token === "") {
      return jsonResponse({
        ok: true,
        configured: false,
        snapshot: emptySnapshot(repo),
      });
    }

    // キャッシュヒット判定。
    const now = Date.now();
    if (cache && cache.repo === repo && now - cache.at < CACHE_TTL_MS) {
      return jsonResponse({
        ok: true,
        configured: true,
        cached: true,
        snapshot: cache.snapshot,
      });
    }

    const runs = await fetchRuns(repo, token);
    const snapshot = buildSnapshot(runs, repo, Date.now());
    cache = { at: Date.now(), repo, snapshot };

    return jsonResponse({ ok: true, configured: true, snapshot });
  } catch (error) {
    // GitHub 側の一時障害はフォールバック可能な形で返す。
    if (isExternalFetchError(error)) {
      return jsonResponse({
        ok: false,
        temporary: true,
        error: error.userMessage,
      }, 502);
    }
    const message = error instanceof Error ? error.message : "Unexpected error.";
    return jsonResponse({ ok: false, error: message }, 500);
  }
});
