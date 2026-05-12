import { SupabaseClient } from "npm:@supabase/supabase-js@2";

export interface VectorMatch {
  file_path: string;
  title: string | null;
  content: string;
  snippet: string | null;
  metadata: Record<string, unknown> | null;
  score: number;
  match_reason: string;
}

const EMBEDDING_DIMENSION = 768;

function normalizeEmbedding(values: number[]): number[] {
  const magnitude = Math.sqrt(
    values.reduce((sum, value) => sum + value * value, 0),
  );
  if (magnitude <= 0) return values;
  return values.map((value) => value / magnitude);
}

export async function embedTextWithGemini(
  text: string,
  apiKey: string,
): Promise<number[]> {
  const response = await fetch(
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:batchEmbedContents",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        requests: [{
          model: "models/gemini-embedding-001",
          content: { parts: [{ text: text.slice(0, 3500) }] },
          taskType: "RETRIEVAL_QUERY",
          outputDimensionality: EMBEDDING_DIMENSION,
        }],
      }),
    },
  );

  if (!response.ok) {
    const raw = await response.text();
    throw new Error(
      `Gemini embedding ${response.status}: ${raw.slice(0, 300)}`,
    );
  }

  const data = await response.json() as {
    embeddings?: Array<{ values?: number[] }>;
  };
  const values = data.embeddings?.[0]?.values ?? [];
  if (values.length !== EMBEDDING_DIMENSION) {
    throw new Error(
      `Gemini embedding dimension mismatch: ${values.length} != ${EMBEDDING_DIMENSION}`,
    );
  }
  return normalizeEmbedding(values);
}

export async function vectorSearch(
  client: SupabaseClient,
  query: string,
  limit = 20,
): Promise<VectorMatch[]> {
  const apiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
  if (!apiKey) return [];

  const embedding = await embedTextWithGemini(query, apiKey);
  if (embedding.length === 0) return [];

  const { data, error } = await client.rpc("match_memory_index", {
    query_embedding: embedding,
    match_count: limit,
    match_threshold: 0.05,
  });
  if (error) throw error;

  return ((data ?? []) as Array<Record<string, unknown>>).map((row) => ({
    file_path: String(row.file_path ?? ""),
    title: row.title == null ? null : String(row.title),
    content: String(row.content ?? ""),
    snippet: row.snippet == null ? null : String(row.snippet),
    metadata: (row.metadata && typeof row.metadata === "object")
      ? row.metadata as Record<string, unknown>
      : null,
    score: Number(row.score ?? 0),
    match_reason: "vector",
  })).filter((row) => row.file_path !== "");
}
