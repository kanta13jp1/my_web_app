# Issue #1264 Query Report Routing

## Goal

Implement the first backend slice for Pleias-style query reports:

- parse query report state from tags, JSON, or line-based metadata
- rerun search with a reformulated query when the report says `reformulated`
- stop retrieval and return a clarification response when the report says
  `unclear`

## Implementation

- Added `supabase/functions/memory-search-hub/query_report.ts` as a pure parser
  and routing decision helper.
- Added `memory.query_route` to `memory-search-hub`.
- Kept `memory.search` behavior unchanged for existing callers.

## Contract

Input:

```json
{
  "action": "memory.query_route",
  "query": "Pleias",
  "query_report": "state: reformulated\nsearch_query: Pleias Open Data Layers enterprise RAG"
}
```

Output:

- `200` with normal memory search results when the route is searchable.
- `422` with `error=query_clarification_required` when the route is unclear.

## Verification

- `deno test --config supabase/functions/deno.json supabase/functions/memory-search-hub/query_report_test.ts`
- `deno check --config supabase/functions/deno.json supabase/functions/memory-search-hub/index.ts`
