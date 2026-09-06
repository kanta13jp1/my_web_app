# Hedra Model Catalog Watch

`Hedra Model Catalog Watch` calls Hedra's official `GET /web-app/public/models`
endpoint once a week and compares a normalized response with the last successful
snapshot.

Official API reference:
https://www.hedra.com/docs/api-reference/public/list-models

## Stored outputs

- `models.json`: the last successfully observed, normalized model catalog. The
  watcher updates it only when the catalog changes, so request timestamps do not
  create false positives.
- `latest-report.json`: counts and structured added, removed, and changed model
  records. Changed records include the affected top-level fields.
- `latest-report.md`: a human-readable summary used for GitHub Issue notices.
- Workflow artifact: all available files above, retained for 90 days as inputs
  to later catalog validation and requirement review.

The first successful run creates a baseline and deliberately sends no Issue.
Later changes create one Issue per dated transition. Re-running the same event
on the same date reuses its hidden event key and cannot create a duplicate.

## Authentication and request budget

The workflow reads the existing `HEDRA_API_KEY` Actions secret and never writes
the key to files or logs. It performs one authenticated request each Tuesday at
05:35 JST. A missing key, non-2xx response, invalid JSON, duplicate model ID, or
response larger than 5 MiB fails closed without overwriting the prior snapshot.

## Deterministic check

```bash
python test/scripts/test_hedra_model_watch.py
```

The test uses local fixtures only and never calls Hedra.
It runs automatically on pull requests that change the watcher. The authenticated
watch job is excluded from pull-request events and receives write permissions only
for scheduled or manually dispatched trusted-branch runs.
