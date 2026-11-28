/**
 * LLM Tool Proposal & User Engagement CTR Correlation Monitor (#2794)
 *
 * Tracks (actionType, generatedLabel, eventKind) pairs, computes CTR per
 * semantic pair, and produces schema-pruning recommendations for low-CTR tools.
 */

export type EngagementEventKind = "impression" | "click";

export const EVENT_KIND_LABELS = {
  impression: "Impression",
  click: "Click",
} as const satisfies Record<EngagementEventKind, string>;

export interface ToolEngagementEvent {
  readonly actionType: string;
  readonly generatedLabel: string;
  readonly eventKind: EngagementEventKind;
}

export interface ToolCtrMetric {
  readonly actionType: string;
  readonly generatedLabel: string;
  readonly impressions: number;
  readonly clicks: number;
  readonly ctr: number;
}

export interface SchemaPruningCandidate {
  readonly actionType: string;
  readonly generatedLabel: string;
  readonly impressions: number;
  readonly clicks: number;
  readonly ctr: number;
  readonly reason: string;
}

export interface SchemaPruningReport {
  readonly minImpressions: number;
  readonly minCtrThreshold: number;
  readonly totalPairs: number;
  readonly prunedActionTypes: readonly string[];
  readonly candidates: readonly SchemaPruningCandidate[];
}

interface PairCounter {
  readonly actionType: string;
  readonly generatedLabel: string;
  impressions: number;
  clicks: number;
}

function pairKey(actionType: string, generatedLabel: string): string {
  return `${actionType}\u0000${generatedLabel}`;
}

export function calculateCtr(impressions: number, clicks: number): number {
  if (impressions <= 0) {
    return 0;
  }
  const boundedClicks = Math.min(impressions, Math.max(0, clicks));
  return Number((boundedClicks / impressions).toFixed(4));
}

export class LlmToolEngagementMonitor {
  private readonly counters = new Map<string, PairCounter>();

  recordEvent(event: ToolEngagementEvent): void {
    const actionType = event.actionType.trim();
    const generatedLabel = event.generatedLabel.trim();
    if (!actionType || !generatedLabel) {
      throw new Error("actionType and generatedLabel must be non-empty.");
    }

    const key = pairKey(actionType, generatedLabel);
    let entry = this.counters.get(key);
    if (!entry) {
      entry = {
        actionType,
        generatedLabel,
        impressions: 0,
        clicks: 0,
      };
      this.counters.set(key, entry);
    }

    if (event.eventKind === "impression") {
      entry.impressions += 1;
    } else {
      entry.clicks += 1;
    }
  }

  computeCtrMetrics(): readonly ToolCtrMetric[] {
    const metrics: ToolCtrMetric[] = [];
    for (const entry of this.counters.values()) {
      metrics.push({
        actionType: entry.actionType,
        generatedLabel: entry.generatedLabel,
        impressions: entry.impressions,
        clicks: entry.clicks,
        ctr: calculateCtr(entry.impressions, entry.clicks),
      });
    }
    return metrics.sort((a, b) => {
      if (a.actionType !== b.actionType) {
        return a.actionType.localeCompare(b.actionType);
      }
      return a.generatedLabel.localeCompare(b.generatedLabel);
    });
  }

  buildPruningReport(
    minImpressions = 20,
    minCtrThreshold = 0.02,
  ): SchemaPruningReport {
    const metrics = this.computeCtrMetrics();
    const candidates: SchemaPruningCandidate[] = [];
    const prunedSet = new Set<string>();

    for (const item of metrics) {
      if (
        item.impressions >= minImpressions &&
        item.ctr < minCtrThreshold
      ) {
        prunedSet.add(item.actionType);
        candidates.push({
          actionType: item.actionType,
          generatedLabel: item.generatedLabel,
          impressions: item.impressions,
          clicks: item.clicks,
          ctr: item.ctr,
          reason:
            `ctr ${item.ctr} < ${minCtrThreshold} ` +
            `over ${item.impressions} impressions`,
        });
      }
    }

    return {
      minImpressions,
      minCtrThreshold,
      totalPairs: metrics.length,
      prunedActionTypes: [...prunedSet].sort(),
      candidates,
    };
  }
}
