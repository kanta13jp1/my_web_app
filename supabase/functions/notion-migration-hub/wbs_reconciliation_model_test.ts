import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  prepareWbsStagingRows,
  reconcileWbsMirror,
  type WbsMirrorRecord,
  wbsMirrorRecord,
} from "./wbs_reconciliation_model.ts";

const base = wbsMirrorRecord({
  id: "A0E77981-441D-41E1-A470-59C9FC632ED1",
  title: "Migrate the WBS mirror",
  instance: "all",
  status: "in-progress",
  progress: "50",
  deadline: "2026-08-30T00:00:00.000Z",
  updatedAt: "2026-08-23T09:00:00+09:00",
});

Deno.test("passes only when every WBS ID and mirrored field is equal", () => {
  const notion = wbsMirrorRecord({
    id: "a0e77981-441d-41e1-a470-59c9fc632ed1",
    title: "Migrate the WBS mirror",
    instance: "codex",
    status: "in_progress",
    progress: 50,
    deadline: "2026-08-30",
    updatedAt: "2026-08-23T00:00:00.000Z",
  });

  assertEquals(reconcileWbsMirror([base], [notion]), {
    siteRows: 1,
    notionRows: 1,
    siteDistinctIds: 1,
    notionDistinctIds: 1,
    siteDuplicateRows: 0,
    notionDuplicateRows: 0,
    siteInvalidIds: 0,
    notionInvalidIds: 0,
    onlyInSite: 0,
    onlyInNotion: 0,
    exactMatches: 1,
    mismatchedRecords: 0,
    mismatchedFields: {
      title: 0,
      instance: 0,
      status: 0,
      progress: 0,
      deadline: 0,
      updated_at: 0,
    },
    deletionGatePassed: true,
  });
});

Deno.test("blocks deletion for duplicate, invalid, or one-sided IDs", () => {
  const extra = { ...base, id: "site-only" };
  const invalid = { ...base, id: "" };
  const result = reconcileWbsMirror(
    [base, extra, invalid],
    [base, base, { ...base, id: "notion-only" }],
  );

  assertEquals(result.siteDuplicateRows, 0);
  assertEquals(result.notionDuplicateRows, 1);
  assertEquals(result.siteInvalidIds, 1);
  assertEquals(result.onlyInSite, 1);
  assertEquals(result.onlyInNotion, 1);
  assertEquals(result.deletionGatePassed, false);
});

Deno.test("reports every differing field without exposing record contents", () => {
  const notion: WbsMirrorRecord = {
    ...base,
    title: "Different",
    instance: "user",
    status: "completed",
    progress: 100,
    deadline: null,
    updatedAt: "2026-08-24T00:00:00.000Z",
  };
  const result = reconcileWbsMirror([base], [notion]);

  assertEquals(result.mismatchedRecords, 1);
  assertEquals(result.exactMatches, 0);
  assertEquals(result.mismatchedFields, {
    title: 1,
    instance: 1,
    status: 1,
    progress: 1,
    deadline: 1,
    updated_at: 1,
  });
  assertEquals(result.deletionGatePassed, false);
});

Deno.test("stages duplicate WBS rows losslessly by Notion page ID", () => {
  const rows = prepareWbsStagingRows([
    {
      sourcePageId: "notion-page-1",
      record: base,
      sourceLastEditedAt: "2026-08-23T09:00:00+09:00",
      sourcePayload: { id: "notion-page-1", properties: { sample: true } },
    },
    {
      sourcePageId: "notion-page-2",
      record: { ...base, title: "Duplicate mirror row" },
      sourceLastEditedAt: null,
      sourcePayload: { id: "notion-page-2", properties: { sample: false } },
    },
    {
      sourcePageId: "notion-page-3",
      record: { ...base, id: "" },
      sourceLastEditedAt: "invalid-date",
      sourcePayload: { id: "notion-page-3" },
    },
  ]);

  assertEquals(rows.map((row) => row.duplicateOrdinal), [1, 2, 1]);
  assertEquals(rows[1].sourcePageId, "notion-page-2");
  assertEquals(rows[1].sourcePayload.properties, { sample: false });
  assertEquals(rows[2].taskId, "");
  assertEquals(rows[2].sourceLastEditedAt, "invalid-date");
});

Deno.test("rejects staging rows that would overwrite a source page", () => {
  let error = "";
  try {
    prepareWbsStagingRows([
      {
        sourcePageId: "same-page",
        record: base,
        sourceLastEditedAt: null,
        sourcePayload: {},
      },
      {
        sourcePageId: "same-page",
        record: base,
        sourceLastEditedAt: null,
        sourcePayload: {},
      },
    ]);
  } catch (caught) {
    error = caught instanceof Error ? caught.message : String(caught);
  }
  assertEquals(error, "wbs_stage_duplicate_source_page_id");
});
