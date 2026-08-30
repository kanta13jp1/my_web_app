# Cloud-first development workflow

This repository treats the local Windows PC as a lightweight control plane.
GitHub owns source preservation, dependency hydration, analysis, tests, builds,
browser checks, and short-lived review artifacts. Supabase owns private
migration staging and server-side processing.

## Default execution path

Use this order for every task:

1. Inspect only the small amount of local state needed to avoid overwriting user
   work.
2. Prefer the GitHub connector, Git Data API, or GitHub web editor for bounded
   source changes. Do not create a local worktree merely to edit files that the
   remote API can update safely.
3. Commit to a scoped `codex/` branch and open a draft pull request.
4. Dispatch GitHub Actions against the exact 40-character branch HEAD.
5. Read logs and summaries remotely. Download an artifact only when a person
   must inspect it.
6. Keep production deployment in the deployment workflow, never on the local
   PC.

Use GitHub Codespaces only when interactive multi-file editing is genuinely
needed and after checking quota or billing. A codespace is never created
automatically.

## Resource boundary

Run locally only lightweight control-plane operations:

- inspect `git status`, a small diff, or a single text file;
- preserve a small scoped edit when no remote edit route exists;
- push a committed branch, update a pull request, or dispatch a workflow;
- read Actions logs or perform a short HTTP/revision check.

Run in GitHub Actions:

- `flutter pub get`;
- `flutter analyze`;
- `flutter test`;
- `flutter build web`;
- browser smoke tests;
- generated artifacts and release gates.

Run in Supabase or another private cloud worker:

- streaming ENEX parsing;
- attachment transfer, hashing, OCR, and media conversion;
- migration ledger updates and aggregate audits;
- recovery export generation and verification.

Do not start a local Flutter/Dart build, analysis, test, browser automation,
server, media pipeline, or ENEX expansion when RAM usage is at least 85%, free
physical memory is below 2 GiB, or free disk is below 30 GiB. Preserve the
current edit remotely and dispatch a cloud workflow. Resume resource-intensive
local work only after two measurements, at least eight seconds apart, both show
RAM below 85%, more than 2 GiB free memory, and no Dart/Flutter process.

A request to continue does not bypass this resource gate.

## Exact-revision cloud validation

`.github/workflows/cloud-development.yml` supports these profiles:

| Profile | Cloud work |
| --- | --- |
| `workspace` | Validate cloud workspace descriptors without Flutter |
| `analyze` | Resolve dependencies and run static analysis |
| `test` | Resolve dependencies and run tests |
| `web-build` | Resolve dependencies and create a release web build |
| `full` | Analyze, test, and create a release web build |

Manual runs require the exact branch HEAD. This prevents a moving branch from
silently validating a different revision:

```powershell
$branch = 'codex/<task>'
$sha = gh api "repos/kanta13jp1/my_web_app/commits/$branch" --jq .sha
gh workflow run cloud-development.yml --ref $branch `
  -f profile=full `
  -f expected_head_sha=$sha
```

When the GitHub connector is available, perform the same branch lookup and
workflow dispatch through the connector so the local PC does not need GitHub
CLI or a hydrated checkout.

A pull-request event validates GitHub's immutable event revision. A reusable
workflow caller may also pass `expected_head_sha`; if supplied, the same
lowercase 40-character validation is enforced.

## Cloud editing workspace

The default `.devcontainer/devcontainer.json` is a lightweight GitHub
Codespaces control plane. It does not install Flutter, run `flutter pub get`,
open a browser, or create build output during startup.

The former rootless-Podman Flutter environment remains available at
`.devcontainer/flutter-local/devcontainer.json`. It is a resource-heavy,
explicit fallback and must never be selected automatically.

## Personal migration data

Personal ENEX files, Obsidian vault contents, attachments, credentials, browser
profiles, production exports, and signed URLs must never be committed to Git,
uploaded to Actions, printed in logs, or preserved as workflow artifacts.

The browser streams a selected export directly to an owner-private Supabase
Storage bucket in bounded resumable chunks. Server-side workers process the
staged object sequentially. Logs and summaries contain only opaque IDs, counts,
hashes, timings, and gate states.

Evernote deletion always requires a fresh explicit approval after a batch is
fully verified. Subscription cancellation remains blocked until all data,
feature parity, recovery, account, and billing checks pass.

## Artifacts, caches, and cleanup

- Hosted-runner dependency caches stay in GitHub.
- Web builds and review patches have one-day retention.
- Do not download build artifacts merely to redeploy them locally.
- Never delete unrelated local worktrees or caches to manufacture headroom.
- Close only resources opened by the current task.
- Keep unmerged work preserved in the remote branch and draft pull request.

If cloud execution is unavailable, report the infrastructure blocker. Do not
fall back to a heavy local run while the resource gate is active.
