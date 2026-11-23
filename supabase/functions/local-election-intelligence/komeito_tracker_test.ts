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
  buildKomeitoLiveDirectorySummary,
  fetchKomeitoMemberSnapshot,
  KOMEITO_DATASET,
  KOMEITO_MEMBER_PAGE_URL,
  KOMEITO_SANGIIN_RESULT_URL,
  KOMEITO_SHUGIIN_RESULT_URL,
  KOMEITO_TRACKER_VARIANT,
  parseKomeitoMemberSummaryHtml,
  parseKomeitoPrefectureDirectory,
  parseKomeitoSearchResultCount,
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

// Real select + result fragments captured verbatim from https://www.komei.or.jp/member/ (2026-11-23)
const REAL_KOMEITO_PREF_SELECT_HTML = `<select name="data[Member][pref]" id="select01">
<option value="">選択してください</option>
<option value="01">北海道</option>
<option value="02">青森県</option>
<option value="03">岩手県</option>
<option value="04">宮城県</option>
<option value="05">秋田県</option>
<option value="06">山形県</option>
<option value="07">福島県</option>
<option value="08">茨城県</option>
<option value="09">栃木県</option>
<option value="10">群馬県</option>
<option value="11">埼玉県</option>
<option value="12">千葉県</option>
<option value="13">東京都</option>
<option value="14">神奈川県</option>
<option value="15">新潟県</option>
<option value="16">富山県</option>
<option value="17">石川県</option>
<option value="18">福井県</option>
<option value="19">山梨県</option>
<option value="20">長野県</option>
<option value="21">岐阜県</option>
<option value="22">静岡県</option>
<option value="23">愛知県</option>
<option value="24">三重県</option>
<option value="25">滋賀県</option>
<option value="26">京都府</option>
<option value="27">大阪府</option>
<option value="28">兵庫県</option>
<option value="29">奈良県</option>
<option value="30">和歌山県</option>
<option value="31">鳥取県</option>
<option value="32">島根県</option>
<option value="33">岡山県</option>
<option value="34">広島県</option>
<option value="35">山口県</option>
<option value="36">徳島県</option>
<option value="37">香川県</option>
<option value="38">愛媛県</option>
<option value="39">高知県</option>
<option value="40">福岡県</option>
<option value="41">佐賀県</option>
<option value="42">長崎県</option>
<option value="43">熊本県</option>
<option value="44">大分県</option>
<option value="45">宮崎県</option>
<option value="46">鹿児島県</option>
<option value="47">沖縄県</option>
</select>`;

const REAL_KOMEITO_RESULT_P_HTML =
  `<p>検索結果<em class="em02">315人</em>の該当する議員が見つかりました。</p>`;

Deno.test("parseKomeitoPrefectureDirectory, parseKomeitoSearchResultCount, and buildKomeitoLiveDirectorySummary enforce 47-prefecture integrity", () => {
  const entries = parseKomeitoPrefectureDirectory(REAL_KOMEITO_PREF_SELECT_HTML);
  assertEquals(entries.length, 47);
  assertEquals(entries[0], {
    code: "01",
    prefecture: "北海道",
    sourceUrl: "https://www.komei.or.jp/member/result/pref:01/",
  });
  assertEquals(entries[12], {
    code: "13",
    prefecture: "東京都",
    sourceUrl: "https://www.komei.or.jp/member/result/pref:13/",
  });
  assertEquals(entries[46], {
    code: "47",
    prefecture: "沖縄県",
    sourceUrl: "https://www.komei.or.jp/member/result/pref:47/",
  });

  // Fail-closed when fewer than 47 prefectures are present
  const missingOkinawa = REAL_KOMEITO_PREF_SELECT_HTML.replace(
    '<option value="47">沖縄県</option>\n',
    "",
  );
  assertEquals(parseKomeitoPrefectureDirectory(missingOkinawa), []);

  assertEquals(parseKomeitoSearchResultCount(REAL_KOMEITO_RESULT_P_HTML), 315);
  assertEquals(
    parseKomeitoSearchResultCount(
      '<p>検索結果<em class="em02">１,２３４人</em>の該当する議員が見つかりました。</p>',
    ),
    1234,
  );
  assertEquals(parseKomeitoSearchResultCount("<html>no result</html>"), null);

  const validTallies = entries.map((entry) => ({
    ...entry,
    totalMembers: entry.code === "01"
      ? 150
      : entry.code === "13"
      ? 315
      : entry.code === "27"
      ? 204
      : entry.code === "02"
      ? 68
      : 50,
  }));
  const summary = buildKomeitoLiveDirectorySummary(validTallies, 28, 21);
  assert(summary !== null);
  assertEquals(summary.totalMembers, 2887);
  assertEquals(summary.estimatedLocalMembers, 2838);

  // Fail-closed on < 47 entries
  assertEquals(
    buildKomeitoLiveDirectorySummary(validTallies.slice(0, 46), 28, 21),
    null,
  );
  // Fail-closed on suspiciously low total (< 2000)
  const lowTallies = entries.map((entry) => ({
    ...entry,
    totalMembers: 40,
  }));
  assertEquals(buildKomeitoLiveDirectorySummary(lowTallies, 28, 21), null);
});

Deno.test("persistKomeitoSnapshot upgrades v1->v2 silently and queues prefecture delta candidate on v2->v2 change", async () => {
  const store = new KomeitoMemoryStore();
  const v1Baseline = parseKomeitoMemberSummaryHtml(REAL_KOMEITO_MEMBER_HTML);
  assert(v1Baseline !== null);
  assertEquals(v1Baseline.liveDirectory, undefined);

  const initial = await persistKomeitoSnapshot(
    store,
    v1Baseline,
    "2026-11-23T03:00:00.000Z",
  );
  assert(initial.baselineCreated);
  assertEquals(initial.candidateCount, 0);

  const rootWithPrefHtml =
    `${REAL_KOMEITO_MEMBER_HTML}\n${REAL_KOMEITO_PREF_SELECT_HTML}`;
  const directory = parseKomeitoPrefectureDirectory(REAL_KOMEITO_PREF_SELECT_HTML);
  const makeMockFetcher = (tokyoCount: number) => {
    const pages = new Map<string, string>([
      [KOMEITO_MEMBER_PAGE_URL, rootWithPrefHtml],
      [
        KOMEITO_SHUGIIN_RESULT_URL,
        "<p>検索結果<em class=\"em02\">28人</em>の該当する議員が見つかりました。</p>",
      ],
      [
        KOMEITO_SANGIIN_RESULT_URL,
        "<p>検索結果<em class=\"em02\">21人</em>の該当する議員が見つかりました。</p>",
      ],
    ]);
    for (const entry of directory) {
      const count = entry.code === "01"
        ? 150
        : entry.code === "13"
        ? tokyoCount
        : entry.code === "27"
        ? 204
        : entry.code === "02"
        ? 68
        : 50;
      const html = count === 315
        ? REAL_KOMEITO_RESULT_P_HTML
        : `<p>検索結果<em class="em02">${count}人</em>の該当する議員が見つかりました。</p>`;
      pages.set(entry.sourceUrl, html);
    }
    return (url: string): Promise<string> => {
      const html = pages.get(url);
      if (html === undefined) {
        return Promise.reject(new Error(`Unexpected URL: ${url}`));
      }
      return Promise.resolve(html);
    };
  };

  // v1 -> v2 upgrade: summary table unchanged, liveDirectory populated -> zero candidates
  const v2Snapshot = await fetchKomeitoMemberSnapshot(makeMockFetcher(315));
  assertEquals(v2Snapshot.liveDirectory?.prefectures.length, 47);
  assertEquals(v2Snapshot.liveDirectory?.totalMembers, 2887);
  assertEquals(v2Snapshot.liveDirectory?.estimatedLocalMembers, 2838);

  const upgraded = await persistKomeitoSnapshot(
    store,
    v2Snapshot,
    "2026-11-23T12:00:00.000Z",
  );
  assertEquals(upgraded.snapshotCreated, true);
  assertEquals(upgraded.hasChanges, false);
  assertEquals(upgraded.candidateCount, 0);
  assertEquals(upgraded.candidatesCreated, 0);
  assertEquals(store.candidates.length, 0);

  // v2 -> v2 delta: Tokyo changes 315 -> 316 -> HITL data_report candidate queued
  const v2UpdatedSnapshot = await fetchKomeitoMemberSnapshot(
    makeMockFetcher(316),
  );
  assertEquals(v2UpdatedSnapshot.liveDirectory?.totalMembers, 2888);
  assertEquals(v2UpdatedSnapshot.liveDirectory?.estimatedLocalMembers, 2839);

  const queued = await persistKomeitoSnapshot(
    store,
    v2UpdatedSnapshot,
    "2026-11-24T00:00:00.000Z",
  );
  assertEquals(queued.snapshotCreated, true);
  assertEquals(queued.hasChanges, true);
  assertEquals(queued.candidateCount, 1);
  assertEquals(queued.candidatesCreated, 1);
  assertEquals(store.candidates.length, 1);

  const candidate = store.candidates[0].metadata;
  assertEquals(candidate.requires_human_approval, true);
  assertEquals(candidate.auto_publish, false);
  assertEquals(candidate.content_archetype, "data_report");

  const payload = candidate.post_payload as JsonRecord;
  assertEquals(payload.linkInReply, true);
  assertEquals(classifyPostArchetype(String(payload.text ?? "")), "data_report");
  const thread = [
    String(payload.text ?? ""),
    ...((payload.replyTexts as string[]) ?? []),
  ].join("\n");
  assert(thread.includes("東京都: 315→316人 (+1)"));
});
