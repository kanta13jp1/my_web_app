import {
  assertEquals,
  assertRejects,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  exportFilteredRecords,
  FORMAT_IMPORTER_ATTR_SOURCE,
  FORMAT_IMPORTER_RECORD_SOURCE,
  FormatImporterDb,
  FormatImporterError,
  handleFormatImporterAction,
  HubDataRow,
  mapRecordWithSchema,
  parseCsvRecords,
  parseHierarchicalJsonRecords,
} from "./format_importer.ts";

class MockHubDb implements FormatImporterDb {
  rows: Array<{
    id: string;
    source: string;
    metadata: Record<string, unknown>;
    created_at: string;
  }> = [];
  private seq = 1;

  from(_table: string) {
    const db = this;
    const state: {
      op: "select" | "insert" | "update";
      insertVal?: Record<string, unknown>;
      updateVal?: Record<string, unknown>;
      eqFilters: Array<[string, unknown]>;
      userFilter?: string;
    } = {
      op: "select",
      eqFilters: [],
    };

    const execute = () => {
      if (state.op === "insert" && state.insertVal) {
        const created = {
          id: `rec-${db.seq++}`,
          source: String(state.insertVal.source ?? ""),
          metadata: (state.insertVal.metadata ?? {}) as Record<string, unknown>,
          created_at: `2026-11-25T00:00:0${db.seq}Z`,
        };
        db.rows.push(created);
        return { data: created, error: null };
      }

      const matches = db.rows.filter((row) => {
        for (const [col, val] of state.eqFilters) {
          if (col === "id" && row.id !== val) return false;
          if (col === "source" && row.source !== val) return false;
        }
        if (state.userFilter !== undefined) {
          if (String(row.metadata.user_id ?? "") !== state.userFilter) {
            return false;
          }
        }
        return true;
      });

      if (state.op === "update" && state.updateVal) {
        if (matches.length === 0) return { data: null, error: null };
        matches[0].metadata = (state.updateVal.metadata ?? {}) as Record<
          string,
          unknown
        >;
        return { data: matches[0], error: null };
      }

      return { data: matches, error: null };
    };

    const builder = {
      select(_columns: string) {
        return builder;
      },
      insert(values: Record<string, unknown>) {
        state.op = "insert";
        state.insertVal = values;
        return builder;
      },
      update(values: Record<string, unknown>) {
        state.op = "update";
        state.updateVal = values;
        return builder;
      },
      eq(col: string, val: unknown) {
        state.eqFilters.push([col, val]);
        return builder;
      },
      filter(col: string, _op: string, val: unknown) {
        if (col === "metadata->>user_id") {
          state.userFilter = String(val);
        }
        return builder;
      },
      order() {
        return builder;
      },
      limit() {
        return builder;
      },
      single() {
        const res = execute();
        return Promise.resolve({
          data: Array.isArray(res.data) ? res.data[0] ?? null : res.data,
          error: res.error,
        });
      },
      maybeSingle() {
        const res = execute();
        return Promise.resolve({
          data: Array.isArray(res.data) ? res.data[0] ?? null : res.data,
          error: res.error,
        });
      },
      then(onfulfilled?: (value: unknown) => unknown) {
        return Promise.resolve(execute()).then(onfulfilled);
      },
    };
    return builder;
  }
}

Deno.test(
  "parses hierarchical JSON and RFC-4180 CSV with dot-path mapping",
  () => {
    const jsonPayload = JSON.stringify({
      envelope: {
        entries: [
          {
            header: { code: "STD-101", origin: "NRT" },
            metrics: { priority: 2 },
          },
        ],
      },
    });
    const parsedJson = parseHierarchicalJsonRecords(
      jsonPayload,
      "envelope.entries",
    );
    const mapped = mapRecordWithSchema(parsedJson[0], {
      record_code: "header.code",
      hub: "header.origin",
      priority: "metrics.priority",
    });
    assertEquals(mapped, {
      record_code: "STD-101",
      hub: "NRT",
      priority: 2,
    });

    const csvPayload = 'code,note\r\n"A-1","Contains, comma"\r\n';
    const parsedCsv = parseCsvRecords(csvPayload);
    assertEquals(parsedCsv.length, 1);
    assertEquals(parsedCsv[0].note, "Contains, comma");

    assertThrows(
      () => mapRecordWithSchema({ ok: 1 }, { bad: "__proto__.polluted" }),
      FormatImporterError,
    );
  },
);

Deno.test(
  "defines JSONB attrs, imports records, updates attrs, and filters export",
  async () => {
    const db = new MockHubDb();

    const defRes = await handleFormatImporterAction({
      action: "format_importer.define_attribute",
      admin: db,
      userId: "user-1",
      body: {
        key: "priority_tier",
        label: "Priority Tier",
        value_type: "number",
        required: true,
        default_value: 3,
      },
    });
    assertEquals(
      (defRes.custom_attribute as { value_type: string }).value_type,
      "number",
    );

    await assertRejects(
      () =>
        handleFormatImporterAction({
          action: "format_importer.define_attribute",
          admin: db,
          userId: "user-1",
          body: { key: "Invalid-Key", value_type: "string" },
        }),
      FormatImporterError,
    );

    const importPublic = await handleFormatImporterAction({
      action: "format_importer.import",
      admin: db,
      userId: "user-1",
      body: {
        source_format: "csv",
        format_profile: "generic_csv",
        tags: ["external", "sync"],
        field_mapping: { code: "id", internal_note: "note" },
        custom_attributes: { priority_tier: "5", debug_flag: "temp" },
        payload: "id,note\nITEM-1,internal draft\n",
      },
    });
    assertEquals(importPublic.imported_count, 1);

    await handleFormatImporterAction({
      action: "format_importer.import",
      admin: db,
      userId: "user-1",
      body: {
        source_format: "json",
        tags: ["internal"],
        custom_attributes: { priority_tier: 1 },
        payload: JSON.stringify({ code: "ITEM-HIDDEN" }),
      },
    });

    const firstId = ((importPublic.records as HubDataRow[])[0]).id;
    await handleFormatImporterAction({
      action: "format_importer.update_record_attributes",
      admin: db,
      userId: "user-1",
      body: {
        record_id: firstId,
        custom_attributes: { priority_tier: 9, region_code: "APAC" },
      },
    });

    const exported = await handleFormatImporterAction({
      action: "format_importer.export",
      admin: db,
      userId: "user-1",
      body: {
        format: "csv",
        excluded_fields: ["internal_note", "custom_attributes.debug_flag"],
        excluded_tags: ["internal"],
      },
    });

    assertEquals(exported.record_count, 1);
    const csvOut = String(exported.payload_text);
    assertEquals(csvOut.includes("ITEM-1"), true);
    assertEquals(csvOut.includes("ITEM-HIDDEN"), false);
    assertEquals(csvOut.includes("internal draft"), false);
    assertEquals(csvOut.includes("debug_flag"), false);
    assertEquals(csvOut.includes("APAC"), true);

    assertEquals(
      db.rows.filter((r) => r.source === FORMAT_IMPORTER_ATTR_SOURCE).length,
      1,
    );
    assertEquals(
      db.rows.filter((r) => r.source === FORMAT_IMPORTER_RECORD_SOURCE).length,
      2,
    );
  },
);

Deno.test("exportFilteredRecords rejects unowned update with 404", async () => {
  const db = new MockHubDb();
  await handleFormatImporterAction({
    action: "format_importer.import",
    admin: db,
    userId: "user-1",
    body: {
      source_format: "json",
      payload: JSON.stringify({ code: "OWNED" }),
    },
  });
  const ownedId = db.rows[0].id;
  await assertRejects(
    () =>
      handleFormatImporterAction({
        action: "format_importer.update_record_attributes",
        admin: db,
        userId: "user-2",
        body: { record_id: ownedId, custom_attributes: { region: "EU" } },
      }),
    FormatImporterError,
  );
  const res = exportFilteredRecords([], { format: "json" });
  assertEquals(res.record_count, 0);
});
