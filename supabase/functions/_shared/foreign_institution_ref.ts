/**
 * Foreign Institutional Comparison Reference Module (#2808)
 *
 * Stores country/institution entries, validates official http(s) reference
 * URLs, filters by country, and supports reverse-lookup by speech/minute ID.
 */

export type InstitutionCategory =
  | "emergency_decree"
  | "term_extension"
  | "oversight";

export const INSTITUTION_CATEGORY_LABELS = {
  emergency_decree: "Emergency Decree",
  term_extension: "Term Extension",
  oversight: "Parliamentary Oversight",
} as const satisfies Record<InstitutionCategory, string>;

export interface ForeignInstitutionEntry {
  readonly id: string;
  readonly countryCode: string;
  readonly countryName: string;
  readonly category: InstitutionCategory;
  readonly title: string;
  readonly summary: string;
  readonly officialUrl: string;
  readonly citedSpeechIds: readonly string[];
}

export function validateOfficialUrl(rawUrl: string): string {
  const trimmed = rawUrl.trim();
  if (!trimmed) {
    throw new Error("officialUrl is required.");
  }
  let parsed: URL;
  try {
    parsed = new URL(trimmed);
  } catch {
    throw new Error(`Invalid officialUrl: ${trimmed}`);
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new Error("officialUrl must use http:// or https://.");
  }
  if (!parsed.hostname) {
    throw new Error("officialUrl must include a hostname.");
  }
  return parsed.toString();
}

export class ForeignInstitutionRefRegistry {
  private readonly entries: ForeignInstitutionEntry[] = [];

  registerEntry(input: ForeignInstitutionEntry): ForeignInstitutionEntry {
    const id = input.id.trim();
    const countryCode = input.countryCode.trim().toUpperCase();
    const countryName = input.countryName.trim();
    const title = input.title.trim();
    const summary = input.summary.trim();

    if (!id || !countryCode || !countryName || !title || !summary) {
      throw new Error("All institutional reference fields must be non-empty.");
    }

    const normalizedUrl = validateOfficialUrl(input.officialUrl);
    const speechIds = [
      ...new Set(
        input.citedSpeechIds.map((s) => s.trim()).filter((s) => s.length > 0),
      ),
    ];

    const record: ForeignInstitutionEntry = {
      id,
      countryCode,
      countryName,
      category: input.category,
      title,
      summary,
      officialUrl: normalizedUrl,
      citedSpeechIds: speechIds,
    };
    this.entries.push(record);
    return record;
  }

  filterByCountry(countryCode?: string): readonly ForeignInstitutionEntry[] {
    if (!countryCode || !countryCode.trim()) {
      return [...this.entries];
    }
    const target = countryCode.trim().toUpperCase();
    return this.entries.filter((item) => item.countryCode === target);
  }

  findBySpeechId(speechId: string): readonly ForeignInstitutionEntry[] {
    const target = speechId.trim();
    if (!target) {
      return [];
    }
    return this.entries.filter((item) => item.citedSpeechIds.includes(target));
  }
}
