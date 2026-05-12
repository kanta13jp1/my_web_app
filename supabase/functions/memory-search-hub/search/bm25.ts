export interface MemoryDocument {
  file_path: string;
  title: string | null;
  content: string;
  snippet: string | null;
  updated_at?: string | null;
  metadata?: Record<string, unknown> | null;
}

export interface ScoredMemoryDocument extends MemoryDocument {
  score: number;
  match_reason: string;
}

const K1 = 1.5;
const B = 0.75;

function cjkBigrams(text: string): string[] {
  const chars = Array.from(text).filter((char) =>
    /\p{Script=Han}|\p{Script=Hiragana}|\p{Script=Katakana}/u.test(char)
  );
  const grams: string[] = [];
  for (let i = 0; i < chars.length - 1; i++) {
    grams.push(`${chars[i]}${chars[i + 1]}`);
  }
  return grams;
}

export function tokenize(text: string): string[] {
  const normalized = text.toLowerCase();
  const latin = normalized.match(/[a-z0-9_#.-]{2,}/g) ?? [];
  return [...latin, ...cjkBigrams(normalized)];
}

function documentText(doc: MemoryDocument): string {
  return [doc.title ?? "", doc.file_path, doc.snippet ?? "", doc.content]
    .join("\n")
    .slice(0, 12000);
}

export function buildSnippet(
  doc: MemoryDocument,
  query: string,
  maxChars = 240,
): string {
  const content = (doc.snippet || doc.content || doc.title || doc.file_path)
    .replace(/\s+/g, " ").trim();
  if (content.length <= maxChars) return content;

  const queryToken = tokenize(query)[0] ?? "";
  const idx = queryToken
    ? content.toLowerCase().indexOf(queryToken.toLowerCase())
    : -1;
  const start = idx > 40 ? idx - 40 : 0;
  return `${start > 0 ? "..." : ""}${content.slice(start, start + maxChars)}${
    start + maxChars < content.length ? "..." : ""
  }`;
}

export function rankBm25(
  query: string,
  docs: MemoryDocument[],
  limit = 50,
): ScoredMemoryDocument[] {
  const queryTokens = tokenize(query);
  if (queryTokens.length === 0 || docs.length === 0) return [];

  const termFrequencies = docs.map((doc) => {
    const counts = new Map<string, number>();
    for (const token of tokenize(documentText(doc))) {
      counts.set(token, (counts.get(token) ?? 0) + 1);
    }
    return counts;
  });
  const lengths = termFrequencies.map((tf) =>
    Array.from(tf.values()).reduce((sum, count) => sum + count, 0)
  );
  const avgLength = lengths.reduce((sum, length) => sum + length, 0) /
    Math.max(1, lengths.length);

  const documentFrequency = new Map<string, number>();
  for (const token of new Set(queryTokens)) {
    let count = 0;
    for (const tf of termFrequencies) {
      if (tf.has(token)) count += 1;
    }
    documentFrequency.set(token, count);
  }

  return docs
    .map((doc, index) => {
      const tf = termFrequencies[index];
      const docLength = lengths[index] || 1;
      let score = 0;
      for (const token of queryTokens) {
        const frequency = tf.get(token) ?? 0;
        if (frequency === 0) continue;
        const df = documentFrequency.get(token) ?? 0;
        const idf = Math.log(1 + (docs.length - df + 0.5) / (df + 0.5));
        const denominator = frequency +
          K1 * (1 - B + B * (docLength / avgLength));
        score += idf * ((frequency * (K1 + 1)) / denominator);
      }
      return {
        ...doc,
        score,
        snippet: buildSnippet(doc, query),
        match_reason: "bm25",
      };
    })
    .filter((doc) => doc.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, limit);
}
