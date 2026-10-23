# Evernote OCR and Attachment Search Implementation

Status: implementation contract; no production OCR provider is enabled by this
document.

## Goal

Preserve every searchable signal already present in an Evernote export and make
images, scanned PDFs, handwritten text, and supported documents searchable
without loading an archive or an attachment fully into Windows memory.

This feature is part of the Evernote deletion gate. A migrated batch is not
eligible for source deletion while any searchable attachment is missing,
unverified, or irrecoverable.

## Authoritative Evernote Behavior

Evernote's current search behavior establishes these parity requirements:

- printed and handwritten text inside images is searchable;
- printed and handwritten text inside scanned PDFs is searchable;
- text inside PDFs, Microsoft Office files, images, presentations, and scanned
  documents participates in search;
- Evernote currently processes PDFs up to 52 MB per file for search;
- normal search is case-insensitive, ignores punctuation, and supports prefix
  matches from the start of a word;
- `resource:` and `contains:` filters distinguish PDFs, images, Office
  documents, presentations, spreadsheets, audio, and other content types;
- semantic search can use OCR text from attachments.

Legacy Evernote recognition data is not just plain text. A `recoIndex` contains
document and engine metadata, rectangular regions, multiple candidate terms,
and a weight for every candidate. ENEX exports may preserve this XML. That
information must be imported before any new OCR is considered.

Official references:

- https://help.evernote.com/hc/en-us/articles/360040282613-Search-overview
- https://help.evernote.com/hc/en-us/articles/37423805275539-If-scanned-PDFs-are-not-appearing-in-your-search-results
- https://help.evernote.com/hc/en-us/articles/222177927-Capture-handwriting-and-scan-documents-with-your-phone
- https://help.evernote.com/hc/en-us/articles/208313828-Use-advanced-search-syntax
- https://dev.evernote.com/pt-br/legacy/doc/articles/image_recognition
- https://xml.evernote.com/pub/recoIndex.dtd

## Non-negotiable Boundaries

- ENEX, PDFs, images, Office files, and OCR output never enter GitHub, GitHub
  Actions artifacts, or application logs.
- The browser or desktop client streams the selected archive directly to a
  private Supabase Storage bucket with bounded resumable chunks.
- The client never receives a service-role key.
- Every table in an exposed schema has RLS and an owner predicate.
- Queue internals are not exposed to the Data API.
- An OCR provider that charges money or sends content to a new third party is
  not enabled without a separate privacy, region, retention, and cost decision.
- Source deletion and subscription cancellation remain manual approval gates.

## Source Priority

For each immutable attachment version, use the first trustworthy source below:

1. **Evernote recognition** — import ENEX `recognition` / `recoIndex` data.
2. **Embedded document text** — extract an existing PDF or Office text layer.
3. **Cloud OCR** — process only when the first two sources are absent,
   malformed, or below the configured quality threshold.
4. **Manual review** — required for encrypted files, unsupported formats,
   corrupt content, or repeated extraction failure.

Re-running paid or probabilistic OCR for an attachment that already has valid
Evernote recognition is wasteful and can reduce fidelity. Preserve the original
recognition payload even when a newer extraction is also created.

## Recognition Import

The streaming ENEX parser must handle recognition data inside each resource
without buffering the entire note or archive.

For every `recoIndex`:

- disable DTD retrieval, external entities, XInclude, and all network access;
- accept the known element and attribute allowlist only;
- record `docType`, `objType`, `objID`, `engineVersion`, `recoType`,
  language, width, and height;
- preserve every region's `x`, `y`, `w`, and `h`;
- preserve every candidate term and its weight in descending order;
- retain the raw XML as a private evidence object, addressed by SHA-256;
- derive a normalized search document from all valid candidates;
- use the highest-weight candidate for default display, without discarding
  lower-weight candidates used for matching.

Malformed recognition XML must not abort attachment or note migration. Record a
structured error, retain the original bytes, and enqueue that attachment for
safe re-extraction.

## Durable Data Model

The migration implementation should expose typed application models for these
logical records. Physical table names may follow the repository's existing
migration conventions.

### Attachment extraction

One row per immutable attachment hash and extraction version:

- owner/user ID;
- note, attachment, migration batch, and source archive IDs;
- attachment SHA-256, MIME type, byte size, and Storage object key;
- source: `evernote_reco_index`, `embedded_text`, or `cloud_ocr`;
- engine/provider name and version;
- status: `queued`, `running`, `succeeded`, `needs_review`, or `failed`;
- language hints and detected languages;
- normalized plain text and searchable text;
- raw evidence object key and SHA-256;
- attempt count, retry time, error code, and timestamps;
- verification status and verifier version.

A uniqueness constraint on owner, attachment SHA-256, source, and engine version
makes retries idempotent.

### Recognition regions

One row per region, or a bounded JSON representation when that is demonstrably
more efficient:

- extraction ID and page/frame number;
- normalized and source pixel coordinates;
- ordered candidates with integer weights;
- selected display candidate;
- optional script and language.

### Search projection

The note search projection combines title, body, tags, imported OCR candidates,
embedded document text, and permitted semantic-search text. Updating an
attachment extraction must deterministically refresh only the owning note's
projection.

Japanese and other scripts must not depend solely on English-oriented Postgres
stemming. Normalization and tokenization require language-aware tests. Prefix
matching must agree with the main Evernote search grammar implementation.

## Cloud Processing Flow

```text
private Storage object
        |
        v
attachment manifest + SHA verification
        |
        +--> valid Evernote recoIndex --> parse safely --> index
        |
        +--> embedded PDF/Office text --> normalize ------> index
        |
        +--> no trustworthy text --> durable OCR queue
                                      |
                                      v
                              isolated cloud worker
                                      |
                                      v
                         evidence + regions + index
                                      |
                                      v
                          migration ledger verification
```

Use a durable Supabase Queue for OCR jobs. The authenticated request path only
verifies ownership and enqueues an idempotent job. It does not expose
`pgmq_public` to browsers.

`EdgeRuntime.waitUntil` may complete a short enqueue or metadata update, but it
must not be the only owner of a long PDF/Office/OCR job. Edge Functions have
wall-clock, CPU, and memory limits. A consumer must checkpoint each attachment
and page so a worker termination cannot lose progress.

A queue message contains identifiers, object keys, hashes, MIME type, requested
engine version, and trace ID only. It does not contain attachment bytes, note
text, signed URLs, or credentials.

Current Supabase references:

- https://supabase.com/docs/guides/queues
- https://supabase.com/docs/guides/functions/background-tasks
- https://supabase.com/docs/guides/storage/buckets/fundamentals
- https://supabase.com/docs/guides/storage/security/access-control
- https://supabase.com/docs/guides/storage/security/ownership

The 2026 Supabase platform change that stops automatically exposing new public
tables must be handled explicitly: decide which records need the Data API,
grant only those roles, and keep internal queue/evidence tables unexposed.

## Content Routing

At minimum, classify attachments using both a trusted MIME value and magic-byte
inspection.

- image: OCR when no valid Evernote recognition exists;
- PDF with trustworthy text layer: extract text;
- image-only or unusable-text PDF: OCR page by page;
- Office document/presentation/spreadsheet: sandboxed text extraction;
- encrypted document: `needs_review`, never brute-force;
- archive or unsupported binary: preserve and expose `resource:` /
  `contains:` filtering without claiming text-search parity;
- attachment larger than the configured limit: preserve it and report a clear
  search-index status. The compatibility report must identify whether it
  exceeds Evernote's current 52 MB PDF search limit.

Extraction runs in an isolated worker with byte, page, pixel, decompression,
CPU, and time limits. Reject polyglots, decompression bombs, recursive archives,
and MIME mismatches before invoking a parser.

## Search and UI Contract

Search results must:

- match OCR and embedded-document terms through the same Boolean/advanced
  grammar as note text;
- support case folding, punctuation normalization, phrase matching, and
  start-of-word prefixes;
- support `resource:` and `contains:` filters even when OCR is pending;
- indicate whether a hit came from the note, an attachment, or OCR;
- open the owning note and identify the matching attachment;
- highlight a region when coordinates exist;
- display processing, retrying, failed, and needs-review states;
- never reveal extraction text from a note the caller cannot read.

Semantic search may consume verified extraction text later. Exact search parity
and access control are required before semantic indexing is enabled.

## Verification Matrix

Cloud CI and staging must cover:

1. synthetic ENEX with typed and handwritten `recoIndex` candidates;
2. preservation of coordinates, ordering, weights, metadata, and raw XML hash;
3. external-entity and network-resolution attempts;
4. malformed/truncated recognition XML with safe fallback;
5. duplicate events and retries proving one logical extraction;
6. digital PDF, image-only PDF, garbled hidden-text PDF, and the 52 MB boundary;
7. JPEG/PNG rotation and high-pixel-count limits;
8. encrypted and corrupt documents;
9. Office document, spreadsheet, and presentation extraction;
10. Japanese, Latin, numbers, punctuation, phrases, and prefix matching;
11. cross-user RLS denial for rows, raw evidence, and attachments;
12. worker termination and checkpointed resume;
13. recovery export and re-import preserving searchable evidence;
14. a negative check proving no personal archive or OCR text is uploaded as a
    GitHub artifact.

## Migration and Deletion Gate

An attachment is verified only when:

- source and destination SHA-256 values match;
- resource metadata and byte counts match;
- imported recognition evidence is preserved, or a replacement extraction is
  complete and explicitly recorded;
- exact-search probes return the owning note;
- recovery export contains sufficient evidence to rebuild the index;
- all failures are resolved or explicitly accepted for that attachment.

A batch may become `eligible_for_source_delete` only when every attachment and
note in that batch passes its verifier. Eligibility is not permission. The UI
must show the evidence summary and obtain fresh explicit approval before the
corresponding Evernote notes are deleted.
