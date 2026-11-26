export type PromptChangeSeverity = "breaking" | "additive" | "metadata";

export const PROMPT_CHANGE_LABELS = {
  breaking: "Breaking Prompt Contract Change",
  additive: "Additive Prompt Capability",
  metadata: "Metadata or Whitespace Only",
} as const satisfies Record<PromptChangeSeverity, string>;

export interface RawPromptSnapshot {
  provider: string;
  modelName: string;
  versionTag: string;
  capturedAtIso: string;
  sections: Record<string, string>;
  verificationStatus?: string;
}

export interface NormalizedPromptSnapshot {
  provider: string;
  modelName: string;
  versionTag: string;
  capturedAtIso: string;
  sections: Record<string, string>;
  contentDigest: string;
  verificationStatus: string;
}

export interface PromptSectionDiff {
  sectionName: string;
  changeKind: "added" | "removed" | "modified";
}

export interface PromptHistoryDiffResult {
  severity: PromptChangeSeverity;
  changed: boolean;
  addedSections: string[];
  removedSections: string[];
  modifiedSections: string[];
  sectionDiffs: PromptSectionDiff[];
}

export interface DryRunInvestigationIssuePayload {
  title: string;
  labels: string[];
  body: string;
  dryRun: true;
}

function normalizeTextValue(value: string): string {
  return value.replace(/\r\n/g, "\n").trim();
}

function fnv1aHex(rawText: string): string {
  let hash = 0x811c9dc5;
  for (let i = 0; i < rawText.length; i++) {
    hash ^= rawText.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash.toString(16).padStart(8, "0");
}

export function normalizePromptSnapshot(
  rawSnapshot: RawPromptSnapshot,
): NormalizedPromptSnapshot {
  const provider = rawSnapshot.provider.trim().toLowerCase();
  const modelName = rawSnapshot.modelName.trim();
  const versionTag = rawSnapshot.versionTag.trim();
  const parsedDate = new Date(rawSnapshot.capturedAtIso);
  if (Number.isNaN(parsedDate.getTime())) {
    throw new TypeError("capturedAtIso must be a valid ISO timestamp");
  }

  const sortedKeys = Object.keys(rawSnapshot.sections).sort();
  const sections: Record<string, string> = {};
  for (const key of sortedKeys) {
    const cleanKey = key.trim();
    if (cleanKey.length > 0) {
      sections[cleanKey] = normalizeTextValue(rawSnapshot.sections[key]);
    }
  }

  const digestSource = JSON.stringify({
    provider,
    modelName,
    versionTag,
    sections,
  });

  return {
    provider,
    modelName,
    versionTag,
    capturedAtIso: parsedDate.toISOString(),
    sections,
    contentDigest: fnv1aHex(digestSource),
    verificationStatus: rawSnapshot.verificationStatus?.trim() || "未確認",
  };
}

export function diffPromptSnapshots(
  previousSnapshot: NormalizedPromptSnapshot,
  currentSnapshot: NormalizedPromptSnapshot,
): PromptHistoryDiffResult {
  const prevKeys = new Set(Object.keys(previousSnapshot.sections));
  const currKeys = new Set(Object.keys(currentSnapshot.sections));

  const addedSections: string[] = [];
  const removedSections: string[] = [];
  const modifiedSections: string[] = [];
  const sectionDiffs: PromptSectionDiff[] = [];

  for (const key of Array.from(currKeys).sort()) {
    if (!prevKeys.has(key)) {
      addedSections.push(key);
      sectionDiffs.push({ sectionName: key, changeKind: "added" });
    } else if (
      previousSnapshot.sections[key] !== currentSnapshot.sections[key]
    ) {
      modifiedSections.push(key);
      sectionDiffs.push({ sectionName: key, changeKind: "modified" });
    }
  }

  for (const key of Array.from(prevKeys).sort()) {
    if (!currKeys.has(key)) {
      removedSections.push(key);
      sectionDiffs.push({ sectionName: key, changeKind: "removed" });
    }
  }

  let severity: PromptChangeSeverity = "metadata";
  if (removedSections.length > 0 || modifiedSections.length > 0) {
    severity = "breaking";
  } else if (addedSections.length > 0) {
    severity = "additive";
  }

  return {
    severity,
    changed: sectionDiffs.length > 0,
    addedSections,
    removedSections,
    modifiedSections,
    sectionDiffs,
  };
}

export function buildInvestigationIssuePayload(
  diff: PromptHistoryDiffResult,
  currentSnapshot: NormalizedPromptSnapshot,
): DryRunInvestigationIssuePayload | null {
  if (!diff.changed) {
    return null;
  }

  const lines = [
    "## AI System Prompt Release Investigation (Dry-Run)",
    "",
    `- Provider / Model: ${currentSnapshot.provider} / ` +
      `${currentSnapshot.modelName}`,
    `- Version: ${currentSnapshot.versionTag}`,
    `- Severity: ${diff.severity} (${PROMPT_CHANGE_LABELS[diff.severity]})`,
    `- Verification Status: ${currentSnapshot.verificationStatus}`,
    `- Added sections: ${
      diff.addedSections.length === 0 ? "none" : diff.addedSections.join(", ")
    }`,
    `- Removed sections: ${
      diff.removedSections.length === 0
        ? "none"
        : diff.removedSections.join(", ")
    }`,
    `- Modified sections: ${
      diff.modifiedSections.length === 0
        ? "none"
        : diff.modifiedSections.join(", ")
    }`,
  ];

  return {
    title:
      `[prompt-intake] ${currentSnapshot.provider} ` +
      `${currentSnapshot.modelName} ${currentSnapshot.versionTag} 仕様差異調査`,
    labels: ["automation", "notebooklm"],
    body: lines.join("\n"),
    dryRun: true,
  };
}
