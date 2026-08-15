# AI大学 YouTube release operations

## Contents

- Completion states
- Playback failure diagnosis
- Barrier-free viewer fix
- Focused validation
- Memory-safe validation
- PR and CI repair loop
- Merge edge cases
- Exact deployment monitoring
- Production data and playback QA
- Failure reporting and rollback

## Completion states

Keep these states separate:

1. **Implemented:** scoped code and tests exist locally.
2. **PR validated:** every required check on the current head commit passed.
3. **Merged:** the PR API reports `MERGED` and supplies the squash merge commit.
4. **Deployed:** the matching production workflow succeeded and `version.json` reports that exact commit.
5. **Fully verified:** the lesson row is active, the banner is visible, the iframe receives the click, and playback time advances.

Never collapse these into one generic “complete” state. If browser control is disconnected, state 4 can be proven while state 5 remains pending.

## Playback failure diagnosis

When the YouTube image and play icon render but the button cannot be pressed, first prove which browser element receives the pointer. Do not replace the iframe or add another player dependency before this check.

1. Open the production AI大学 route and select the published lesson.
2. Locate `iframe[src*="youtube.com/embed/"]` and record its rectangle.
3. Inspect `document.elementsFromPoint()` at the iframe center.
4. Treat an iframe-first result as healthy hit testing.
5. Treat a full-screen Flutter semantics node, modal barrier, or overlay before the iframe as a blocked hit target.
6. Temporarily disable pointer events on only the proven blocker for diagnosis. Click the player and verify playback advances. Never ship this DOM mutation as the fix.

Example browser-side diagnostic:

```javascript
const iframe = document.querySelector('iframe[src*="youtube.com/embed/"]');
const rect = iframe?.getBoundingClientRect();
const x = rect ? rect.left + rect.width / 2 : 0;
const y = rect ? rect.top + rect.height / 2 : 0;
const stack = document.elementsFromPoint(x, y).slice(0, 8).map((element) => ({
  tag: element.tagName,
  id: element.id,
  className: element.className,
}));
({ rect, stack });
```

Also verify the expected video ID appears in the iframe URL and the visible `YouTubeで開く` action resolves to the same canonical watch URL.

## Barrier-free viewer fix

Flutter Web can place a `DialogRoute` or `ModalBarrier` above an `HtmlElementView`. The iframe remains visible because it is a platform view, but the barrier wins browser hit testing.

Use the shared `AiUniversityYoutubeViewerRoute` pattern:

- Push a regular opaque `MaterialPageRoute` through the root navigator.
- Render the constrained lesson surface inside a full-screen background and `SafeArea`.
- Keep an explicit close action.
- Keep the previous page non-interactive while the viewer is open.
- Do not use `showDialog` for an interactive Web iframe.
- Assign only a registered app route name. A query string is allowed when its path resolves to an existing route, for example `/ai-university?tab=openai`.

Do not invent an unregistered viewer URL such as `/ai-university/published-video`; the repository route synchronization test rejects hard-coded names that cannot be restored after reload or sharing.

## Focused validation

Run the smallest deterministic set first:

```powershell
python .agents/skills/youtube-video-pipeline/scripts/ai_university_content.py check-ui --repo .
python -m py_compile .agents/skills/youtube-video-pipeline/scripts/ai_university_content.py
flutter test --no-pub test/widgets/ai_university_youtube_viewer_route_test.dart
flutter test --no-pub test/routes/route_url_sync_test.dart
git diff --check
```

The viewer regression test must prove:

- The pushed route is `AiUniversityYoutubeViewerRoute`.
- `opaque` is `true` and `barrierColor` is `null`.
- The previous page does not receive taps while the viewer is open.
- The explicit close action returns to the previous page.

Run the repository-required commit hook normally. Do not use `--no-verify` to bypass a slow gate. Let GitHub CI remain the authoritative full-suite and Web-build proof after an approved push.

## Memory-safe validation

When physical memory is critically high:

- Do not start multiple Flutter analyzes, tests, or Web builds concurrently.
- Prefer the focused tests above, then the normal commit hook and remote CI.
- Give the commit hook enough time; a full analyze can take several minutes.
- If a shell timeout leaves a process behind, inspect process IDs, command lines, and parent IDs. Stop only the exact process tree proven to belong to the timed-out command. Never kill every Dart or Flutter process.
- Recheck memory before retrying.
- Restore only known incidental generated registrants after verification, and only when they are outside the scoped change.

Typical incidental files are platform-generated plugin registrants under `linux/flutter/`, `macos/Flutter/`, and `windows/flutter/`. Inspect `git status` before restoring any path.

## PR and CI repair loop

Create a ready PR only after the explicit AI大学 production gate. Include the root cause, scoped fix, validation, rollback, and the repository-required Minimal E2E declaration. Inspect the current gate template or workflow instead of guessing its required wording.

For every CI cycle:

1. Read `gh pr checks <number> --json name,state,bucket,workflow,link`.
2. Wait while any check is pending.
3. On failure, use `gh run view <run-id> --log-failed` and identify the first real assertion or command error.
4. Reproduce that exact check locally when practical.
5. Fix forward on the same scoped branch and rerun the focused tests.
6. Amend or add a commit according to repository policy.
7. If an amended commit was already pushed, update with `git push --force-with-lease`, never plain `--force`.
8. Wait for the complete new check set. Do not merge based on checks from the superseded commit.

Example: an unregistered `RouteSettings` name can pass the new viewer test but fail `test/routes/route_url_sync_test.dart`. Add that repository-wide contract test to the focused set after such a failure.

## Merge edge cases

Run:

```powershell
gh pr merge <number> --squash --delete-branch
gh pr view <number> --json state,mergedAt,mergeCommit,url
```

`gh pr merge` can merge remotely and then exit nonzero because another local worktree already has `main` checked out. Always inspect the PR state after a nonzero exit. If it reports `MERGED`, record the returned merge commit and do not retry the merge.

Treat branch cleanup separately. Delete only the exact feature branch after confirming the PR is merged and no work remains.

## Exact deployment monitoring

Use the squash merge SHA as the correlation key. GitHub Actions can have queued or concurrent runs; the newest visible run is not necessarily this release.

```powershell
gh run list --workflow "Deploy to Production" --limit 20 `
  --json databaseId,headSha,status,conclusion,url,createdAt,displayTitle
gh run view <matching-run-id> --json status,conclusion,jobs,url
```

Poll until a run with `headSha == <merge-sha>` appears. Watch only that run through:

- Reusable CI and security checks.
- Supabase migrations.
- Supabase Edge Function deployment.
- Production Flutter Web build.
- Firebase Hosting deployment.
- Deployment notification and version verification.

Because `deploy-prod.yml` uses `cancel-in-progress: false`, queued state is expected. Do not dispatch a duplicate deployment.

After success, bypass caches while polling:

```text
https://my-web-app-b67f4.web.app/version.json?t=<timestamp>
```

Require `commit` to equal the exact squash merge SHA. Record `version`, `buildNumber`, `commit`, and `deployedAt`.

## Production data and playback QA

Verify three independent surfaces:

### Data

Query `ai_university_content` through the configured application service or public REST contract without printing keys. Confirm one row with the expected:

- `provider`
- stable `video_...` category
- published title
- canonical `source_url`
- publication date
- `is_active = true`

### YouTube

Use the YouTube API or oEmbed metadata to confirm the video ID, title, channel, and public availability. Do not infer public state only from an iframe thumbnail.

### Live UI and playback

1. Open `/ai-university?tab=<provider>` and confirm `公開動画で学ぶ` shows the expected title.
2. Click `今すぐ見る` and confirm the barrier-free viewer opens.
3. Confirm the iframe contains the expected video ID.
4. Run the center-point hit-test diagnostic and require `IFRAME` to be the effective target.
5. Click the YouTube play control.
6. Wait briefly, inspect the YouTube frame when the browser tool permits it, and require `paused == false` with `currentTime` increasing between samples.
7. Confirm `YouTubeで開く` targets the same canonical public watch URL.
8. Close the viewer and confirm the AI大学 page remains usable.

If autoplay policy blocks programmatic playback, perform a real user-like click before evaluating the video state. If browser automation cannot inspect the cross-origin frame, require a visible player state change and report the weaker evidence explicitly.

## Failure reporting and rollback

- If CI fails, report the failing workflow and assertion; do not call the PR validated.
- If deployment fails, keep the YouTube video public and preserve the lesson migration for a forward fix.
- If `version.json` does not match, report the deployed build as stale or pending.
- If the lesson row is active but the iframe is blocked, report “deployed, playback defect remains.”
- If browser control is unavailable, report “deployment verified; live playback QA pending.” Do not claim full completion.
- For a frontend defect, use a reviewed `git revert` and the normal production workflow.
- For lesson data, add a forward-only idempotent migration that corrects the row or sets `is_active = false`.
