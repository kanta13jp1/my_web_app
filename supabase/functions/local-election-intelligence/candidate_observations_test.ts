import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  separateCandidateObservations,
  VERIFIED_CANDIDATE_ELECTIONS,
} from "./candidate_observations.ts";

const proof = VERIFIED_CANDIDATE_ELECTIONS[0];
const candidate = {
  prefecture: proof.prefecture,
  electionName: proof.electionName,
  name: proof.name,
  detailUrl: proof.detailUrl,
  sourceUrl: proof.candidateSourceUrl,
  voteDate: "",
  statusLabel: "公認・元職",
};

Deno.test("verified exact profile and election gain the commission voting date", () => {
  const result = separateCandidateObservations([candidate], [proof]);
  assertEquals(result.verifiedCandidates[0].voteDate, "2026-12-27");
  assertEquals(result.pendingCandidates.length, 0);
  assertEquals(result.verifiedEvidence[0].announcementDate, "2026-12-20");
});

Deno.test("a plain PDF or party-page date without reviewed evidence remains pending", () => {
  const result = separateCandidateObservations([{
    ...candidate,
    voteDate: "2027-04-11",
  }], []);
  assertEquals(result.verifiedCandidates, []);
  assertEquals(result.pendingCandidates[0].voteDate, "");
  assertEquals(result.pendingCandidates[0].reportedVoteDate, "2027-04-11");
  assertEquals(result.mayInferWithdrawal, false);
});

Deno.test("an announcement date cannot replace the verified voting date", () => {
  const result = separateCandidateObservations([{
    ...candidate,
    voteDate: "2026-12-20",
  }], [proof]);
  assertEquals(result.verifiedCandidates, []);
});

Deno.test("similar names, different profiles, by-elections and prefectures are not joined", () => {
  for (
    const changed of [
      { ...candidate, name: "鈴木 祐馬" },
      { ...candidate, detailUrl: "https://new-kokumin.jp/member/suzuki-yuma" },
      { ...candidate, electionName: "西東京市議会議員補欠選挙" },
      { ...candidate, prefecture: "埼玉県" },
      { ...candidate, sourceUrl: "https://new-kokumin.jp/member_tag/tokyo" },
    ]
  ) {
    assertEquals(
      separateCandidateObservations([changed], [proof]).verifiedCandidates,
      [],
    );
  }
});

Deno.test("duplicate identities or conflicting evidence are held for review", () => {
  assertEquals(
    separateCandidateObservations([candidate, candidate], [proof])
      .verifiedCandidates,
    [],
  );
  assertEquals(
    separateCandidateObservations([candidate], [proof, {
      ...proof,
      voteDate: "2026-12-28",
    }]).verifiedCandidates,
    [],
  );
});

Deno.test("invalid date or non-government evidence cannot confirm the candidate", () => {
  for (
    const changed of [
      { ...proof, voteDate: "2026-02-30" },
      { ...proof, voteDate: "" },
      { ...proof, voteDate: proof.announcementDate },
      { ...proof, authoritySourceUrl: "https://example.com/election" },
    ]
  ) {
    assertEquals(
      separateCandidateObservations([candidate], [changed]).verifiedCandidates,
      [],
    );
  }
});

Deno.test("separation preserves unverified people and does not mutate source observations", () => {
  const other = {
    ...candidate,
    name: "未確認 候補",
    detailUrl: "https://new-kokumin.jp/member/other",
  };
  const result = separateCandidateObservations([candidate, other], [proof]);
  assertEquals(result.verifiedCandidates.length, 1);
  assertEquals(result.pendingCandidates.length, 1);
  assertEquals(candidate.voteDate, "");
  assertEquals(result.pendingCandidates[0].name, "未確認 候補");
});
