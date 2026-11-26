/**
 * Legislative Facts Sharing & Side-by-Side Comparison Registry (#2806)
 *
 * Registers neutral legislative facts per topic & faction with mandatory
 * http(s) source URL validation and builds a side-by-side comparison matrix.
 */

export type FactStance = "supporting" | "contextual" | "disputed";

export const FACT_STANCE_LABELS = {
  supporting: "Supporting",
  contextual: "Contextual",
  disputed: "Disputed",
} as const satisfies Record<FactStance, string>;

export interface LegislativeFactInput {
  readonly id: string;
  readonly topicKey: string;
  readonly factionName: string;
  readonly summary: string;
  readonly sourceUrl: string;
  readonly sourceTitle: string;
  readonly stance: FactStance;
}

export interface FactionFactColumn {
  readonly factionName: string;
  readonly facts: readonly LegislativeFactInput[];
}

export interface LegislativeFactMatrix {
  readonly topicKey: string;
  readonly totalFacts: number;
  readonly columns: readonly FactionFactColumn[];
}

export function validateSourceUrl(rawUrl: string): string {
  const trimmed = rawUrl.trim();
  if (!trimmed) {
    throw new Error("sourceUrl is required.");
  }
  let parsed: URL;
  try {
    parsed = new URL(trimmed);
  } catch {
    throw new Error(`Invalid sourceUrl: ${trimmed}`);
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new Error("sourceUrl must use http:// or https://.");
  }
  if (!parsed.hostname) {
    throw new Error("sourceUrl must include a hostname.");
  }
  return parsed.toString();
}

export class LegislativeFactRegistry {
  private readonly entries: LegislativeFactInput[] = [];

  registerFact(input: LegislativeFactInput): LegislativeFactInput {
    const id = input.id.trim();
    const topicKey = input.topicKey.trim();
    const factionName = input.factionName.trim();
    const summary = input.summary.trim();
    const sourceTitle = input.sourceTitle.trim();

    if (!id || !topicKey || !factionName || !summary || !sourceTitle) {
      throw new Error("All legislative fact fields must be non-empty.");
    }

    const normalizedUrl = validateSourceUrl(input.sourceUrl);
    const record: LegislativeFactInput = {
      id,
      topicKey,
      factionName,
      summary,
      sourceUrl: normalizedUrl,
      sourceTitle,
      stance: input.stance,
    };
    this.entries.push(record);
    return record;
  }

  buildComparisonMatrix(topicKey: string): LegislativeFactMatrix {
    const target = topicKey.trim();
    const byFaction = new Map<string, LegislativeFactInput[]>();

    for (const item of this.entries) {
      if (item.topicKey !== target) {
        continue;
      }
      const list = byFaction.get(item.factionName) ?? [];
      list.push(item);
      byFaction.set(item.factionName, list);
    }

    const columns: FactionFactColumn[] = [...byFaction.keys()]
      .sort()
      .map((factionName) => ({
        factionName,
        facts: byFaction.get(factionName) ?? [],
      }));

    const totalFacts = columns.reduce(
      (sum, col) => sum + col.facts.length,
      0,
    );

    return {
      topicKey: target,
      totalFacts,
      columns,
    };
  }
}
