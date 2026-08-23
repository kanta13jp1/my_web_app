# AI大学 YouTube embedding

## Contents

- Repository safety
- Data contract
- Reusable Flutter contract
- Lesson generation
- Validation
- Release and verification
- Rollback

## Repository safety

Work in `my_web_app`. Run `python scripts/codex_session_check.py` first. If the root is dirty, create a clean worktree from `origin/main` on a `codex/` branch and preserve every unrelated user change.

The production SSOT is `docs/RELEASE_CHECKLIST_ROLLBACK.md`. Normal production delivery is a reviewed merge to `main`; `.github/workflows/deploy-prod.yml` applies migrations, builds Flutter Web, deploys Firebase Hosting, and verifies `version.json`.

## Data contract

Store a video lesson in `ai_university_content`:

| Column | Rule |
|---|---|
| `provider` | Existing provider ID, normally `openai` for Codex |
| `category` | Stable unique ID beginning with `video_` |
| `title` | Published YouTube title |
| `content` | Original Markdown learning goal, takeaways, exercise, and attribution |
| `source_url` | Canonical public `https://www.youtube.com/watch?v=<id>` URL |
| `published_at` | Actual publication date |
| `sort_order` | `0` unless the user requests another order |
| `is_active` | `true` |

Use `ON CONFLICT (provider, category) DO UPDATE` so reruns update the same lesson. Never place OAuth data, raw audio, or local media paths in the migration.

## Reusable Flutter contract

The implementation must be generic so future YouTube-backed lessons need only a database migration.

Expected components:

- `lib/services/ai_university_video_lesson_service.dart`
  - Parse `youtube.com/watch`, `youtu.be`, `embed`, `shorts`, and `live` URLs.
  - Accept only valid 11-character YouTube IDs.
  - Expose a canonical embed URL.
- `lib/widgets/ai_university_youtube_embed.dart`
  - Register an iframe through `lib/utils/platform_view.dart` on Web.
  - Render at 16:9 with fullscreen permission.
  - Provide a visible `YouTubeで開く` fallback/action.
  - Render a non-Web fallback instead of importing Web-only APIs directly.
- `lib/widgets/ai_university_published_video_banner.dart`
  - Show a provider-independent `公開動画で学ぶ` entry above the genre shelf.
  - Receive every active public-video lesson as a data list and render each title and provider; never collapse multiple rows to the first topic.
  - Give each lesson an orange primary `今すぐ見る` CTA with a minimum 44 px target.
  - Switch each lesson tile to full width below 620 px using `LayoutBuilder`.
  - Receive titles, providers, and callbacks as data; never hard-code a video ID.
- `lib/widgets/ai_university_youtube_viewer_route.dart`
  - Open the embedded lesson through a regular opaque `MaterialPageRoute`.
  - Do not render an interactive iframe behind a `DialogRoute` or `ModalBarrier`; Flutter Web can place the barrier above the iframe in browser hit testing.
  - Keep an explicit visible close action and prevent interaction with the previous page while the viewer is open.
- `lib/pages/gemini_university_v2_page.dart`
  - Detect a YouTube `source_url` and embed the player inside the expanded lesson card.
  - Derive all active public-video topics from database rows and pass every topic to the banner regardless of the selected provider.
  - Open the embedded lesson in a constrained barrier-free viewer and keep the generation action labeled separately.
- `lib/pages/ai_university_video_page.dart`
  - Embed the selected published lesson before the generated-video controls.

Do not add a new video-player dependency when the repository iframe abstraction already satisfies the requirement.

## Lesson generation

Create a UTF-8 Markdown content file, then run:

```powershell
$skillDir = "C:\Users\kanta\GitHub\my_web_app\.agents\skills\youtube-video-pipeline"
python "$skillDir\scripts\ai_university_content.py" generate `
  --repo "<clean-worktree>" `
  --provider openai `
  --category video_<stable-slug> `
  --title "<published-title>" `
  --content-file "<lesson.md>" `
  "--video-url=https://www.youtube.com/watch?v=<video-id>" `
  --published-at YYYY-MM-DD
```

Inspect the migration diff. Check for a timestamp collision with all existing migrations before committing.

## Validation

Run focused validation first:

```powershell
python "$skillDir\scripts\ai_university_content.py" check-ui --repo "<worktree>"
dart analyze lib/services/ai_university_video_lesson_service.dart
dart analyze lib/widgets/ai_university_youtube_embed.dart
dart analyze lib/widgets/ai_university_published_video_banner.dart
dart analyze lib/widgets/ai_university_youtube_viewer_route.dart
dart analyze lib/pages/ai_university_video_page.dart
dart analyze lib/pages/gemini_university_v2_page.dart
flutter test --no-pub test/services/ai_university_video_lesson_service_test.dart
flutter test --no-pub test/services/ai_university_published_video_seed_test.dart
flutter test --no-pub test/widgets/ai_university_youtube_embed_test.dart
flutter test --no-pub test/widgets/ai_university_published_video_banner_test.dart
flutter test --no-pub test/widgets/ai_university_youtube_viewer_route_test.dart
git diff --check
```

When resources permit, run the repository Web build used by CI. If local memory is critically high, do not worsen system pressure; record the limitation and rely on the same CI build after the approved push.

## Release and verification

After the separate AI大学 confirmation:

1. Commit only the scoped skill, UI, tests, and migration.
2. Push a `codex/` branch and open a reviewed PR with the validation and rollback plan.
3. Watch required PR checks and merge only after they pass and the user authorized production reflection.
4. Capture the squash merge commit from the merged PR.
5. Find the `deploy-prod.yml` run whose `headSha` equals that merge commit; queued newer/older runs are not substitutes.
6. Watch the matching run through migration, Flutter Web build, Firebase deploy, and version verification.
7. Confirm `https://my-web-app-b67f4.web.app/version.json` reports the squash merge commit.
8. Open production `/ai-university` without selecting a provider and verify the public-video banner shows the title.
9. Use `今すぐ見る`, verify the iframe contains the published video ID, confirm the iframe is the browser hit-test target, click play and verify playback advances, and confirm `YouTubeで開く` resolves to the same public video.

Report separately: YouTube state, database lesson state, deployed commit, workflow URL, banner state, and visible embed state.

## Rollback

- Frontend defect: `git revert` the bad commit and let `deploy-prod.yml` redeploy.
- Lesson-data defect: add a forward-only idempotent migration that corrects the row or sets `is_active = false`.
- Do not delete or privatize the public YouTube video merely because the app release failed.
