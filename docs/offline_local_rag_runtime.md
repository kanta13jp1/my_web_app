# Offline Local RAG Runtime

This project cannot make a hosted Supabase Edge Function read files from a
user's PC. Offline secure RAG therefore uses a local loopback runtime:

- Flutter stores the local model path, vector DB path, and runtime URL.
- Edge LLM Playground routes to `http://127.0.0.1:8765/rag` when offline secure
  mode blocks external APIs and both local paths are configured.
- The hosted `ai-hub` function continues to block external provider fetches and
  returns `offline_blocked=true` / `localRuntimePending` when a browser or other
  caller still reaches the cloud boundary.

## Start The Runtime

Create a local corpus directory and a local model marker or actual model file:

```powershell
New-Item -ItemType Directory -Force C:\rag\lancedb | Out-Null
Set-Content C:\rag\lancedb\policy.md "Offline secure mode answers from local documents only."
Set-Content C:\models\pleias-rag.gguf "replace with a real local model file"
python scripts\local_rag_runtime.py --serve `
  --model-path C:\models\pleias-rag.gguf `
  --vector-db-path C:\rag\lancedb `
  --memory-limit-mb 8192 `
  --enforce-network-block
```

Then set the app's offline secure mode values:

- Local model path: `C:\models\pleias-rag.gguf`
- Local vector DB path: `C:\rag\lancedb`
- Local RAG runtime URL: `http://127.0.0.1:8765/rag`
- External API blocking: on

## Validation

One-shot validation without starting the HTTP server:

```powershell
python scripts\local_rag_runtime.py `
  --query "How does offline secure mode answer?" `
  --model-path C:\models\pleias-rag.gguf `
  --vector-db-path C:\rag\lancedb `
  --memory-limit-mb 8192 `
  --enforce-network-block
```

Expected success contract:

- `success=true`
- `offline_only=true`
- `network_blocked=true`
- `memory_peak_mb <= 8192`
- `citations` contains at least one local source

Expected safe failure contract:

- missing model path returns `success=false` and `status=missingModel`
- missing vector DB path returns `success=false`
- the app does not fall back to external providers while external API blocking
  is enabled

## Pleias Citation Token Contract

The Edge LLM Playground and `local_rag_runtime` interoperate via two equivalent
citation token formats. Both must round-trip through
`parsePleiasCitationText` in `lib/services/local_rag_runtime_service.dart`
(see Issue #1263 / PR #1709).

### Request payload (Flutter -> runtime)

The Flutter client always sends:

| Field                     | Value                            | Why                                           |
|---------------------------|----------------------------------|-----------------------------------------------|
| `temperature`             | `0`                              | Determinism for citation re-binding tests     |
| `include_citations`       | `true`                           | Asks the runtime to attach `citations[]`      |
| `citation_token_format`   | `pleias_source_start_end`        | Selects the native span format below          |

`temperature: 0` is fixed in both `EdgeLlmPlaygroundService` and
`LocalRagRuntimeService`. Do not expose a UI knob for it without an Issue.

### Format A: native Pleias span tokens (preferred)

```
<|source_start|>{source_id}<|source_end|>{cited_text}{close_token}
```

- `{source_id}` is the trimmed ID between the start and end markers.
- `{cited_text}` is the verbatim quoted span shown to the user.
- `{close_token}` is any of: `<|/source|>` / `<|source_close|>` /
  `<|source_stop|>` / `<|source_finish|>`. The parser accepts whichever the
  runtime emits first.
- If no close token is found, the parser degrades to a marker-only chip and
  preserves the source ID. No external content is ever fabricated.

Example: `Answer <|source_start|>doc-1<|source_end|>quoted fact<|/source|> done`.

### Format B: legacy bracket markers

```
[source:{N}]
```

- Whitespace tolerant (`[source: 1]` works) -- regex `\[source\s*:\s*([^\]]+)\]`.
- The marker stays visible in the output as a pill chip (no surrounding text
  is consumed). Use this format when the runtime cannot delimit a span.

### Source ID resolution (4-step fallback)

`PleiasCitationText._resolveCitation()` resolves a parsed `sourceId` against
the `citations[]` array using:

1. Exact match (case-insensitive, trimmed) on `citation.source_id`.
2. Numeric `N` -> `citations[N-1]` (1-indexed; out-of-range returns null).
3. Prefix variants: `doc-{N}` / `source-{N}` / any `*-{N}` suffix match.
4. Otherwise the chip renders with tooltip `source:{ID}` and the dialog
   reports "No source metadata was returned." -- never fabricates a citation.

### UI rendering rules

| Segment kind     | Visual                                                       |
|------------------|--------------------------------------------------------------|
| native span      | Each whitespace token wrapped in a `Tooltip` + `GestureDetector`, with cited background (`#CCFBF1` light / `#134E4A` dark). |
| bracket marker   | Single inline `DecoratedBox` pill carrying `[source:N]` text plus the same tooltip + dialog. `key: ValueKey('pleias-citation-marker-{ID}')` for E2E. |
| source chip rail | Below the text, an `ActionChip` per resolved citation showing `title` or `sourceId`. |

Tooltip lines (newline-joined): `title` / `snippet` / `path` / `score X.XX`.
Empty fields are omitted; missing `score` (== 0) is hidden too.

### Adding a new runtime token format

If a future Pleias / llama.cpp / Ollama build emits a different envelope (for
example a JSON-only payload with `{"citations":[{"text":..,"id":..}]}` or
URL+line-number citations), update both:

1. `parsePleiasCitationText` -- add the parse branch and a unit test in
   `test/services/local_rag_runtime_service_test.dart`.
2. The `citation_token_format` request field -- if a new selector is needed,
   keep `pleias_source_start_end` as the default and append a new constant.

Do not silently change the parser default: doing so flips citation rendering
for every existing run captured in the playground history.

## UAT Playbook (#1719)

The acceptance criteria for #1719 require a live browser UAT after the parser
and payload contracts above are settled. Run this playbook against
`flutter run -d chrome` (and a mobile-width window) on the merged change:

### A. Citation chip interactions

1. Open Edge LLM Playground.
2. Ask any question that triggers Pleias-style citations (or paste a fixture
   answer like `Common Corpus [source:1] for traceable RAG.`).
3. Hover a citation chip -- tooltip must surface `title`, `snippet`, `path`,
   and `score X.XX` on separate lines, all selectable from the dialog.
4. Click a citation chip -- the `AlertDialog` must show the same metadata
   plus a Close button. Pressing Close must restore focus to the chip.
5. Repeat with the source rail `ActionChip` below the answer; the dialog
   must be identical to the inline-marker dialog for the same source ID.

### B. Layout matrix (desktop / mobile)

| Width | Citation text length | Expected behavior                              |
|-------|----------------------|------------------------------------------------|
| 1440  | short snippet        | Answer + chip rail fit on a single row.        |
| 1024  | long path (>120 ch)  | Tooltip wraps; ActionChip truncates with "...".|
| 768   | long title (>80 ch)  | ActionChip wraps to next line, no overflow.    |
| 414   | very long snippet    | Tooltip stays on screen; dialog content scrolls. |
| 360   | many citations (>=8) | Wrap rail flows to multiple rows, no clipping. |

Fail conditions: any horizontal scrollbar, any chip text clipped without
ellipsis, any tooltip clipped by viewport, any dialog wider than the screen.

### C. Edge-case fixtures

Drive these inputs through the playground to exercise parser branches:

1. Span token only: `<|source_start|>doc-1<|source_end|>quoted fact<|/source|>`.
2. Bracket marker only: `Pleias created Common Corpus [source:1] for traceable RAG.`.
3. Mixed input: `<|source_start|>doc-1<|source_end|>fact one<|/source|> and [source:2] continues.`.
4. Missing close token: `<|source_start|>doc-1<|source_end|>fact without close`.
5. Unresolved ID: `[source:999]` with a 1-element `citations[]` -- chip should
   still render and the dialog must say "No source metadata was returned.".
6. Whitespace-loose marker: `[source:  doc-1  ]` -- normalized to `doc-1`.
7. Numeric resolution: `[source:1]` with `citations[0].source_id == 'doc-1'` --
   chip resolves to `doc-1` via the prefix fallback.

### D. Runtime token-format probe (real model)

Once a real Pleias / llama.cpp / Ollama runtime is connected:

1. Send a probe query (`temperature: 0`, `include_citations: true`).
2. Capture the raw response body. Confirm one of:
   - `<|source_start|>...<|source_end|>...<|/source|>` (or alias close token), or
   - `[source:N]` markers with a `citations[]` field, or
   - A new envelope -- in which case open a follow-up Issue and reference
     "Adding a new runtime token format" above.
3. Record the observation in this section as a dated bullet so the contract
   stays grounded in real runtime output.

### E. Sign-off

After UAT, comment on #1263 with:

- Browser + viewport matrix executed (A/B/C above).
- Real-runtime token format observed (D).
- Any deviation from the contract documented in this file.
- The `flutter analyze` / `flutter test` invocation used for verification.

## Current Limit

The bundled Python runtime is a deterministic offline extractive RAG harness.
It validates the local-only transport, citation contract, and 8GB memory gate.
Replacing the answer builder with a real Pleias/llama.cpp/Ollama command is the
next production hardening step for real generative local inference.
