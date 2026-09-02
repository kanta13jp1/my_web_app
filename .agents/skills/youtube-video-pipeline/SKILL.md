---
name: youtube-video-pipeline
description: End-to-end reference-video workflow for fetching public captions and metadata, writing an original Japanese narration, recording the user's voice, rendering a verified 1080p video and thumbnail, uploading privately to a verified YouTube channel, publishing after a separate confirmation, registering the public video in my_web_app AI大学 as a discoverable embedded lesson, and monitoring the reviewed production deployment through live UI verification. Use for requests such as 「参考動画から解説動画を作って」, 「読み上げを録音して動画化」, 「YouTubeに非公開投稿して確認後に公開」, 「公開動画をAI大学に埋め込んで」, 「mainへマージしてデプロイを監視」, or the complete reference-video-to-AI大学 pipeline.
---

# YouTube Video Pipeline

Turn a reference video into an original Japanese narrated video, release it through a private-first YouTube workflow, then register the verified public video as an embedded AI大学 lesson in `my_web_app`. Keep each stage independently verifiable and resumable across turns.

## Required safety policy

Read [references/publishing-policy.md](references/publishing-policy.md) before fetching third-party captions, recording a voice, authenticating YouTube, uploading, changing visibility, or initiating an AI大学 production release. Follow its confirmation gates exactly.

Read [references/ai-university-embedding.md](references/ai-university-embedding.md) before changing `my_web_app`, generating a lesson migration, opening a PR, or verifying the embedded video.

## Preflight

Set the skill and output paths, then check dependencies:

```powershell
$skillDir = "C:\Users\kanta\GitHub\my_web_app\.agents\skills\youtube-video-pipeline"
$jobDir = "C:\Users\kanta\Videos\youtube-video-pipeline\<job-name>"
$appRepo = "C:\Users\kanta\GitHub\my_web_app"
python "$skillDir\scripts\media_pipeline.py" check
```

Require `ffmpeg`, `ffprobe`, `yt-dlp`, Python 3.11+, Pillow, and the Google API packages for publishing. Preserve unrelated files in an existing job directory.

## Workflow

### 1. Inspect the reference

Fetch metadata and an official subtitle track when available:

```powershell
python "$skillDir\scripts\media_pipeline.py" reference `
  --url "<youtube-url>" --language en --output-dir "$jobDir\reference"
```

Add `--allow-auto` only when official subtitles do not exist and disclose that automatic captions were used. Do not return or publish a full third-party transcript. Use it internally to produce an original summary or commentary script.

### 2. Write the narration

Create `$jobDir\narration.txt` in UTF-8. Use one spoken subtitle unit per paragraph. Keep the script original, natural to read aloud, and materially shorter than the source when the source is third-party.

Use [references/narration-format.txt](references/narration-format.txt) as a paragraph-format example when a concrete template is helpful; replace its subject matter rather than reusing it blindly.

Show the full narration to the user before recording. Do not begin recording in the same message as the script unless the user explicitly says they are ready.

### 3. Record the user's voice

List Windows audio devices when needed:

```powershell
python "$skillDir\scripts\media_pipeline.py" devices
```

Start recording only after the user says 「録音開始」:

```powershell
python "$skillDir\scripts\media_pipeline.py" record-start `
  --device "<exact DirectShow audio device name>" --output-dir "$jobDir\audio"
```

Wait for `RECORDING_CONFIRMED` before telling the user to speak. If startup fails or the raw file remains zero bytes, say that nothing was recorded and retry; never pretend recording started.

Stop only after the user says 「録音終了」:

```powershell
python "$skillDir\scripts\media_pipeline.py" record-stop `
  --output-dir "$jobDir\audio"
```

Use the returned normalized MP3 for editing. Keep the original MP3. The script deletes only its own temporary raw PCM after both MP3 files validate.

### 4. Build the video

Prepare audio, align the narration paragraphs to detected pauses, render subtitles and a waveform, create a thumbnail, and verify the MP4:

```powershell
python "$skillDir\scripts\media_pipeline.py" build `
  --audio "$jobDir\audio\<recording>_original.mp3" `
  --script "$jobDir\narration.txt" `
  --output-dir "$jobDir\video" `
  --title "Codex Record & Replay" `
  --tagline "一度見せれば、次から任せられる。"
```

Review the generated contact sheet. If subtitle timing or wrapping is poor, edit `cues.json` and rerun with `--cues <path>` instead of regenerating alignment.

Never report completion until:

- `ffprobe` reports H.264 video and AAC audio at 1920×1080.
- Full decoding finishes without errors.
- The contact sheet shows readable opening, middle, and ending captions.
- Duration and audio level are plausible.

### 5. Prepare YouTube metadata

Draft and show the exact target handle, title, description, category, audience setting, thumbnail, local MP4 path, and visibility. Attribute the reference URL and say that the video is an original summary/commentary rather than an official translation when applicable.

Require a user confirmation such as 「この内容で投稿」 immediately before upload.

### 6. Authenticate and upload privately

The YouTube management scope is broad. Start OAuth only after explaining it to the user:

```powershell
python "$skillDir\scripts\youtube_release.py" auth-manage
```

Ask the user to complete Google authentication themselves. Never request a password, OAuth code, or token contents.

Verify the authenticated channel before upload:

```powershell
python "$skillDir\scripts\youtube_release.py" channel `
  --expected-handle "@channel-handle"
```

After the upload confirmation, upload as private only:

```powershell
python "$skillDir\scripts\youtube_release.py" upload-private `
  --expected-handle "@channel-handle" `
  --file "$jobDir\video\video.mp4" `
  --thumbnail "$jobDir\video\thumbnail.jpg" `
  --title "<title>" `
  --description-file "$jobDir\description.txt" `
  --tags "Codex,OpenAI,AI,生成AI" `
  --confirm-upload "video.mp4"
```

Report the returned video ID and private status. Ask the user to inspect the private video.

### 7. Publish after a second confirmation

Never infer approval to publish from approval to upload. Require a fresh, explicit instruction such as 「公開に変更」.

```powershell
python "$skillDir\scripts\youtube_release.py" publish `
  --expected-handle "@channel-handle" `
  "--video-id=<video-id>" `
  "--confirm-public=<video-id>"
```

The command verifies channel ownership, changes visibility, then polls until YouTube returns `public`. Do not claim success from the update response alone.

Use the quoted `--key=value` form for video IDs because valid YouTube IDs can begin with `-`.

### 8. Prepare the AI大学 lesson

Proceed only after YouTube reports the video as `public`. Save an original learning lesson to `$jobDir\ai-university-content.md` with:

- A one-sentence learning goal.
- Three to five concrete takeaways.
- A short practice exercise.
- The reference video's attribution and the independent-summary disclaimer when applicable.

Select the existing AI provider, normally `openai` for Codex. Use a stable unique category beginning with `video_`, such as `video_codex_record_replay`.

Check whether the reusable embedding foundation already exists:

```powershell
python "$skillDir\scripts\ai_university_content.py" check-ui --repo "$appRepo"
```

If the check fails, implement the shared URL parser and `AiUniversityYoutubeEmbed` contract from [references/ai-university-embedding.md](references/ai-university-embedding.md). Do not add a one-off hard-coded iframe to a single lesson.

Generate the idempotent content migration in a clean scoped worktree:

```powershell
python "$skillDir\scripts\ai_university_content.py" generate `
  --repo "<clean-worktree>" `
  --provider openai `
  --category video_<stable-slug> `
  --title "<published-video-title>" `
  --content-file "$jobDir\ai-university-content.md" `
  "--video-url=https://www.youtube.com/watch?v=<video-id>" `
  --published-at YYYY-MM-DD
```

Use quoted `--key=value` form when a value begins with `-`. Review the generated SQL before continuing.

### 9. Make published videos discoverable

Do not bury a published lesson inside the selected provider's collapsed content. Keep the reusable provider lesson card, and also expose all active YouTube-backed lessons through a provider-independent `公開動画で学ぶ` entry near the top of `/ai-university`, before the genre shelf.

Use the shared `AiUniversityPublishedVideoBanner` contract from [references/ai-university-embedding.md](references/ai-university-embedding.md):

- Show every active published title and provider together with the total public-video count; never reduce the banner to only `topics.first`.
- Give every listed lesson its own design-system orange CTA `今すぐ見る` with a minimum 44 px target.
- Open the reusable embedded player in a barrier-free opaque viewer route without requiring a provider-tab change. Do not place an interactive Web iframe behind a `DialogRoute` or `ModalBarrier`.
- Switch each lesson tile below 620 px to a full-width layout and add a narrow-width overflow test plus a second-item callback test.
- Keep the app-bar video-generation action distinct, such as `AI動画レッスンを生成`.
- Derive lessons from database rows; never hard-code one video ID into the banner.

Run `check-ui` again. It must validate both the iframe foundation and the discoverability banner.

### 10. Validate the AI大学 release

Run the targeted checks specified in [references/ai-university-embedding.md](references/ai-university-embedding.md). Show the user:

- Public YouTube URL and video ID.
- AI大学 provider, category, title, and learning summary.
- Migration path and application files changed.
- Static-analysis, test, and Web-validation results.
- Target production URL and rollback plan.

Require a new explicit confirmation such as 「AI大学に反映」 before pushing, merging, or dispatching production deployment. YouTube publication approval does not authorize an application production release.

### 11. Commit, merge, and monitor production

After that explicit production confirmation, release through a scoped branch and reviewed PR. Do not run direct production `supabase db push` or Firebase deployment unless the user explicitly requests the documented manual recovery path.

```powershell
git status -sb
git diff --check
git add -- <explicit scoped paths>
git commit -m "feat: publish YouTube lesson in AI University"
git push -u origin (git branch --show-current)

gh pr create --base main --head (git branch --show-current) `
  --title "feat: publish YouTube lesson in AI University" `
  --body-file <pr-body.md>
gh pr checks <pr-number> --watch --interval 15
gh pr merge <pr-number> --squash --delete-branch
gh pr view <pr-number> --json state,mergedAt,mergeCommit,url
```

Merge only after required checks pass. Capture the actual squash merge commit, then identify the `Deploy to Production` run whose `headSha` matches it; do not assume the newest run belongs to this release.

```powershell
gh run list --workflow deploy-prod.yml --branch main --event push --limit 20 `
  --json databaseId,headSha,status,conclusion,url,createdAt
gh run watch <matching-run-id> --exit-status
```

If the run fails, inspect it with `gh run view <run-id> --log-failed`, keep the YouTube video public, and preserve the PR/migration for a forward fix. Because deployment runs queue with `cancel-in-progress: false`, wait through queued state rather than dispatching a duplicate run.

After deployment:

1. Poll `https://my-web-app-b67f4.web.app/version.json` until `commit` equals the squash merge commit.
2. Open `/ai-university` without relying on a particular provider tab.
3. Confirm `公開動画で学ぶ` shows the published title and `今すぐ見る` opens the barrier-free viewer.
4. Confirm the iframe URL or player contains the published video ID and `YouTubeで開く` resolves to the same public URL.
5. Confirm the iframe is the browser hit-test target at its center, click the YouTube play control, and verify playback time advances.
6. Report separately: YouTube privacy state, database lesson state, deployed commit, workflow URL, banner visibility, and embedded-player state.

Do not claim completion until the active database lesson, production version, discoverability banner, and visible embedded player are all confirmed.

## Resume and failure handling

- Reuse job artifacts instead of restarting the whole pipeline.
- Treat OAuth `invalid_grant` as expired authorization; create a new, separately named token after user approval.
- Treat an API `insufficientPermissions` response as a scope mismatch; do not bypass it with browser automation.
- Preserve the private video if publishing fails. Report the actual current state.
- If AI大学 deployment fails, keep the public YouTube video unchanged and preserve the migration/PR for retry.
- If the app repository is dirty, create a clean worktree from `origin/main`; never overwrite unrelated changes.
- If system memory is critically high, stop local Web builds and use already-passing targeted checks plus CI after user-approved push.
- Never commit OAuth client secrets, access tokens, refresh tokens, raw recordings, or rendered media.

## Bundled tools

- `scripts/media_pipeline.py`: reference inspection, recording, silence trimming, pause-aligned subtitles, rendering, thumbnails, and media verification.
- `scripts/youtube_release.py`: channel verification, private-only upload, thumbnail upload, status inspection, and confirmation-locked publication.
- `scripts/ai_university_content.py`: reusable UI-contract check and idempotent AI大学 video lesson migration generator.
- `references/publishing-policy.md`: copyright, consent, OAuth, confirmation, provenance, and validation rules.
- `references/ai-university-embedding.md`: `my_web_app` schema, reusable Flutter embed contract, tests, release, verification, and rollback.
- `references/narration-format.txt`: example of one subtitle-sized spoken unit per paragraph.
