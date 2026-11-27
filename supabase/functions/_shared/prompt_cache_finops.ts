/**
 * Prompt Cache Prefix Ordering, Batch API Routing & FinOps Telemetry (#2788)
 *
 * Orders static blocks (system prompt, DB schema, few-shot examples) ahead of
 * dynamic user input with `cache_control: { type: "ephemeral" }`, routes
 * non-urgent tasks to the Message Batches API, and tracks cache-hit FinOps.
 */

export type CacheBlockRole =
  | "system_prompt"
  | "db_schema"
  | "few_shot"
  | "user_input";

export type ExecutionUrgency = "realtime" | "batch_eligible";

export type DispatchMode = "messages_api" | "message_batches_api";

export const BLOCK_ROLE_LABELS = {
  system_prompt: "System Prompt",
  db_schema: "DB Schema",
  few_shot: "Few-Shot Examples",
  user_input: "User Input",
} as const satisfies Record<CacheBlockRole, string>;

export const DISPATCH_MODE_LABELS = {
  messages_api: "Messages API (Real-Time)",
  message_batches_api: "Message Batches API (Async)",
} as const satisfies Record<DispatchMode, string>;

const STATIC_ROLE_PRIORITY: Record<CacheBlockRole, number> = {
  system_prompt: 0,
  db_schema: 1,
  few_shot: 2,
  user_input: 3,
};

export interface CacheControlDirective {
  readonly type: "ephemeral";
}

export interface PromptBlockInput {
  readonly role: CacheBlockRole;
  readonly content: string;
  readonly estimatedInputCount: number;
}

export interface OrderedPromptBlock {
  readonly role: CacheBlockRole;
  readonly content: string;
  readonly estimatedInputCount: number;
  readonly cache_control?: CacheControlDirective;
}

export interface PromptPrefixPlan {
  readonly blocks: readonly OrderedPromptBlock[];
  readonly cacheEnabled: boolean;
  readonly staticPrefixCount: number;
  readonly dynamicCount: number;
}

export interface FinopsUsageRecord {
  readonly feature: string;
  readonly dispatchMode: DispatchMode;
  readonly baseInputCount: number;
  readonly cacheReadCount: number;
  readonly cacheCreationCount: number;
  readonly outputCount: number;
}

export interface PromptCacheFinopsSummary {
  readonly totalRequests: number;
  readonly batchRequests: number;
  readonly batchOffloadRate: number;
  readonly totalBaseInputCount: number;
  readonly totalCacheReadCount: number;
  readonly totalCacheCreationCount: number;
  readonly totalOutputCount: number;
  readonly cacheHitRate: number;
}

export function isStaticRole(role: CacheBlockRole): boolean {
  return role !== "user_input";
}

export function selectDispatchMode(urgency: ExecutionUrgency): DispatchMode {
  return urgency === "batch_eligible" ? "message_batches_api" : "messages_api";
}

export function buildPromptCachePrefix(
  inputs: readonly PromptBlockInput[],
  minCacheableCount = 1024,
): PromptPrefixPlan {
  const sorted = [...inputs].sort(
    (a, b) => STATIC_ROLE_PRIORITY[a.role] - STATIC_ROLE_PRIORITY[b.role],
  );

  let staticPrefixCount = 0;
  let dynamicCount = 0;
  let lastStaticIdx = -1;

  for (let i = 0; i < sorted.length; i++) {
    const count = Math.max(0, Math.round(sorted[i].estimatedInputCount));
    if (isStaticRole(sorted[i].role)) {
      staticPrefixCount += count;
      lastStaticIdx = i;
    } else {
      dynamicCount += count;
    }
  }

  const cacheEnabled =
    lastStaticIdx >= 0 && staticPrefixCount >= minCacheableCount;

  const blocks: OrderedPromptBlock[] = sorted.map((item, idx) => {
    const bounded = Math.max(0, Math.round(item.estimatedInputCount));
    if (cacheEnabled && idx === lastStaticIdx) {
      return {
        role: item.role,
        content: item.content,
        estimatedInputCount: bounded,
        cache_control: { type: "ephemeral" },
      };
    }
    return {
      role: item.role,
      content: item.content,
      estimatedInputCount: bounded,
    };
  });

  return {
    blocks,
    cacheEnabled,
    staticPrefixCount,
    dynamicCount,
  };
}

export class PromptCacheFinopsTracker {
  private totalRequests = 0;
  private batchRequests = 0;
  private totalBaseInputCount = 0;
  private totalCacheReadCount = 0;
  private totalCacheCreationCount = 0;
  private totalOutputCount = 0;

  recordUsage(record: FinopsUsageRecord): void {
    this.totalRequests += 1;
    if (record.dispatchMode === "message_batches_api") {
      this.batchRequests += 1;
    }
    this.totalBaseInputCount += Math.max(0, Math.round(record.baseInputCount));
    this.totalCacheReadCount += Math.max(0, Math.round(record.cacheReadCount));
    this.totalCacheCreationCount += Math.max(
      0,
      Math.round(record.cacheCreationCount),
    );
    this.totalOutputCount += Math.max(0, Math.round(record.outputCount));
  }

  getSummary(): PromptCacheFinopsSummary {
    const totalInputDenominator =
      this.totalBaseInputCount +
      this.totalCacheReadCount +
      this.totalCacheCreationCount;

    const cacheHitRate = totalInputDenominator === 0
      ? 0
      : Number((this.totalCacheReadCount / totalInputDenominator).toFixed(4));

    const batchOffloadRate = this.totalRequests === 0
      ? 0
      : Number((this.batchRequests / this.totalRequests).toFixed(4));

    return {
      totalRequests: this.totalRequests,
      batchRequests: this.batchRequests,
      batchOffloadRate,
      totalBaseInputCount: this.totalBaseInputCount,
      totalCacheReadCount: this.totalCacheReadCount,
      totalCacheCreationCount: this.totalCacheCreationCount,
      totalOutputCount: this.totalOutputCount,
      cacheHitRate,
    };
  }
}
