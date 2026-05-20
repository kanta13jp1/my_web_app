export type FeatureRequestCandidate = {
  key: string;
  title: string;
  description?: string;
};

export type ExistingFeatureRequestIssue = {
  key: string;
  number: number;
  title: string;
  html_url: string;
  state: string;
  matched_by: "github_title" | "local_record";
};

export type FeatureRequestIssueLike = {
  number?: unknown;
  title?: unknown;
  html_url?: unknown;
  url?: unknown;
  state?: unknown;
};

export function normalizeFeatureRequestIssueTitle(value: string): string {
  return value
    .normalize("NFKC")
    .replace(/\[[^\]]*\]/g, " ")
    .replace(/【[^】]*】/g, " ")
    .replace(/追加要望/g, " ")
    .replace(/資産管理/g, " ")
    .replace(/feature\s*request/gi, " ")
    .replace(/github\s*issue/gi, " ")
    .toLowerCase()
    .replace(/[\s\p{P}\p{S}]+/gu, "");
}

export function featureRequestCandidateKey(
  title: string,
  description = "",
  source = "",
): string {
  return [
    source.trim().toLowerCase(),
    normalizeFeatureRequestIssueTitle(title),
    normalizeFeatureRequestIssueTitle(description).slice(0, 120),
  ].join("|");
}

export function featureRequestIssueMatchesCandidate(
  candidate: FeatureRequestCandidate,
  issueTitle: string,
): boolean {
  const candidateTitle = normalizeFeatureRequestIssueTitle(candidate.title);
  const issue = normalizeFeatureRequestIssueTitle(issueTitle);
  if (candidateTitle.length < 4 || issue.length < 4) return false;
  return issue === candidateTitle ||
    issue.includes(candidateTitle) ||
    candidateTitle.includes(issue);
}

export function matchExistingFeatureRequestIssues(
  candidates: FeatureRequestCandidate[],
  issues: FeatureRequestIssueLike[],
  matchedBy: ExistingFeatureRequestIssue["matched_by"],
): ExistingFeatureRequestIssue[] {
  const matches = new Map<string, ExistingFeatureRequestIssue>();
  for (const candidate of candidates) {
    if (matches.has(candidate.key)) continue;
    for (const issue of issues) {
      const title = String(issue.title ?? "");
      if (!featureRequestIssueMatchesCandidate(candidate, title)) continue;
      const number = Number(issue.number ?? 0);
      if (!Number.isFinite(number) || number <= 0) continue;
      matches.set(candidate.key, {
        key: candidate.key,
        number,
        title,
        html_url: String(issue.html_url ?? issue.url ?? ""),
        state: String(issue.state ?? ""),
        matched_by: matchedBy,
      });
      break;
    }
  }
  return [...matches.values()];
}
