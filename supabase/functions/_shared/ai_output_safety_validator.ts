export type SafetyViolationCategory =
  | "csae"
  | "self_harm"
  | "illicit_drugs"
  | "cyber_attack"
  | "violence";

export const SAFETY_CATEGORY_LABELS = {
  csae: "Child Sexual Abuse and Exploitation",
  self_harm: "Self-Harm or Suicide Instruction",
  illicit_drugs: "Illicit Drug Manufacturing or Trafficking",
  cyber_attack: "Cyberattack or Malware Exploitation",
  violence: "Severe Violence or Weapons Instruction",
} as const satisfies Record<SafetyViolationCategory, string>;

export interface SourceReference {
  sourceId: string;
  text: string;
}

export interface QuoteOverlapFinding {
  sourceId: string;
  wordCount: number;
  quoteCount: number;
  excerpt: string;
}

export interface DryRunIssueAlertPayload {
  title: string;
  labels: string[];
  body: string;
  dryRun: true;
}

export interface AiOutputValidationOptions {
  maxWordsPerQuote?: number;
  maxQuotesPerSource?: number;
  minQuoteWordsForCount?: number;
}

export interface AiOutputValidationResult {
  allowed: boolean;
  blockedCategories: SafetyViolationCategory[];
  quoteViolations: QuoteOverlapFinding[];
  issueAlertPayload: DryRunIssueAlertPayload | null;
}

const CATEGORY_PATTERNS: Record<SafetyViolationCategory, RegExp[]> = {
  csae: [
    /\bchild\s+sexual\b/i,
    /\bcsam\b/i,
    /児童性的虐待/,
  ],
  self_harm: [
    /\bhow\s+to\s+commit\s+suicide\b/i,
    /\bself[-\s]?harm\s+instructions\b/i,
    /自殺の方法/,
  ],
  illicit_drugs: [
    /\bsynthesize\s+methamphetamine\b/i,
    /\bhow\s+to\s+cook\s+meth\b/i,
    /違法薬物の製造/,
  ],
  cyber_attack: [
    /\bransomware\s+payload\b/i,
    /\bcredential\s+harvesting\s+kit\b/i,
    /ランサムウェアの作り方/,
  ],
  violence: [
    /\bbuild\s+an\s+improvised\s+explosive\b/i,
    /\bpipe\s+bomb\s+instructions\b/i,
    /爆発物の製造方法/,
  ],
};

function splitNormalizedWords(rawText: string): string[] {
  const normalized = rawText
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s]+/gu, " ")
    .trim();
  if (normalized.length === 0) {
    return [];
  }
  return normalized.split(/\s+/);
}

function findVerbatimMatches(
  outputWords: string[],
  sourceWords: string[],
  minLen: number,
): Array<{ length: number; excerpt: string }> {
  if (outputWords.length < minLen || sourceWords.length < minLen) {
    return [];
  }

  const matches: Array<{ length: number; excerpt: string }> = [];
  let i = 0;
  while (i <= outputWords.length - minLen) {
    let bestLen = 0;
    for (let j = 0; j <= sourceWords.length - minLen; j++) {
      let k = 0;
      while (
        i + k < outputWords.length &&
        j + k < sourceWords.length &&
        outputWords[i + k] === sourceWords[j + k]
      ) {
        k += 1;
      }
      if (k > bestLen) {
        bestLen = k;
      }
    }
    if (bestLen >= minLen) {
      matches.push({
        length: bestLen,
        excerpt: outputWords.slice(i, i + Math.min(bestLen, 20)).join(" "),
      });
      i += bestLen;
    } else {
      i += 1;
    }
  }
  return matches;
}

export function buildDryRunIssueAlertPayload(
  blockedCategories: SafetyViolationCategory[],
  quoteViolations: QuoteOverlapFinding[],
): DryRunIssueAlertPayload {
  const lines = [
    "## AI Output Copyright & Safety Validation Alert (Dry-Run)",
    "",
    `- Blocked safety categories: ${
      blockedCategories.length === 0 ? "none" : blockedCategories.join(", ")
    }`,
    `- Quote overlap violations: ${quoteViolations.length}`,
  ];
  for (const finding of quoteViolations) {
    lines.push(
      `  - source=${finding.sourceId} words=${finding.wordCount} ` +
        `quotes=${finding.quoteCount}`,
    );
  }
  return {
    title: "[security][ai-guard] AI出力の著作権・安全性バリデーション検知",
    labels: ["security", "automation"],
    body: lines.join("\n"),
    dryRun: true,
  };
}

export function validateAiOutput(
  outputText: string,
  sources: SourceReference[] = [],
  options: AiOutputValidationOptions = {},
): AiOutputValidationResult {
  const maxWordsPerQuote = options.maxWordsPerQuote ?? 15;
  const maxQuotesPerSource = options.maxQuotesPerSource ?? 1;
  const minQuoteWordsForCount = options.minQuoteWordsForCount ?? 6;

  const blockedCategories: SafetyViolationCategory[] = [];
  for (
    const category of Object.keys(
      CATEGORY_PATTERNS,
    ) as SafetyViolationCategory[]
  ) {
    const patterns = CATEGORY_PATTERNS[category];
    if (patterns.some((pattern) => pattern.test(outputText))) {
      blockedCategories.push(category);
    }
  }

  const outputWords = splitNormalizedWords(outputText);
  const quoteViolations: QuoteOverlapFinding[] = [];

  for (const source of sources) {
    const sourceWords = splitNormalizedWords(source.text);
    const matches = findVerbatimMatches(
      outputWords,
      sourceWords,
      minQuoteWordsForCount,
    );
    const maxMatchedWords = matches.reduce(
      (max, item) => Math.max(max, item.length),
      0,
    );
    if (
      maxMatchedWords > maxWordsPerQuote ||
      matches.length > maxQuotesPerSource
    ) {
      quoteViolations.push({
        sourceId: source.sourceId,
        wordCount: maxMatchedWords,
        quoteCount: matches.length,
        excerpt: matches[0]?.excerpt ?? "",
      });
    }
  }

  const allowed =
    blockedCategories.length === 0 && quoteViolations.length === 0;
  const issueAlertPayload = allowed
    ? null
    : buildDryRunIssueAlertPayload(blockedCategories, quoteViolations);

  return {
    allowed,
    blockedCategories,
    quoteViolations,
    issueAlertPayload,
  };
}
