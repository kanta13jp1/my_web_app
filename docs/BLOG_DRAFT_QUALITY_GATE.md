# Blog Draft Quality Gate

Issue: #1302

The blog automation now runs a deterministic quality gate before generated
drafts are committed and again before any publish request reaches
`schedule-hub`.

## Gate Checks

- Minimum compact character count: 800 for Japanese drafts, 1200 for English drafts.
- Required structure: at least two `##` sections.
- Duplicate detection: exact normalized title matches and high body similarity are blocked against `docs/blog-drafts/` and `docs/blog/`.
- Traceability: every run must provide a `TRACE_ID` and `GITHUB_SHA`; the gate writes a JSON report containing the draft SHA-256, source ref, and recent git commits.

## Failure Behavior

`scripts/validate_blog_draft.py` exits non-zero on failure, writes a JSON report
under `tmp/blog-quality/`, and emits GitHub Actions error annotations. That stops:

- `blog-draft.yml` before committing low-quality drafts.
- `blog-publish.yml` before `blog.create` or `blog.auto_publish` can run.

## Local Verification

```bash
python scripts/validate_blog_draft.py \
  --draft docs/blog-drafts/example.md \
  --language ja \
  --trace-id local-blog-quality-check \
  --source-ref HEAD \
  --report tmp/blog-quality/local.json
```
