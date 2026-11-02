# Search Console daily measurement

Google Search Console reports how this site's pages appeared in Google Search. This tool collects clicks and impressions through its official read-only API, or validates an already saved date-only API response. It does not add visitor tracking to the web application or create permissions.

## Prerequisites for real data

1. Open https://search.google.com/search-console and confirm a verified property for https://my-web-app-b67f4.web.app/ (or the actual custom domain). A sitemap-ready repository is not proof that a property is registered.
2. Enable the Search Console API in the Google project used by the existing authorized client. The account must have access to the property.
3. Supply a short-lived OAuth access token with scope `https://www.googleapis.com/auth/webmasters.readonly` as the environment variable `SEARCH_CONSOLE_ACCESS_TOKEN`. OAuth is Google's mechanism for granting an application specific access. Do not paste tokens into chat, CLI arguments, source files, evidence files or articles. This tool does not mint tokens, persist them, create credentials or grant access.
4. Run the command from the repository root, choosing finalized dates available in the property.

```sh
python -B scripts/search_console_measurement.py --fetch --site https://my-web-app-b67f4.web.app/ --start 2026-09-13 --end 2026-09-26 --before 2026-09-13 --after 2026-09-20 --days 7 --output search-console-private.json
```

To investigate one fixed page, add `--page https://my-web-app-b67f4.web.app/`. For an already saved response, replace `--fetch` with `--response /path/to/date-only-final-response.json`. The saved response must be from the documented date-only, finalized query; the program cannot authenticate the provenance of a local file. Do not commit the private snapshot automatically. Review aggregates before publishing.

## What the program checks

It asks for finalized web-search data with only the date dimension and an optional exact page filter. A maximum 500-day interval fits under the request's 25,000-row limit. It rejects malformed counts, duplicate days, incomplete metadata and overlapping comparison periods. Omitted days stay missing; absence cannot be silently converted to zero. A zero baseline returns no multiplier. A failed live request does not overwrite a previous snapshot, and error output omits response bodies and tokens. Redirects are rejected so authorization cannot be forwarded.

Output retains `America/Los_Angeles`, Google's Pacific calendar-day boundary. It does not pretend that daily sums can be converted into Japan-day sums. Search clicks and the application's accepted touch records are different populations with different deduplication. Compare each series within its own consistent measurement definition.

Impressions are the site's visibility in search results; changes reflect ranking and coverage as well as search demand. They do not measure all searches in the market. Three weeks cannot establish annual seasonality, and this tool does not prove an AI-copy causal effect. A real comparison still requires stable page versions, an appropriate control or randomized assignment, outcomes and a predeclared duration/sample plan.

## Verification

```sh
python -B -m unittest discover -s test/scripts -p test_search_console_measurement.py
```

Tests replace only the network transport, exercise the fixed Google endpoint and sanitized HTTP 403 path, and validate missing-day, timezone, invalid-input and zero-baseline behavior. Fixture results are not Google production measurements. The real-data stage remains pending until a verified property and an authorized token or genuine export are available.

References (checked 2026-09-27):
- https://developers.google.com/webmaster-tools/v1/searchanalytics/query
- https://developers.google.com/webmaster-tools/v1/how-tos/authorizing
- https://support.google.com/webmasters/answer/10267942
