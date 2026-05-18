# Internal AI Model Bench Verdict

Last updated: 2026-05-18

## Current State

No live provider run has been recorded yet. The project therefore has no
task-specific winner and no fixed strongest-model conclusion.

Latest source-only evidence snapshot:
`docs/ai-bench/results/20260518_source_recheck.md`.

## Routing Rule

- `#2521` routing defaults must cite a scored `scripts/internal_ai_bench.py`
  report, or remain behind a feature flag.
- Provider live runs require explicit operator approval because they may use
  paid APIs and provider credentials.
- SNS-only model claims stay unranked until an official or primary source is
  attached to the bench input.

## Next Evidence Needed

1. Recheck current official model sources:

   ```powershell
   python scripts/internal_ai_bench_source_recheck.py `
     --input docs/ai-bench/results/template.json `
     --output-json docs/ai-bench/results/source_recheck.json `
     --output-md docs/ai-bench/results/source_recheck.md `
     --strict
   ```

   This step is also available as the `AI Bench Source Recheck` workflow. It is
   source-only and does not use provider API keys.

2. Generate a dry-run provider manifest:

   ```powershell
   python scripts/internal_ai_bench_provider_manifest.py `
     --input docs/ai-bench/results/template.json `
     --output-json docs/ai-bench/results/provider_manifest.json `
     --output-md docs/ai-bench/results/provider_manifest.md `
     --strict
   ```

3. Recheck official model ids, pricing, context limits, and thinking/tool-use
   parameters immediately before any live provider execution.
4. Run B1/B2/B3/R1 against synthetic repository fixtures only.
5. Normalize results with `scripts/internal_ai_bench.py` and attach the Markdown
   report to `#2520`.

## Interim Verdict

Keep the existing asset-management AI routing conservative. Evidence collection
is ready, but live scoring and production routing changes are not complete.
