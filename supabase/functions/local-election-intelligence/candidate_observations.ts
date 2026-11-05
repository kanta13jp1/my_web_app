// A read-only separation boundary. Pending observations are not cancellations,
// confirmed election associations, or instructions to write to the database.
import { normalizeConfirmedVoteDate } from "./official_site_parsers.ts";
export interface CandidateObservation {
  prefecture: string;
  electionName: string;
  voteDate: string;
  name: string;
  detailUrl: string;
  sourceUrl: string;
}

export interface VerifiedCandidateElection {
  prefecture: string;
  electionName: string;
  name: string;
  detailUrl: string;
  voteDate: string;
  announcementDate: string;
  authoritySourceUrl: string;
  candidateSourceUrl: string;
  pdfSha256: string;
  pdfRowOrdinal: number;
  verifiedAsOf: string;
}

// Manually checked against the exact party profile, PDF row 113, and the city
// election commission's announcement. No fuzzy-name or municipality fallback.
export const VERIFIED_CANDIDATE_ELECTIONS: VerifiedCandidateElection[] = [{
  prefecture: "東京都",
  electionName: "西東京市議会議員選挙",
  name: "鈴木 佑馬",
  detailUrl: "https://new-kokumin.jp/member/suzuki-yuma-2",
  voteDate: "2026-12-27",
  announcementDate: "2026-12-20",
  authoritySourceUrl:
    "https://www.city.nishitokyo.lg.jp/siseizyoho/senkyo/topics/sigikaisenkyotouhyo.html",
  candidateSourceUrl: "https://new-kokumin.jp/member_tag/tokyo?mode=candidate",
  pdfSha256: "45284c84fbbb3bd4ed5e5f2ca1f0d552ad9da202322b711f729eb3c9df652c91",
  pdfRowOrdinal: 113,
  verifiedAsOf: "2026-11-05",
}];

function identity(
  candidate: CandidateObservation | VerifiedCandidateElection,
): string {
  // Whitespace only: do not equate variant kanji, similar names, or different URLs.
  return [
    candidate.prefecture.trim(),
    candidate.electionName.trim(),
    candidate.name.replace(/[\s　]/gu, ""),
    candidate.detailUrl,
  ].join("::");
}

export function separateCandidateObservations<T extends CandidateObservation>(
  candidates: T[],
  evidence: VerifiedCandidateElection[],
): {
  verifiedCandidates: T[];
  pendingCandidates: Array<T & { reportedVoteDate: string; reason: string }>;
  verifiedEvidence: VerifiedCandidateElection[];
  mayInferWithdrawal: false;
} {
  const verifiedCandidates: T[] = [];
  const pendingCandidates: Array<
    T & { reportedVoteDate: string; reason: string }
  > = [];
  const verifiedEvidence: VerifiedCandidateElection[] = [];
  const counts = new Map<string, number>();
  for (const candidate of candidates) {
    const key = identity(candidate);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  for (const candidate of candidates) {
    const matches = evidence.filter((item) =>
      identity(item) === identity(candidate)
    );
    const entry = matches.length === 1 ? matches[0] : undefined;
    const verified = entry && counts.get(identity(candidate)) === 1 &&
      entry.candidateSourceUrl === candidate.sourceUrl &&
      /^https:\/\/[^/]+\.(?:lg|go)\.jp\//.test(entry.authoritySourceUrl) &&
      normalizeConfirmedVoteDate(entry.voteDate) === entry.voteDate &&
      entry.voteDate !== "" &&
      entry.voteDate !== entry.announcementDate &&
      (candidate.voteDate === "" || candidate.voteDate === entry.voteDate);
    if (verified && entry) {
      verifiedCandidates.push({ ...candidate, voteDate: entry.voteDate });
      verifiedEvidence.push(entry);
    } else {
      pendingCandidates.push({
        ...candidate,
        reportedVoteDate: candidate.voteDate,
        voteDate: "",
        reason: "election_identity_or_voting_date_unverified",
      });
    }
  }
  return {
    verifiedCandidates,
    pendingCandidates,
    verifiedEvidence,
    mayInferWithdrawal: false,
  };
}
