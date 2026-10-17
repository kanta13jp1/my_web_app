# JSON download API reference

The public reference is `/labs/shared/reference.html`. Its source of truth is
the JSDoc directly above `downloadJson` in `web/labs/shared/download-json.mjs`.
Only this already-public browser module is parsed; server code and private
configuration are not inputs. JSDoc is development tooling, not a browser dependency.

## Update in five steps

1. Change the function and its JSDoc together. Explain the use case, arguments,
   return value, limitations, exceptions and a synthetic usage example.
2. On a sufficiently resourced development environment, run
   `npm ci --prefix scripts/api-docs --ignore-scripts`. Under the repository's
   cloud-first policy, dispatch **Lab API Reference** with `generate: true` on
   the pushed feature branch instead. It creates artifacts, never a push.
3. Run `node scripts/api-docs/generate.mjs --write` (or download the cloud HTML
   candidate), review it, and commit the HTML alongside source. When dependencies
   intentionally change, review and commit the generated lockfile too.
4. Run `node --test scripts/api-docs/reference.test.mjs` and
   `node scripts/api-docs/generate.mjs --check`. CI rejects stale/missing output,
   missing required documentation and mismatched parameter names.
5. Review desktop/mobile rendering and verify the deployed reference after merge.
   A passing generator does not establish semantic correctness; review the prose.

## Why this boundary?

This helper is shared by the Blur Studio and Jev Mario labs. It only serializes
and requests a local file download; callers own schema, filename and UI feedback.
The API reference carries the exact contract and an example. This handwritten
guide retains the workflow and tradeoff discussion so those are not lost during
generation. Each generated page links directly to the editable source and this guide.

Do not use it for cloud persistence, acknowledgements of completed saves or data
validation. JSON serialization may omit or transform values, so callers must
choose JSON-compatible data. The helper's behavior is unchanged by this documentation
work. Errors propagate; a UI must retain the user's input and offer recovery.

The generated reference is committed, not generated during a production request.
Reproducibility checks use a locked JSDoc version and LF-normalized source digest;
no machine-specific paths or timestamps enter the HTML. The rendering escapes
all documentation fields rather than executing comment HTML.

Scope limitation: the checks target this one function and do not claim whole-repository
documentation coverage. Browser download policies and actual disk-save completion
still require user/browser handling.
