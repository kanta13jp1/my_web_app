import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { classifyPostArchetype } from "../growth-hub/x_post_archetype.ts";
import type {
  HubDataRow,
  HubInsertResult,
  JsonRecord,
  LocalElectionHubStore,
} from "./snapshot_history.ts";
import {
  KOMEITO_DATASET,
  KOMEITO_TRACKER_VARIANT,
  parseKomeitoMemberSummaryHtml,
  persistKomeitoSnapshot,
} from "./komeito_tracker.ts";

// Real HTML captured verbatim from https://www.komei.or.jp/member/ (2026-11-23)
const REAL_KOMEITO_MEMBER_HTML = `
<div id="main">
<div class="inner">
<div class="hdg2_02 date">
<h2 class="mt0"><span>所属議員数</span></h2>
<p>2026年10月31日現在</p>
<!--/.hdg2_02 --></div>
<p><em class="em01">2,886人</em>（推薦：1人）</p>
<div class="column2_01">
<div class="col">
<h3 class="hdg3_01">国会議員</h3>
<table class="tbl01 acenter">
<colgroup>
<col class="w25" />
<col class="w25" />
<col class="w25" />
<col class="w25" />
</colgroup>
<thead>
<tr>
<td class="blank">&nbsp;</td>
<th>男性</th>
<th>女性</th>
<th>議員総数</th>
</tr>
</thead>
<tbody>
<tr>
<th>衆議院</th>
<td>24</td>
<td>4</td>
<td>28</td>
</tr>
<tr>
<th>参議院</th>
<td>19</td>
<td>2</td>
<td>21</td>
</tr>
<tr class="em01">
<th>小計</th> 
<td>43</td>
<td>6</td>
<td>49</td>
</tr>
</tbody>
</table>
<!--/.col --></div>
<div class="col">
<h3 class="hdg3_01">地方議員</h3>
<table class="tbl01 acenter mb5">
<colgroup>
<col class="w25" />
<col class="w25" />
<col class="w25" />
<col class="w25" />
</colgroup>
<thead>
<tr>
<td class="blank">&nbsp;</td>
<th>男性</th>
<th>女性</th>
<th>議員総数</th>
</tr>
</thead>
<tbody>
<tr>
<th>都道府県会</th>
<td>167<br /></td>
<td>36</td>
<td>203<br /></td>
</tr>
<tr>
<th>政令市会</th>
<td>155</td>
<td>43</td>
<td>198</td>
</tr>
<tr>
<th>特別区会</th>
<td>115</td>
<td>47</td>
<td>162</td>
</tr>
<tr>
<th>一般市会</th>
<td>1,203<br />（1）</td>
<td>668<br /></td>
<td>1,871<br />（1）</td>
</tr>
<tr>
<th>町村会</th>
<td>183<br /></td>
<td>220<br /></td>
<td>403<br /></td>
</tr>
<tr class="em01">
<th>小計</th>
<td>1,823<br />（1）</td>
<td>1014<br /></td>
<td>2,837<br />（1）</td>
</tr>
</tbody>
</table>
<ul class="note01">
<li><span>※</span>（）内数字は推薦議員数。</li>
</ul>
<!--/.col --></div>
<!--/.column2_01 --></div>
</div>
</div>
`;

class KomeitoMemoryStore implements LocalElectionHubStore {
  snapshots: HubDataRow[] = [];
  candidates: HubDataRow[] = [];
  private seq = 0;

  findSnapshotTransition(
    dataset: string,
    previousSnapshotId: string | null,
    snapshotHash: string,
  ): Promise<HubDataRow | null> {
    const found = this.snapshots.find((row) =>
      row.metadata.dataset === dataset &&
      (row.metadata.previous_snapshot_id ?? null) === previousSnapshotId &&
      row.metadata.snapshot_hash === snapshotHash
    ) ?? null;
    return Promise.resolve(found);
  }

  findSnapshotById(snapshotId: string): Promise<HubDataRow | null> {
    return Promise.resolve(
      this.snapshots.find((row) => row.id === snapshotId) ?? null,
    );
  }

  getLatestSnapshot(dataset: string): Promise<HubDataRow | null> {
    const filtered = this.snapshots.filter((row) =>
      row.metadata.dataset === dataset
    );
    return Promise.resolve(
      filtered.length > 0 ? filtered[filtered.length - 1] : null,
    );
  }

  async insertSnapshot(metadata: JsonRecord): Promise<HubInsertResult> {
    const existing = await this.findSnapshotTransition(
      String(metadata.dataset ?? ""),
      (metadata.previous_snapshot_id as string | null) ?? null,
      String(metadata.snapshot_hash ?? ""),
    );
    if (existing) return { row: existing, created: false };
    this.seq += 1;
    const row: HubDataRow = {
      id: `snap-${this.seq}`,
      metadata: structuredClone(metadata),
      created_at: `2026-11-23T00:00:0${this.seq}.000Z`,
    };
    this.snapshots.push(row);
    return { row, created: true };
  }

  insertPostCandidate(metadata: JsonRecord): Promise<HubInsertResult> {
    const key = String(metadata.candidate_key ?? "");
    const existing = this.candidates.find((row) =>
      row.metadata.candidate_key === key
    );
    if (existing) return Promise.resolve({ row: existing, created: false });
    this.seq += 1;
    const row: HubDataRow = {
      id: `cand-${this.seq}`,
      metadata: structuredClone(metadata),
      created_at: `2026-11-23T00:00:0${this.seq}.000Z`,
    };
    this.candidates.push(row);
    return Promise.resolve({ row, created: true });
  }
}

Deno.test("parseKomeitoMemberSummaryHtml parses exact captured komei.or.jp HTML", () => {
  const snapshot = parseKomeitoMemberSummaryHtml(REAL_KOMEITO_MEMBER_HTML);
  assert(snapshot !== null);
  assertEquals(snapshot.asOfDate, "2026-10-31");
  assertEquals(snapshot.asOfLabel, "2026年10月31日現在");
  assertEquals(snapshot.totalMembers, 2886);
  assertEquals(snapshot.recommendedCount, 1);
  assertEquals(snapshot.national.subtotal, {
    male: 43,
    female: 6,
    total: 49,
    recommended: 0,
  });
  assertEquals(snapshot.local.prefectural.total, 203);
  assertEquals(snapshot.local.designatedCity.total, 198);
  assertEquals(snapshot.local.specialWard.total, 162);
  assertEquals(snapshot.local.generalCity, {
    male: 1203,
    female: 668,
    total: 1871,
    recommended: 1,
  });
  assertEquals(snapshot.local.townVillage.total, 403);
  assertEquals(snapshot.local.subtotal, {
    male: 1823,
    female: 1014,
    total: 2837,
    recommended: 1,
  });
});

Deno.test("parseKomeitoMemberSummaryHtml rejects broken or arithmetically inconsistent HTML", () => {
  assertEquals(parseKomeitoMemberSummaryHtml(""), null);
  assertEquals(
    parseKomeitoMemberSummaryHtml("<html><body>not found</body></html>"),
    null,
  );
  // Corrupt top total so national (49) + local (2837) !== total (2900)
  const mismatchedTotal = REAL_KOMEITO_MEMBER_HTML.replace("2,886人", "2,900人");
  assertEquals(parseKomeitoMemberSummaryHtml(mismatchedTotal), null);
});

Deno.test("persistKomeitoSnapshot creates baseline with zero candidates and dedupes retries", async () => {
  const store = new KomeitoMemoryStore();
  const snapshot = parseKomeitoMemberSummaryHtml(REAL_KOMEITO_MEMBER_HTML);
  assert(snapshot !== null);

  const first = await persistKomeitoSnapshot(
    store,
    snapshot,
    "2026-11-23T03:00:00.000Z",
  );
  assertEquals(first.dataset, KOMEITO_DATASET);
  assert(first.baselineCreated);
  assert(first.snapshotCreated);
  assertEquals(first.candidateCount, 0);
  assertEquals(store.candidates.length, 0);

  const retry = await persistKomeitoSnapshot(
    store,
    snapshot,
    "2026-11-23T09:00:00.000Z",
  );
  assert(retry.deduplicated);
  assertEquals(retry.snapshotCreated, false);
  assertEquals(retry.candidateCount, 0);
  assertEquals(store.snapshots.length, 1);
  assertEquals(store.candidates.length, 0);
});

Deno.test("persistKomeitoSnapshot queues HITL data_report candidate when member count changes", async () => {
  const store = new KomeitoMemoryStore();
  const baseline = parseKomeitoMemberSummaryHtml(REAL_KOMEITO_MEMBER_HTML);
  assert(baseline !== null);
  await persistKomeitoSnapshot(store, baseline, "2026-11-23T03:00:00.000Z");

  // Simulate an official monthly update (+2 generalCity women -> 2,839 local / 2,888 total)
  const updatedHtml = REAL_KOMEITO_MEMBER_HTML
    .replace("2026年10月31日現在", "2026年11月30日現在")
    .replace("2,886人", "2,888人")
    .replace("<td>668<br /></td>", "<td>670<br /></td>")
    .replace("<td>1,871<br />（1）</td>", "<td>1,873<br />（1）</td>")
    .replace("<td>1014<br /></td>", "<td>1016<br /></td>")
    .replace("<td>2,837<br />（1）</td>", "<td>2,839<br />（1）</td>");
  const updated = parseKomeitoMemberSummaryHtml(updatedHtml);
  assert(updated !== null);

  const queued = await persistKomeitoSnapshot(
    store,
    updated,
    "2026-12-01T00:00:00.000Z",
  );
  assert(queued.snapshotCreated);
  assert(queued.hasChanges);
  assertEquals(queued.candidateCount, 1);
  assertEquals(queued.candidatesCreated, 1);

  const candidate = store.candidates[0].metadata;
  assertEquals(candidate.status, "pending_approval");
  assertEquals(candidate.variant, KOMEITO_TRACKER_VARIANT);
  assertEquals(candidate.content_archetype, "data_report");
  assertEquals(candidate.requires_human_approval, true);
  assertEquals(candidate.auto_publish, false);

  const postPayload = candidate.post_payload as JsonRecord;
  assertEquals(postPayload.action, "x.post");
  const fullThread = [
    String(postPayload.text ?? ""),
    ...((postPayload.replyTexts as string[]) ?? []),
  ].join("\n");
  assert(fullThread.includes("2,837→2,839人 (+2)"));
  assert(fullThread.includes("一般市会: 1,871→1,873人 (+2)"));
  assertEquals(classifyPostArchetype(fullThread), "data_report");
});
