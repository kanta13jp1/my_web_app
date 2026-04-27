---
title: "Auto-Generating Video Content with AI: NotebookLM + ElevenLabs + GitHub Actions Pipeline"
tags: ai,automation,youtube,github-actions
published: true
---

# Auto-Generating Video Content with AI: NotebookLM + ElevenLabs + GitHub Actions Pipeline

I wanted to produce video content without spending hours on editing. Here's the fully automated pipeline I built that turns a YouTube URL into a processed, embedded video with one click.

## The Full Pipeline

```
YouTube URL → ElevenLabs Scribe (transcription) → SRT generation
           → Title card generation (PIL)
           → Embed in Flutter philosophy page
           → GitHub Actions auto-commit/push
           → Slack notification
```

Human work per video: **paste one URL into a GitHub Actions dispatch**.

## Step 1: Transcription with ElevenLabs Scribe

Scribe handles multilingual audio including Japanese and supports speaker diarization.

```python
# scripts/video/transcribe.py
def transcribe(audio_path: str) -> dict:
    with open(audio_path, 'rb') as f:
        response = requests.post(
            'https://api.elevenlabs.io/v1/speech-to-text',
            headers={'xi-api-key': API_KEY},
            files={'audio': f},
            data={'model_id': 'scribe_v1', 'diarize': True}
        )
    return response.json()
```

Speaker labels (`Speaker A:`, `Speaker B:`) are added only when multiple speakers are detected. Single-speaker videos get no prefix — zero behavior change.

## Step 2: SRT Generation

Four-level cue boundary detection:

```python
# Boundary priority order:
# 1. Terminal punctuation (. ? !)
# 2. Force-split cues over 15 seconds
# 3. Silence gaps > 0.5s
# 4. Max 20 words per cue
```

An `ASR_CORRECTIONS` environment variable accepts a JSON dict of mis-transcribed terms to fix before SRT output.

## Step 3: Title Card Generation

Auto-generate thumbnails and title cards using PIL with the project's design tokens.

```python
# scripts/video/make_cards.py
BACKGROUND = '#1e1b4b'  # Indigo 950 (project dark theme)
ACCENT = '#f97316'       # Orange 500

def make_title_card(title: str, series: str) -> Image:
    img = Image.new('RGB', (1280, 720), BACKGROUND)
    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype('NotoSansCJK-Regular.ttc', 72)
    # Auto word-wrap for CJK + Latin mixed text
    wrapped = wrap_text(title, max_width=1100, font=font)
    draw.text((90, 280), wrapped, font=font, fill='white')
```

## Step 4: GitHub Actions Automation

```yaml
name: NotebookLM Video Pipeline
on:
  workflow_dispatch:
    inputs:
      youtube_url: { required: true }

jobs:
  pipeline:
    steps:
      - name: Step 0 — YouTube quota pre-flight
        run: |
          # Abort if 6+ videos processed in last 24h
          COUNT=$(gh run list --workflow=${{ github.workflow }} \
            --status=success --json createdAt \
            --jq "[.[] | select(.createdAt > \"$SINCE\")] | length")
          [ "$COUNT" -ge 6 ] && echo "Quota exceeded" && exit 1

      - name: Step 1 — Download audio
        run: yt-dlp -x --audio-format mp3 "${{ inputs.youtube_url }}"

      - name: Step 2 — Transcribe
        run: python scripts/video/transcribe.py

      - name: Step 3 — Build SRT
        run: python scripts/video/build_srt.py

      - name: Step 4 — Make title cards
        run: python scripts/video/make_cards.py

      - name: Step 8 — Embed in Flutter
        run: python scripts/embed_video_in_philosophy.py

      - name: Notify Slack
        if: always()
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## Slack Notifications

Success message includes video URL, duration, and SRT summary. Failure includes a direct link to the Actions log.

```json
{
  "blocks": [{
    "type": "section",
    "text": {
      "type": "mrkdwn",
      "text": "✅ Video processed\n*Title:* {title}\n*Duration:* {duration}\n*URL:* {url}"
    }
  }]
}
```

Slack webhook is optional — the workflow gracefully skips the notification step if `SLACK_WEBHOOK_URL` is unset.

## Real-World Numbers

Processing a Nomic AEC explainer video (18MB / 8m17s):
- Transcription accuracy: 17 domain-specific corrections applied via ASR_CORRECTIONS
- SRT output: 42 cues
- Pipeline runtime: ~4 minutes on GitHub Actions

## What Makes This Robust

- **Duplicate prevention**: slug dedup checks git log for same title within 1 hour
- **Quota guard**: aborts before hitting YouTube API limits (6/day)
- **Graceful failures**: each step writes outputs to `$GITHUB_OUTPUT` so downstream steps can skip cleanly

The human work per video dropped from 2-3 hours to under 5 minutes. The pipeline handles everything else.
