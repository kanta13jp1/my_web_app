import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  calendarIcsUidFromMetadata,
  normalizeCalendarIcsUid,
  prepareCalendarBulkCreateCandidates,
} from "./calendar_bulk_create.ts";

Deno.test("calendar bulk create normalizes UID metadata", () => {
  assertEquals(
    normalizeCalendarIcsUid(" event-1@example.com "),
    "event-1@example.com",
  );
  assertEquals(
    calendarIcsUidFromMetadata({ uid: "fallback-uid" }),
    "fallback-uid",
  );
  assertEquals(
    calendarIcsUidFromMetadata({ ical_uid: "ical-uid", uid: "fallback-uid" }),
    "ical-uid",
  );
});

Deno.test("calendar bulk create skips existing and payload duplicate UIDs", () => {
  const prepared = prepareCalendarBulkCreateCandidates(
    [
      { ical_uid: "already-there", start_at: "2026-05-14T09:00:00.000" },
      { uid: "new-one", start_at: "2026-05-14T10:00:00.000" },
      { ical_uid: "new-one", start_at: "2026-05-14T11:00:00.000" },
      { ical_uid: "", start_at: "2026-05-14T12:00:00.000" },
      { ical_uid: "missing-start" },
      "not-an-event",
    ],
    new Set(["already-there"]),
  );

  assertEquals(prepared.candidates.length, 1);
  assertEquals(prepared.candidates[0].ical_uid, "new-one");
  assertEquals(prepared.skippedDuplicates, 2);
  assertEquals(prepared.invalidCount, 3);
});
