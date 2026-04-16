---
title: "Building a Text Similarity Lab with Gemini Embeddings + Flutter Web (Cosine Similarity Visualizer)"
tags: Flutter,GeminiAPI,AI,buildinpublic,webdev
published: true
---

# Building a Text Similarity Lab with Gemini Embeddings + Flutter Web

## The Problem This Solves

"Are these two notes about the same topic?"

Before implementing semantic search in my app [自分株式会社](https://my-web-app-b67f4.web.app/), I wanted to *feel* how Gemini embeddings work — not just use them as a black box. So I built **Embedding Lab**: a dev tool that lets you input any two texts and instantly see their cosine similarity score.

---

## What We Built

Two modes in one page:

1. **Embed mode** — convert any text to a 768-dimension vector, preview the first 10 dimensions
2. **Compare mode** — input two texts, get a cosine similarity score from -1.0 to 1.0 with a color-coded label

---

## The Math: Cosine Similarity

Cosine similarity measures the angle between two vectors regardless of their magnitude:

```
similarity = (A · B) / (||A|| × ||B||)
```

In Dart:

```dart
double _cosineSimilarity(List<double> a, List<double> b) {
  double dot = 0, normA = 0, normB = 0;
  for (int i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  final denom = sqrt(normA) * sqrt(normB);
  return denom == 0 ? 0.0 : dot / denom;
}
```

No packages needed — pure Dart math with `dart:math`'s `sqrt`.

---

## Calling the Gemini Embedding API

`gemini-embedding-001` uses the `embedContent` endpoint:

```dart
Future<List<double>> _fetchEmbedding(String text) async {
  final url = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/'
    'gemini-embedding-001:embedContent',
  );
  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    },
    body: jsonEncode({
      'content': {
        'parts': [{'text': text}],
      },
    }),
  );
  final data = jsonDecode(response.body);
  return (data['embedding']['values'] as List)
      .map((v) => (v as num).toDouble())
      .toList();
}
```

For the two-text comparison, fetch both in parallel:

```dart
final results = await Future.wait([
  _fetchEmbedding(textA),
  _fetchEmbedding(textB),
]);
final score = _cosineSimilarity(results[0], results[1]);
```

`Future.wait` cuts the latency roughly in half versus sequential calls.

---

## The UI: Color-Coded Similarity Meter

The score is shown as a `LinearProgressIndicator` that changes color based on similarity:

```dart
Color _scoreColor(double score) {
  if (score >= 0.85) return Colors.green;
  if (score >= 0.70) return Colors.lightGreen;
  if (score >= 0.50) return Colors.orange;
  return Colors.red;
}

String _scoreLabel(double score) {
  if (score >= 0.85) return 'Very similar';
  if (score >= 0.70) return 'Related';
  if (score >= 0.50) return 'Loosely related';
  return 'Different topics';
}
```

This makes the abstract "0.73" score immediately interpretable.

---

## Real Examples

| Text A | Text B | Score | Label |
|--------|--------|-------|-------|
| "Flutter is a UI framework by Google" | "Dart is a programming language by Google" | 0.91 | Very similar |
| "I went to the gym today" | "Stock markets fell 3% this morning" | 0.12 | Different topics |
| "How to make pasta carbonara" | "Classic Italian recipes" | 0.78 | Related |

The 768-dimension space captures semantic meaning remarkably well. "Flutter" and "Dart" land close together even though they're different products.

---

## Why Build This First

I'm building toward **semantic note search**: when you have hundreds of notes, you want to find "notes about similar topics" even without keyword matches. Embedding Lab is the proof-of-concept that answers:

- Does this model produce useful embeddings for my data?
- What threshold should I use for "related"?
- How much does sentence length affect scores?

Once I had this tool, I could tune the similarity thresholds before writing a single line of `pgvector` code.

---

## Next Steps: pgvector in Supabase

The production path from here:

```sql
-- Enable the extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Add embedding column to notes
ALTER TABLE notes ADD COLUMN embedding vector(768);

-- Similarity search function
CREATE OR REPLACE FUNCTION match_notes(
  query_embedding vector(768),
  match_threshold float DEFAULT 0.75,
  match_count int DEFAULT 10
)
RETURNS TABLE (id uuid, title text, similarity float)
AS $$
  SELECT id, title, 1 - (embedding <=> query_embedding) AS similarity
  FROM notes
  WHERE 1 - (embedding <=> query_embedding) > match_threshold
  ORDER BY embedding <=> query_embedding
  LIMIT match_count;
$$ LANGUAGE sql;
```

The `<=>` operator is cosine distance (1 - similarity). Supabase's `pgvector` extension handles the index automatically.

---

## Key Takeaways

1. **`gemini-embedding-001` returns 768 dimensions** — dense enough for nuanced similarity, lightweight enough for real-time use
2. **`Future.wait` for parallel API calls** — always fetch multiple embeddings concurrently
3. **Build the tool before the feature** — Embedding Lab answered threshold questions that would have been expensive to answer in production
4. **Color-coded thresholds beat raw numbers** — `LinearProgressIndicator` + color makes similarity instantly readable

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #GeminiAPI #AI #webdev
