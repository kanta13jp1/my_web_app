# Publishing policy

## Contents

- Source rights and attribution
- Voice and personal data
- YouTube confirmation gates
- AI大学 production gate
- Authentication and account safety
- Validation and truthful reporting

## Source rights and attribution

- Treat captions from a third-party video as research input, not reusable copy.
- Do not output, translate, dub, or publish a full third-party transcript unless the user owns the rights or supplies clear permission.
- For third-party sources, write an original summary, review, tutorial, or commentary. Avoid close sentence-by-sentence substitution.
- Include the source URL and identify the result as an independent summary/commentary, not an official translation.
- If only automatic captions are available, disclose their use and expect transcription errors.
- Do not download or reuse the source video's visuals, music, or branding unless the user has rights to them.

## Voice and personal data

- Record only after the speaker explicitly asks to start.
- Confirm that the recorder reports `RECORDING_CONFIRMED` before telling the speaker to begin.
- Stop only after an explicit stop request.
- Do not clone or imitate another identifiable person's voice.
- Store recordings in the user-selected job directory. Do not upload raw audio unless explicitly requested.
- Keep the original and normalized MP3. Delete only the temporary raw PCM created by this skill, and only after conversion validation succeeds.

## YouTube confirmation gates

Use two separate gates:

1. **Private upload gate:** Show the exact channel handle, MP4, thumbnail, title, description summary, category, audience setting, and `private` visibility. Require explicit approval immediately before upload.
2. **Public release gate:** After the user inspects the private video, require a new explicit instruction to publish. Approval to upload does not authorize publication.

Upload new videos as `private`. Do not upload as `public` or `unlisted` from the production command.

Before public release:

- Verify the authenticated channel's `customUrl` equals the requested handle.
- Verify the target video's `channelId` belongs to that authenticated channel.
- Verify the confirmation token exactly equals the video ID.
- Preserve `selfDeclaredMadeForKids`, license, embeddable, and public statistics settings unless the user asks to change them.
- Poll after the update until the API returns `public`; visibility can lag behind the update response.

## AI大学 production gate

Treat the AI大学 release as a third, separate gate after YouTube publication.

- Show the public video URL, provider, category, title, lesson summary, migration path, changed Flutter files, validation results, production URL, and rollback plan.
- Require explicit approval such as 「AI大学に反映」 immediately before pushing, merging, or dispatching production deployment.
- YouTube upload or publication approval does not authorize a database or application deployment.
- Prefer a clean worktree, reviewed PR, and the repository's `deploy-prod.yml`. Do not directly run production `supabase db push` or Firebase deployment unless the user explicitly requests the documented manual recovery path.
- Never report the lesson as embedded until the database row is active and the production AI大学 page visibly renders the published video ID.
- Roll back forward: use `git revert` for code and an idempotent follow-up migration such as `is_active = false` for lesson data. Never rewrite shared history.

## Authentication and account safety

- Store OAuth files under `~/.youtube/`, outside the repository.
- Never print, read aloud, paste, transmit, or commit token contents.
- Let the user enter Google credentials and approve OAuth in the browser.
- Explain that `youtube.force-ssl` is a broad management permission before starting authorization.
- The bundled release script implements no delete command.
- On `invalid_grant`, leave the old token untouched and create a newly named token after user approval.
- On `insufficientPermissions`, request the correct scope rather than attempting a workaround.

## Validation and truthful reporting

Before upload, verify:

- MP4 includes H.264 video and AAC audio.
- Resolution is 1920×1080 and frame rate is 30 fps unless the user requested otherwise.
- Full-file decoding returns no error.
- A three-frame contact sheet shows readable typography and subtitles.
- Audio is present and normalized without clipping.

After upload or visibility change:

- Report the video ID, URL, title, and actual API-reported privacy status.
- Never report a video as uploaded or public merely because a command was started or an update request returned successfully.
- If verification disagrees with the requested state, report the current state and continue diagnosis without repeating destructive or public actions blindly.
