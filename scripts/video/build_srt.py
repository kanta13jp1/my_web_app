"""Build a SubRip (SRT) subtitle file from an ElevenLabs Scribe transcript.

Used by .github/workflows/notebooklm-video-pipeline.yml Step 3 (Win版#132 part 32).

Splitting rules (tuned for Japanese explainer videos):
  1. Hard break after sentence-ending punctuation (。 . ？ ! ?).
  2. Soft break after 18 visible chars OR after a sub-clause comma (、 ,).
  3. Hard break after 4 seconds of cue duration.
  4. Hard cap at 28 visible chars per cue (force split mid-word if needed).

ASR corrections:
  Optional `ASR_CORRECTIONS` env var (JSON dict {wrong: correct}) applied as
  literal substring replacement to the concatenated text. Use to fix common
  Scribe mistakes like 製品 misheard as 正比.

Usage:
    python videos/build_srt.py <transcript.json> <output.srt>
    ASR_CORRECTIONS='{"正比":"製品"}' python videos/build_srt.py in.json out.srt
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

PUNCT_HARD = "。.?？!！"
PUNCT_SOFT = "、,"
SOFT_LEN = 18
HARD_LEN = 28
MAX_DURATION_S = 4.0


def fmt_timestamp(seconds: float) -> str:
    """Format float seconds as SRT timestamp HH:MM:SS,mmm."""
    if seconds < 0:
        seconds = 0.0
    total_ms = int(round(seconds * 1000))
    h, rem_ms = divmod(total_ms, 3600 * 1000)
    m, rem_ms = divmod(rem_ms, 60 * 1000)
    s, ms = divmod(rem_ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def apply_corrections(text: str, corrections: dict[str, str]) -> str:
    if not corrections:
        return text
    for wrong, correct in corrections.items():
        if wrong:
            text = text.replace(wrong, correct)
    return text


def build_cues(words: list[dict]) -> list[dict]:
    """Walk Scribe word entries and emit cue dicts {start, end, text}.

    Scribe `words` entries have type 'word', 'spacing', or 'audio_event'.
    `audio_event` text is wrapped in parens. `spacing` carries silence only —
    skip its text but use the gap for cue boundary decisions.
    """
    cues: list[dict] = []
    cur_text: list[str] = []
    cur_start: float | None = None
    cur_end: float | None = None

    def flush() -> None:
        nonlocal cur_text, cur_start, cur_end
        if not cur_text or cur_start is None or cur_end is None:
            cur_text, cur_start, cur_end = [], None, None
            return
        text = "".join(cur_text).strip()
        if text:
            cues.append({"start": cur_start, "end": cur_end, "text": text})
        cur_text, cur_start, cur_end = [], None, None

    for w in words:
        wtype = w.get("type", "word")
        raw = (w.get("text") or "")
        start = w.get("start")
        end = w.get("end", start)

        if wtype == "spacing":
            continue
        if wtype == "audio_event":
            piece = raw.strip()
            if piece and not piece.startswith("("):
                piece = f"({piece})"
        else:
            piece = raw

        if not piece:
            continue
        if start is None or end is None:
            continue

        if cur_start is None:
            cur_start = float(start)
        cur_end = float(end)
        cur_text.append(piece)

        joined = "".join(cur_text)
        joined_len = len(joined.strip())
        duration = cur_end - cur_start

        last_char = joined[-1] if joined else ""

        if last_char in PUNCT_HARD:
            flush()
            continue
        if duration >= MAX_DURATION_S:
            flush()
            continue
        if joined_len >= HARD_LEN:
            flush()
            continue
        if joined_len >= SOFT_LEN and last_char in PUNCT_SOFT:
            flush()
            continue

    flush()
    return cues


def split_long_cues(cues: list[dict]) -> list[dict]:
    """Force-split any cue exceeding HARD_LEN visible chars.

    The build_cues loop already guards on HARD_LEN, but a single Scribe
    'word' entry can itself exceed the cap (e.g. a long compound proper
    noun). This pass slices such cues uniformly across their duration so
    no cue ever overflows the on-screen budget.
    """
    out: list[dict] = []
    for cue in cues:
        text = cue["text"]
        if len(text) <= HARD_LEN:
            out.append(cue)
            continue
        n = (len(text) + HARD_LEN - 1) // HARD_LEN
        seg_dur = (cue["end"] - cue["start"]) / n
        for i in range(n):
            piece = text[i * HARD_LEN : (i + 1) * HARD_LEN]
            if not piece:
                continue
            out.append({
                "start": cue["start"] + i * seg_dur,
                "end": cue["start"] + (i + 1) * seg_dur,
                "text": piece,
            })
    return out


def render_srt(cues: list[dict]) -> str:
    blocks: list[str] = []
    for i, cue in enumerate(cues, start=1):
        blocks.append(
            f"{i}\n"
            f"{fmt_timestamp(cue['start'])} --> {fmt_timestamp(cue['end'])}\n"
            f"{cue['text']}\n"
        )
    return "\n".join(blocks)


def load_corrections() -> dict[str, str]:
    raw = os.environ.get("ASR_CORRECTIONS", "").strip()
    if not raw or raw == "{}":
        return {}
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        sys.exit(f"ASR_CORRECTIONS env var is not valid JSON: {e}")
    if not isinstance(data, dict):
        sys.exit("ASR_CORRECTIONS must be a JSON object {wrong: correct}")
    return {str(k): str(v) for k, v in data.items()}


def main() -> int:
    ap = argparse.ArgumentParser(description="Build an SRT subtitle file from a Scribe transcript")
    ap.add_argument("transcript", type=Path, help="Path to ElevenLabs Scribe JSON")
    ap.add_argument("output", type=Path, help="Path to write .srt file")
    args = ap.parse_args()

    if not args.transcript.exists():
        print(f"transcript not found: {args.transcript}", file=sys.stderr)
        return 2

    payload = json.loads(args.transcript.read_text(encoding="utf-8"))
    words = payload.get("words", []) if isinstance(payload, dict) else []
    if not words:
        print("transcript contains no 'words' entries — refusing to emit empty SRT", file=sys.stderr)
        return 2

    corrections = load_corrections()
    cues = build_cues(words)
    cues = split_long_cues(cues)

    if corrections:
        for cue in cues:
            cue["text"] = apply_corrections(cue["text"], corrections)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render_srt(cues), encoding="utf-8")
    print(f"wrote {len(cues)} cues to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
