"""Build a Shorts repurposing package from a NotebookLM video transcript.

The script intentionally stops before expensive media rendering. It produces
deterministic clip candidates, per-clip SRT/VTT files, ffmpeg render commands,
social post drafts, and provenance metadata so the existing video pipeline can
fan out long AI University episodes into 9:16 assets after upload.

Example:
    python scripts/video/build_shorts_package.py videos/edit/transcripts/demo.json \
      --source-video videos/demo.mp4 \
      --source-url https://youtu.be/example \
      --title "AI University demo" \
      --output-dir videos/shorts
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from build_srt import build_cues, fmt_timestamp, render_srt, split_long_cues

CANVAS_WIDTH = 1080
CANVAS_HEIGHT = 1920
DEFAULT_MIN_SEC = 60.0
DEFAULT_MAX_SEC = 90.0
DEFAULT_TARGET_SEC = 75.0
MAX_TITLE_CHARS = 52
HOOK_TERMS = (
    "ai",
    "agent",
    "automation",
    "codex",
    "claude",
    "gemini",
    "notebooklm",
    "mcp",
    "github",
    "slack",
    "notion",
    "zero",
    "today",
    "why",
    "how",
)


@dataclass(frozen=True)
class ClipCandidate:
    start: float
    end: float
    anchor_start: float
    score: float
    reason: str

    @property
    def duration(self) -> float:
        return max(0.0, self.end - self.start)


def load_transcript(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit("transcript must be a JSON object")
    words = data.get("words")
    if not isinstance(words, list) or not words:
        raise SystemExit("transcript contains no words[] entries")
    return data


def transcript_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def transcript_duration(words: list[dict[str, Any]]) -> float:
    ends = []
    for word in words:
        value = word.get("end", word.get("start"))
        if isinstance(value, (int, float)):
            ends.append(float(value))
    return max(ends) if ends else 0.0


def clean_text(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def clip_text(cues: list[dict[str, Any]], start: float, end: float, max_chars: int = 260) -> str:
    parts = [
        str(cue.get("text", ""))
        for cue in cues
        if float(cue.get("end", 0.0)) > start and float(cue.get("start", 0.0)) < end
    ]
    text = clean_text(" ".join(parts))
    if len(text) <= max_chars:
        return text
    return text[: max_chars - 1].rstrip() + "..."


def score_cue(cue: dict[str, Any]) -> tuple[float, list[str]]:
    text = clean_text(str(cue.get("text", ""))).lower()
    score = 1.0
    reasons: list[str] = []
    if "?" in text:
        score += 1.2
        reasons.append("question hook")
    if re.search(r"\d", text):
        score += 0.7
        reasons.append("numbered claim")
    matched_terms = [term for term in HOOK_TERMS if term in text]
    if matched_terms:
        score += min(2.0, 0.35 * len(matched_terms))
        reasons.append("topic terms: " + ", ".join(matched_terms[:4]))
    cue_duration = float(cue.get("end", 0.0)) - float(cue.get("start", 0.0))
    if 1.5 <= cue_duration <= 4.5:
        score += 0.3
        reasons.append("clear subtitle beat")
    return score, reasons or ["evenly spaced candidate"]


def make_window(anchor: float, total_duration: float, min_sec: float, max_sec: float) -> tuple[float, float]:
    target = min(DEFAULT_TARGET_SEC, max_sec)
    if total_duration <= max_sec:
        return 0.0, total_duration
    target = max(min_sec, min(max_sec, target))
    start = max(0.0, anchor - target / 2.0)
    end = start + target
    if end > total_duration:
        end = total_duration
        start = max(0.0, end - target)
    return round(start, 3), round(end, 3)


def overlaps_too_much(candidate: ClipCandidate, selected: list[ClipCandidate]) -> bool:
    for existing in selected:
        overlap = max(0.0, min(candidate.end, existing.end) - max(candidate.start, existing.start))
        if overlap / max(1.0, min(candidate.duration, existing.duration)) > 0.45:
            return True
    return False


def select_clips(
    cues: list[dict[str, Any]],
    words: list[dict[str, Any]],
    count: int,
    min_sec: float,
    max_sec: float,
) -> list[ClipCandidate]:
    total = transcript_duration(words)
    if total <= 0:
        raise SystemExit("transcript duration is zero")

    scored: list[ClipCandidate] = []
    for cue in cues:
        cue_start = float(cue.get("start", 0.0))
        cue_end = float(cue.get("end", cue_start))
        anchor = (cue_start + cue_end) / 2.0
        start, end = make_window(anchor, total, min_sec, max_sec)
        score, reasons = score_cue(cue)
        scored.append(ClipCandidate(start, end, cue_start, score, "; ".join(reasons)))

    selected: list[ClipCandidate] = []
    for candidate in sorted(scored, key=lambda item: (-item.score, item.start)):
        if candidate.duration < min(min_sec, total):
            continue
        if overlaps_too_much(candidate, selected):
            continue
        selected.append(candidate)
        if len(selected) >= count:
            break

    if len(selected) < count and total > min_sec:
        usable = max(1.0, total - min_sec)
        slots = count - len(selected)
        for i in range(slots):
            anchor = (i + 0.5) * usable / max(1, slots) + min_sec / 2.0
            start, end = make_window(anchor, total, min_sec, max_sec)
            candidate = ClipCandidate(start, end, anchor, 0.5, "fallback evenly spaced window")
            if not overlaps_too_much(candidate, selected):
                selected.append(candidate)

    if not selected:
        selected.append(ClipCandidate(0.0, total, 0.0, 0.1, "short source fallback"))

    return sorted(selected[:count], key=lambda item: item.start)


def relative_cues(cues: list[dict[str, Any]], start: float, end: float) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for cue in cues:
        cue_start = float(cue.get("start", 0.0))
        cue_end = float(cue.get("end", cue_start))
        if cue_end <= start or cue_start >= end:
            continue
        out.append({
            **cue,
            "start": max(0.0, cue_start - start),
            "end": min(end, cue_end) - start,
        })
    return out


def render_vtt(cues: list[dict[str, Any]]) -> str:
    lines = ["WEBVTT", ""]
    for cue in cues:
        start = fmt_timestamp(float(cue["start"])).replace(",", ".")
        end = fmt_timestamp(float(cue["end"])).replace(",", ".")
        lines.extend([f"{start} --> {end}", str(cue["text"]), ""])
    return "\n".join(lines)


def caption_style() -> dict[str, Any]:
    return {
        "canvas": {"width": CANVAS_WIDTH, "height": CANVAS_HEIGHT, "aspect_ratio": "9:16"},
        "safe_zone": {
            "top_px": 220,
            "bottom_px": 320,
            "left_px": 72,
            "right_px": 72,
        },
        "subtitle": {
            "font": "Noto Sans CJK JP",
            "font_size_px": 46,
            "outline_px": 3,
            "shadow_px": 1,
            "alignment": "bottom-center",
            "max_lines": 3,
            "max_width_px": 936,
            "active_word": {
                "enabled": True,
                "color": "#FF6A33",
                "rule": "highlight hook nouns, numbers, and platform names",
            },
        },
        "validation": {
            "subtitle_box_top_px": 1430,
            "subtitle_box_bottom_px": 1600,
            "within_safe_zone": True,
        },
    }


def ffmpeg_command(source_video: str, clip_stem: str, start: float, end: float) -> str:
    duration = max(0.0, end - start)
    style = (
        "FontName=Noto Sans CJK JP,FontSize=46,Outline=3,Shadow=1,"
        "Alignment=2,MarginV=320,PrimaryColour=&H00FFFFFF&"
    )
    return (
        "ffmpeg -y "
        f"-ss {start:.3f} -t {duration:.3f} -i \"{source_video}\" "
        "-vf "
        "\"scale=1080:1920:force_original_aspect_ratio=increase,"
        "crop=1080:1920,"
        f"subtitles={clip_stem}.srt:force_style='{style}'\" "
        "-c:v libx264 -preset fast -crf 22 -c:a aac -b:a 128k "
        f"\"{clip_stem}.mp4\""
    )


def social_posts(title: str, source_url: str, clips: list[dict[str, Any]]) -> list[dict[str, Any]]:
    posts: list[dict[str, Any]] = []
    for clip in clips:
        hook = clip["hook"]
        index = clip["index"]
        tags = ["#AIUniversity", "#NotebookLM", "#Shorts", "#buildinpublic"]
        posts.append({
            "clip_index": index,
            "platform": "x",
            "text": f"{hook}\n\nFull lesson: {source_url}\n{' '.join(tags)}",
            "fixed_reply": f"Source: {title}. Clip {index} includes AI-generated captions and provenance.",
        })
        posts.append({
            "clip_index": index,
            "platform": "youtube_shorts",
            "title": truncate_title(f"{title}: {hook}"),
            "description": f"Generated from the AI University long-form lesson.\nSource: {source_url}\n{' '.join(tags)}",
        })
    return posts


def truncate_title(value: str) -> str:
    value = clean_text(value)
    if len(value) <= MAX_TITLE_CHARS:
        return value
    return value[: MAX_TITLE_CHARS - 1].rstrip() + "..."


def write_package(args: argparse.Namespace) -> dict[str, Any]:
    transcript = load_transcript(args.transcript)
    words = transcript["words"]
    cues = split_long_cues(build_cues(words))
    clips = select_clips(cues, words, args.count, args.min_sec, args.max_sec)
    out_dir = args.output_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    source_video = str(args.source_video or args.source_url or "source.mp4")
    source_url = str(args.source_url or args.source_video or "")
    style = caption_style()
    clip_entries: list[dict[str, Any]] = []

    for i, clip in enumerate(clips, start=1):
        stem = f"clip_{i:02d}"
        rel = relative_cues(cues, clip.start, clip.end)
        srt_text = render_srt(rel, diarize=False)
        vtt_text = render_vtt(rel)
        (out_dir / f"{stem}.srt").write_text(srt_text, encoding="utf-8")
        (out_dir / f"{stem}.vtt").write_text(vtt_text, encoding="utf-8")
        command = ffmpeg_command(source_video, stem, clip.start, clip.end)
        (out_dir / f"{stem}.ffmpeg.txt").write_text(command + "\n", encoding="utf-8")
        hook = truncate_title(clip_text(cues, clip.start, clip.end, 96) or args.title)
        clip_entries.append({
            "index": i,
            "id": stem,
            "start_sec": clip.start,
            "end_sec": clip.end,
            "duration_sec": round(clip.duration, 3),
            "hook": hook,
            "selection_reason": clip.reason,
            "caption_style": style,
            "files": {
                "srt": f"{stem}.srt",
                "vtt": f"{stem}.vtt",
                "ffmpeg_command": f"{stem}.ffmpeg.txt",
                "output_video": f"{stem}.mp4",
            },
        })

    package = {
        "schema": "jibun.ai_university.shorts_package.v1",
        "title": args.title,
        "source": {
            "video": str(args.source_video or ""),
            "url": source_url,
            "transcript": str(args.transcript),
            "transcript_sha256": transcript_sha256(args.transcript),
        },
        "render_target": {
            "platforms": ["youtube_shorts", "tiktok", "x"],
            "aspect_ratio": "9:16",
            "width": CANVAS_WIDTH,
            "height": CANVAS_HEIGHT,
        },
        "clips": clip_entries,
        "social_posts": social_posts(args.title, source_url, clip_entries),
        "provenance": {
            "generated_by": "scripts/video/build_shorts_package.py",
            "requires_ai_generated_disclosure": True,
            "reuse_policy": "Pass rendered assets to x-media-post or viral-growth-engine; do not post directly from this script.",
        },
    }
    (out_dir / "shorts_package.json").write_text(json.dumps(package, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (out_dir / "social_posts.json").write_text(json.dumps(package["social_posts"], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return package


def main() -> int:
    parser = argparse.ArgumentParser(description="Build AI University Shorts package metadata from a transcript")
    parser.add_argument("transcript", type=Path, help="ElevenLabs Scribe transcript JSON")
    parser.add_argument("--source-video", type=Path, default=None, help="Original long-form video path")
    parser.add_argument("--source-url", default="", help="Published source video URL")
    parser.add_argument("--title", default="AI University lesson", help="Long-form lesson title")
    parser.add_argument("--output-dir", type=Path, default=Path("videos/shorts"), help="Directory for package files")
    parser.add_argument("--count", type=int, default=3, help="Number of clip candidates to emit")
    parser.add_argument("--min-sec", type=float, default=DEFAULT_MIN_SEC, help="Minimum target clip length")
    parser.add_argument("--max-sec", type=float, default=DEFAULT_MAX_SEC, help="Maximum target clip length")
    args = parser.parse_args()

    if args.count < 1 or args.count > 5:
        raise SystemExit("--count must be between 1 and 5")
    if args.min_sec <= 0 or args.max_sec < args.min_sec:
        raise SystemExit("--min-sec/--max-sec are invalid")
    if args.source_video and not args.source_video.exists():
        raise SystemExit(f"source video not found: {args.source_video}")

    package = write_package(args)
    print(f"wrote {len(package['clips'])} clip candidates to {args.output_dir / 'shorts_package.json'}")
    for clip in package["clips"]:
        print(f"- {clip['id']} {clip['start_sec']:.1f}-{clip['end_sec']:.1f}s {clip['hook']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
