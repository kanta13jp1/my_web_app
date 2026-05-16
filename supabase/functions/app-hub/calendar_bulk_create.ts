export function normalizeCalendarIcsUid(value: unknown): string {
  const raw = value == null ? "" : String(value).trim();
  return raw.length > 512 ? raw.slice(0, 512) : raw;
}

export function calendarIcsUidFromMetadata(
  metadata: Record<string, unknown>,
): string {
  return normalizeCalendarIcsUid(metadata.ical_uid ?? metadata.uid);
}

export type CalendarBulkCreatePreparation = {
  candidates: Record<string, unknown>[];
  skippedDuplicates: number;
  invalidCount: number;
};

export function prepareCalendarBulkCreateCandidates(
  rawEvents: unknown,
  existingUids: Set<string>,
): CalendarBulkCreatePreparation {
  if (!Array.isArray(rawEvents)) {
    return { candidates: [], skippedDuplicates: 0, invalidCount: 1 };
  }

  const seen = new Set(
    Array.from(existingUids).map(normalizeCalendarIcsUid).filter(Boolean),
  );
  const candidates: Record<string, unknown>[] = [];
  let skippedDuplicates = 0;
  let invalidCount = 0;

  for (const raw of rawEvents) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
      invalidCount += 1;
      continue;
    }
    const event = raw as Record<string, unknown>;
    const uid = normalizeCalendarIcsUid(event.ical_uid ?? event.uid);
    const startAt = String(event.start_at ?? "").trim();
    if (!uid || !startAt) {
      invalidCount += 1;
      continue;
    }
    if (seen.has(uid)) {
      skippedDuplicates += 1;
      continue;
    }
    seen.add(uid);
    candidates.push({ ...event, ical_uid: uid });
  }

  return { candidates, skippedDuplicates, invalidCount };
}
