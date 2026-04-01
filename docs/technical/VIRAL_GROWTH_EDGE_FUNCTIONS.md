# Viral Growth Edge Functions

Added on 2026-04-02.

## Functions

| Function | Role |
| --- | --- |
| `post-x-update` | Extended to support media URLs, link URLs, hashtags, and video/image uploads before posting to X |
| `viral-video-generator` | Generates short-form ad briefs, scene plans, render prompts, and can queue external video render jobs |
| `viral-share-engine` | Generates share packs, X post variants, reply prompts, and records viral campaign metrics |
| `growth-automation-controller` | Orchestrates the end-to-end pipeline from brief generation to render queueing to X publishing |

## Secrets

- `X_API_KEY`
- `X_API_SECRET`
- `X_ACCESS_TOKEN`
- `X_ACCESS_TOKEN_SECRET`
- `X_ACCOUNT_HANDLE` (optional, defaults to `@kanta13jp1`)
- `OPENAI_API_KEY` (optional, enables AI-generated briefs instead of fallback templates)
- `VIRAL_VIDEO_PROVIDER_URL` (optional, enables external render queueing)
- `VIRAL_VIDEO_PROVIDER_API_KEY` (optional)
- `VIRAL_VIDEO_PROVIDER_NAME` (optional)
- `VIRAL_VIDEO_CALLBACK_URL` (optional)

## Notes

- The ad brief generator is intentionally optimized for high-retention short-form creative while avoiding fake gameplay, fake metrics, or misleading claims.
- If no video provider is configured, the render step returns `awaiting_provider` so the pipeline can still be tested end-to-end in dry-run mode.
- Posted campaign data is logged into `app_analytics` with sources such as `viral_video_brief`, `viral_video_job`, `viral_share_pack`, `viral_growth_run`, and `x_media_post`.
