# Internal AI Model Bench Verdict

Last updated: 2026-05-18

## Current State

No live provider run has been recorded yet. The project therefore has no
task-specific winner and no fixed strongest-model conclusion.

## Routing Rule

- `#2521` routing defaults must cite a scored `scripts/internal_ai_bench.py`
  report, or remain behind a feature flag.
- Provider live runs require explicit operator approval because they may use
  paid APIs and provider credentials.
- SNS-only model claims stay unranked until an official or primary source is
  attached to the bench input.

## Next Evidence Needed

1. Generate a dry-run provider manifest:

   ```powershell
   python scripts/internal_ai_bench_provider_manifest.py `
     --input docs/ai-bench/results/template.json `
     --output-json docs/ai-bench/results/provider_manifest.json `
     --output-md docs/ai-bench/results/provider_manifest.md `
     --strict
   ```

2. Recheck official model ids, pricing, context limits, and thinking/tool-use
   parameters immediately before any live provider execution.
3. Run B1/B2/B3/R1 against synthetic repository fixtures only.
4. Normalize results with `scripts/internal_ai_bench.py` and attach the Markdown
   report to `#2520`.

## Interim Verdict

Keep the existing asset-management AI routing conservative. Evidence collection
is ready, but live scoring and production routing changes are not complete.
