import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const GITHUB_API_BASE = "https://api.github.com";

interface GitHubConfig {
  pat: string;
  repo: string;
}

interface GitHubPR {
  number: number;
  title: string;
  state: string;
  merged_at: string | null;
  user: { login: string };
  updated_at: string;
}

interface GitHubRepo {
  stargazers_count: number;
}

interface PullRequest {
  number: number;
  title: string;
  state: "open" | "closed" | "merged";
  author: string;
  updated_at: string;
}

interface RepoStats {
  open_prs: number;
  merged_prs: number;
  stars: number;
}

async function getGitHubConfig(
  supabase: ReturnType<typeof createClient>,
  userId: string,
): Promise<GitHubConfig | null> {
  const { data } = await supabase
    .from("app_analytics")
    .select("metadata")
    .eq("source", "github_config")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(1)
    .single();

  if (!data) return null;
  const meta = data.metadata as Record<string, unknown>;
  return {
    pat: (meta.pat as string) ?? "",
    repo: (meta.repo as string) ?? "",
  };
}

async function fetchGitHubPRs(
  pat: string,
  owner: string,
  repo: string,
): Promise<{ prs: PullRequest[]; stats: RepoStats }> {
  const headers: Record<string, string> = {
    "Authorization": `token ${pat}`,
    "Accept": "application/vnd.github.v3+json",
    "User-Agent": "jibun-kaisha-app",
  };

  const [prRes, repoRes] = await Promise.all([
    fetch(
      `${GITHUB_API_BASE}/repos/${owner}/${repo}/pulls?state=all&per_page=20`,
      { headers },
    ),
    fetch(`${GITHUB_API_BASE}/repos/${owner}/${repo}`, { headers }),
  ]);

  if (!prRes.ok) {
    throw new Error(`GitHub API error: ${prRes.status}`);
  }

  const rawPRs = (await prRes.json()) as GitHubPR[];
  const repoData = repoRes.ok ? (await repoRes.json()) as GitHubRepo : null;

  const prs: PullRequest[] = rawPRs.map((pr) => ({
    number: pr.number,
    title: pr.title,
    state: pr.merged_at
      ? "merged"
      : pr.state === "open"
      ? "open"
      : "closed",
    author: pr.user?.login ?? "",
    updated_at: pr.updated_at,
  }));

  const openCount = prs.filter((p) => p.state === "open").length;
  const mergedCount = prs.filter((p) => p.state === "merged").length;

  return {
    prs,
    stats: {
      open_prs: openCount,
      merged_prs: mergedCount,
      stars: repoData?.stargazers_count ?? 0,
    },
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        { status: 401, headers: corsHeaders },
      );
    }

    const supabaseClient = createClient(
      SUPABASE_URL,
      SUPABASE_SERVICE_ROLE_KEY,
    );

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: userError } =
      await supabaseClient.auth.getUser(token);

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: corsHeaders },
      );
    }

    const body = await req.json();
    const action: string = body.action ?? "get_config";

    if (action === "get_config" || action === "get_prs") {
      const config = await getGitHubConfig(supabaseClient, user.id);

      if (!config?.pat || !config?.repo) {
        return new Response(
          JSON.stringify({
            token_set: false,
            repo: "",
            pull_requests: [],
            stats: { open_prs: 0, merged_prs: 0, stars: 0 },
          }),
          { headers: corsHeaders },
        );
      }

      const [owner, repoName] = config.repo.split("/");
      if (!owner || !repoName) {
        return new Response(
          JSON.stringify({ error: "Invalid repo format. Use owner/repo" }),
          { status: 400, headers: corsHeaders },
        );
      }

      const { prs, stats } = await fetchGitHubPRs(
        config.pat,
        owner,
        repoName,
      );

      return new Response(
        JSON.stringify({
          token_set: true,
          repo: config.repo,
          pull_requests: prs,
          stats,
        }),
        { headers: corsHeaders },
      );
    }

    if (action === "configure") {
      const pat: string = body.pat ?? "";
      const repo: string = body.repo ?? "";

      if (!pat || !repo) {
        return new Response(
          JSON.stringify({ error: "pat and repo are required" }),
          { status: 400, headers: corsHeaders },
        );
      }

      if (!repo.includes("/")) {
        return new Response(
          JSON.stringify({ error: "repo must be in owner/repo format" }),
          { status: 400, headers: corsHeaders },
        );
      }

      const existing = await getGitHubConfig(supabaseClient, user.id);

      if (existing) {
        await supabaseClient
          .from("app_analytics")
          .update({
            metadata: { pat, repo },
            updated_at: new Date().toISOString(),
          })
          .eq("source", "github_config")
          .eq("user_id", user.id);
      } else {
        await supabaseClient.from("app_analytics").insert({
          user_id: user.id,
          source: "github_config",
          metadata: { pat, repo },
          created_at: new Date().toISOString(),
        });
      }

      return new Response(
        JSON.stringify({ success: true, repo }),
        { headers: corsHeaders },
      );
    }

    return new Response(
      JSON.stringify({ error: `Unknown action: ${action}` }),
      { status: 400, headers: corsHeaders },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: corsHeaders },
    );
  }
});
