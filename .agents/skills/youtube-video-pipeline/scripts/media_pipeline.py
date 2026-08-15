#!/usr/bin/env python3
"""Deterministic local media workflow for the YouTube video pipeline.

Subcommands:
  check          Verify required local tools and Python packages.
  reference      Fetch YouTube metadata and a caption track with yt-dlp.
  devices        List DirectShow audio input devices on Windows.
  record-start   Start a detached raw-PCM microphone recording.
  record-status  Inspect the active recording state.
  record-stop    Stop recording and create original + normalized MP3 files.
  build          Trim audio, align script paragraphs, render and verify MP4.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Iterable


SAMPLE_RATE = 48_000
CHANNELS = 1
CREATE_NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0x08000000)
CREATE_NEW_PROCESS_GROUP = getattr(
    subprocess, "CREATE_NEW_PROCESS_GROUP", 0x00000200
)


class PipelineError(RuntimeError):
    pass


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False, indent=2))


def executable(name: str) -> str:
    value = shutil.which(name)
    if not value:
        raise PipelineError(f"Required executable was not found: {name}")
    return value


def run(
    args: list[str],
    *,
    check: bool = True,
    capture: bool = True,
    timeout: float | None = None,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        args,
        check=False,
        capture_output=capture,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )
    if check and result.returncode != 0:
        detail = (result.stderr or result.stdout or "").strip()
        raise PipelineError(
            f"Command failed ({result.returncode}): {' '.join(args[:4])}\n{detail}"
        )
    return result


def probe(path: Path) -> dict[str, Any]:
    result = run(
        [
            executable("ffprobe"),
            "-v",
            "error",
            "-show_entries",
            "format=duration,size:stream=codec_name,width,height,r_frame_rate,sample_rate,channels",
            "-of",
            "json",
            str(path),
        ]
    )
    return json.loads(result.stdout)


def duration_seconds(path: Path) -> float:
    data = probe(path)
    try:
        return float(data["format"]["duration"])
    except (KeyError, TypeError, ValueError) as exc:
        raise PipelineError(f"Could not determine duration: {path}") from exc


def volume_stats(path: Path) -> dict[str, str]:
    sink = "NUL" if os.name == "nt" else "/dev/null"
    result = run(
        [
            executable("ffmpeg"),
            "-hide_banner",
            "-i",
            str(path),
            "-af",
            "volumedetect",
            "-f",
            "null",
            sink,
        ],
        check=False,
    )
    output = f"{result.stdout}\n{result.stderr}"
    mean = re.search(r"mean_volume:\s*([^\r\n]+)", output)
    peak = re.search(r"max_volume:\s*([^\r\n]+)", output)
    return {
        "mean_volume": mean.group(1).strip() if mean else "unknown",
        "max_volume": peak.group(1).strip() if peak else "unknown",
    }


def cmd_check(_: argparse.Namespace) -> None:
    tools: dict[str, str | None] = {}
    for name in ("ffmpeg", "ffprobe", "yt-dlp"):
        tools[name] = shutil.which(name)

    packages: dict[str, bool] = {}
    for name in ("PIL", "googleapiclient", "google_auth_oauthlib"):
        try:
            __import__(name)
            packages[name] = True
        except ImportError:
            packages[name] = False

    fonts = find_fonts(required=False)
    ready = all(tools.values()) and packages["PIL"] and bool(fonts.get("bold"))
    emit(
        {
            "status": "READY" if ready else "MISSING_DEPENDENCIES",
            "python": sys.version.split()[0],
            "tools": tools,
            "packages": packages,
            "fonts": {key: str(value) if value else None for key, value in fonts.items()},
        }
    )
    if not ready:
        raise SystemExit(2)


def cmd_reference(args: argparse.Namespace) -> None:
    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    ytdlp = executable("yt-dlp")
    metadata_result = run(
        [ytdlp, "--dump-single-json", "--skip-download", "--no-warnings", args.url],
        timeout=120,
    )
    metadata = json.loads(metadata_result.stdout)
    video_id = str(metadata.get("id") or "video")
    official = metadata.get("subtitles") or {}
    automatic = metadata.get("automatic_captions") or {}
    source = None
    caption_args: list[str] = []
    if args.language in official:
        source = "official"
        caption_args = ["--write-subs"]
    elif args.allow_auto and args.language in automatic:
        source = "automatic"
        caption_args = ["--write-auto-subs"]

    caption_path: Path | None = None
    if source:
        output_template = output_dir / "%(id)s.%(ext)s"
        run(
            [
                ytdlp,
                *caption_args,
                "--sub-langs",
                args.language,
                "--sub-format",
                "vtt",
                "--skip-download",
                "--no-warnings",
                "-o",
                str(output_template),
                args.url,
            ],
            timeout=180,
        )
        candidate = output_dir / f"{video_id}.{args.language}.vtt"
        if candidate.exists():
            caption_path = candidate
        else:
            matches = sorted(output_dir.glob(f"{video_id}*.vtt"))
            caption_path = matches[0] if matches else None

    summary = {
        "id": video_id,
        "title": metadata.get("title"),
        "uploader": metadata.get("uploader"),
        "duration_seconds": metadata.get("duration"),
        "webpage_url": metadata.get("webpage_url") or args.url,
        "official_subtitle_languages": sorted(official.keys()),
        "automatic_caption_languages": sorted(automatic.keys()),
        "selected_caption_source": source,
        "caption_path": str(caption_path) if caption_path else None,
        "warning": (
            "Automatic captions can contain transcription errors."
            if source == "automatic"
            else None
        ),
    }
    (output_dir / "reference.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    emit(summary)


def directshow_devices() -> tuple[list[str], str]:
    result = run(
        [
            executable("ffmpeg"),
            "-hide_banner",
            "-list_devices",
            "true",
            "-f",
            "dshow",
            "-i",
            "dummy",
        ],
        check=False,
    )
    output = f"{result.stdout}\n{result.stderr}"
    devices = re.findall(r'"([^"]+)"\s+\(audio\)', output)
    return list(dict.fromkeys(devices)), output


def cmd_devices(_: argparse.Namespace) -> None:
    if os.name != "nt":
        raise PipelineError("The bundled recorder currently supports Windows DirectShow.")
    devices, _ = directshow_devices()
    emit({"audio_devices": devices})


def recording_state_path(output_dir: Path) -> Path:
    return output_dir / ".recording.json"


def process_image_name(pid: int) -> str | None:
    if os.name != "nt":
        try:
            os.kill(pid, 0)
            return "unknown"
        except OSError:
            return None
    result = run(
        ["tasklist", "/FI", f"PID eq {pid}", "/FO", "CSV", "/NH"],
        check=False,
    )
    line = result.stdout.strip()
    if not line or line.startswith("INFO:"):
        return None
    try:
        row = next(csv.reader([line]))
        return row[0] if row else None
    except (csv.Error, StopIteration):
        return None


def stop_ffmpeg(pid: int) -> None:
    name = process_image_name(pid)
    if not name:
        return
    if name.lower() != "ffmpeg.exe":
        raise PipelineError(f"PID {pid} is {name}, not ffmpeg.exe; refusing to stop it.")
    result = run(["taskkill", "/PID", str(pid), "/T", "/F"], check=False)
    if result.returncode not in (0, 128):
        raise PipelineError(f"Could not stop ffmpeg PID {pid}: {result.stderr.strip()}")


def cmd_record_start(args: argparse.Namespace) -> None:
    if os.name != "nt":
        raise PipelineError("The bundled recorder currently supports Windows DirectShow.")
    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    state_path = recording_state_path(output_dir)
    if state_path.exists():
        previous = json.loads(state_path.read_text(encoding="utf-8"))
        pid = int(previous.get("pid", 0))
        if pid and process_image_name(pid):
            raise PipelineError(f"A recording is already active with PID {pid}.")
        state_path.unlink()

    devices, _ = directshow_devices()
    if args.device not in devices:
        raise PipelineError(
            f"Audio device was not found: {args.device}\nAvailable: {devices}"
        )

    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    raw_path = output_dir / f"recording_{stamp}.pcm"
    log_path = output_dir / f"recording_{stamp}.ffmpeg.log"
    command = [
        executable("ffmpeg"),
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-f",
        "dshow",
        "-i",
        f"audio={args.device}",
        "-ac",
        str(CHANNELS),
        "-ar",
        str(SAMPLE_RATE),
        "-c:a",
        "pcm_s16le",
        "-f",
        "s16le",
        str(raw_path),
    ]
    log_handle = log_path.open("wb")
    try:
        process = subprocess.Popen(
            command,
            stdin=subprocess.DEVNULL,
            stdout=log_handle,
            stderr=log_handle,
            creationflags=CREATE_NO_WINDOW | CREATE_NEW_PROCESS_GROUP,
        )
    finally:
        log_handle.close()

    state = {
        "status": "starting",
        "pid": process.pid,
        "device": args.device,
        "raw_path": str(raw_path),
        "log_path": str(log_path),
        "sample_rate": SAMPLE_RATE,
        "channels": CHANNELS,
        "started_at": dt.datetime.now().astimezone().isoformat(),
    }
    state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")

    deadline = time.time() + args.startup_timeout
    size = 0
    while time.time() < deadline:
        if process.poll() is not None:
            detail = log_path.read_text(encoding="utf-8", errors="replace")
            state_path.unlink(missing_ok=True)
            raise PipelineError(
                f"Recorder exited during startup ({process.returncode}). Nothing was recorded.\n{detail}"
            )
        size = raw_path.stat().st_size if raw_path.exists() else 0
        if size >= args.minimum_bytes:
            break
        time.sleep(0.25)

    if size < args.minimum_bytes:
        stop_ffmpeg(process.pid)
        state_path.unlink(missing_ok=True)
        raise PipelineError(
            f"The recorder created only {size} bytes. Nothing usable was recorded."
        )

    state["status"] = "RECORDING_CONFIRMED"
    state["bytes_at_confirmation"] = size
    state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")
    emit(state)


def load_recording_state(output_dir: Path) -> tuple[Path, dict[str, Any]]:
    state_path = recording_state_path(output_dir)
    if not state_path.exists():
        raise PipelineError(f"No active recording state found: {state_path}")
    return state_path, json.loads(state_path.read_text(encoding="utf-8"))


def cmd_record_status(args: argparse.Namespace) -> None:
    output_dir = Path(args.output_dir).expanduser().resolve()
    state_path, state = load_recording_state(output_dir)
    raw_path = Path(state["raw_path"])
    image_name = process_image_name(int(state["pid"]))
    emit(
        {
            **state,
            "state_path": str(state_path),
            "process_image_name": image_name,
            "process_alive": bool(image_name),
            "raw_bytes": raw_path.stat().st_size if raw_path.exists() else 0,
        }
    )


def cmd_record_stop(args: argparse.Namespace) -> None:
    output_dir = Path(args.output_dir).expanduser().resolve()
    state_path, state = load_recording_state(output_dir)
    pid = int(state["pid"])
    stop_ffmpeg(pid)
    time.sleep(0.5)

    raw_path = Path(state["raw_path"]).resolve()
    if raw_path.parent != output_dir or not raw_path.name.startswith("recording_"):
        raise PipelineError(f"Unexpected raw recording path: {raw_path}")
    if not raw_path.exists() or raw_path.stat().st_size < args.minimum_bytes:
        raise PipelineError("The raw recording is missing or too short; no MP3 was created.")

    stem = raw_path.stem
    original_path = output_dir / f"{stem}_original.mp3"
    normalized_path = output_dir / f"{stem}_normalized.mp3"
    ffmpeg = executable("ffmpeg")
    run(
        [
            ffmpeg,
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-f",
            "s16le",
            "-ar",
            str(state.get("sample_rate", SAMPLE_RATE)),
            "-ac",
            str(state.get("channels", CHANNELS)),
            "-i",
            str(raw_path),
            "-codec:a",
            "libmp3lame",
            "-b:a",
            "192k",
            str(original_path),
        ]
    )
    run(
        [
            ffmpeg,
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-i",
            str(original_path),
            "-af",
            "highpass=f=70,lowpass=f=12000,loudnorm=I=-16:TP=-1.5:LRA=11",
            "-ar",
            str(SAMPLE_RATE),
            "-codec:a",
            "libmp3lame",
            "-b:a",
            "192k",
            str(normalized_path),
        ]
    )
    normalized_probe = probe(normalized_path)
    if not original_path.exists() or not normalized_path.exists():
        raise PipelineError("MP3 conversion did not create both expected files.")

    result = {
        "status": "READY",
        "original_path": str(original_path),
        "normalized_path": str(normalized_path),
        "duration_seconds": float(normalized_probe["format"]["duration"]),
        "raw_bytes": raw_path.stat().st_size,
        "normalized_bytes": int(normalized_probe["format"]["size"]),
        **volume_stats(normalized_path),
    }
    (output_dir / ".recording-last.json").write_text(
        json.dumps({**state, **result}, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    if not args.keep_raw:
        raw_path.unlink()
        result["raw_removed"] = True
    else:
        result["raw_removed"] = False
    state_path.unlink(missing_ok=True)
    emit(result)


def silence_intervals(
    path: Path, *, noise_db: float = -40.0, min_duration: float = 0.35
) -> list[dict[str, float]]:
    sink = "NUL" if os.name == "nt" else "/dev/null"
    result = run(
        [
            executable("ffmpeg"),
            "-hide_banner",
            "-i",
            str(path),
            "-af",
            f"silencedetect=noise={noise_db}dB:d={min_duration}",
            "-f",
            "null",
            sink,
        ],
        check=False,
    )
    output = f"{result.stdout}\n{result.stderr}"
    intervals: list[dict[str, float]] = []
    pending: float | None = None
    for line in output.splitlines():
        start_match = re.search(r"silence_start:\s*([0-9.]+)", line)
        if start_match:
            pending = float(start_match.group(1))
        end_match = re.search(
            r"silence_end:\s*([0-9.]+)\s*\|\s*silence_duration:\s*([0-9.]+)",
            line,
        )
        if end_match:
            end = float(end_match.group(1))
            duration = float(end_match.group(2))
            start = pending if pending is not None else max(0.0, end - duration)
            intervals.append(
                {"start": start, "end": end, "duration": duration, "mid": (start + end) / 2}
            )
            pending = None
    return intervals


def detect_active_bounds(
    path: Path,
    *,
    noise_db: float,
    min_outer_silence: float,
    pad: float,
) -> tuple[float, float, list[dict[str, float]]]:
    duration = duration_seconds(path)
    raw_intervals = silence_intervals(path, noise_db=noise_db, min_duration=0.5)
    intervals: list[dict[str, float]] = []
    for item in raw_intervals:
        if not intervals:
            intervals.append(dict(item))
            continue
        previous = intervals[-1]
        gap = item["start"] - previous["end"]
        # Mouth noise or a small click can split one long leading/trailing wait
        # into multiple silence intervals. Bridge only short gaps adjacent to a
        # genuinely long silence so ordinary sentence pauses stay independent.
        if gap <= 1.0 and (
            previous["duration"] >= min_outer_silence
            or item["duration"] >= min_outer_silence
        ):
            previous["end"] = item["end"]
            previous["duration"] = previous["end"] - previous["start"]
            previous["mid"] = (previous["start"] + previous["end"]) / 2
        else:
            intervals.append(dict(item))
    start = 0.0
    end = duration
    if intervals:
        first = intervals[0]
        if first["start"] <= 0.2 and first["duration"] >= min_outer_silence:
            start = max(0.0, first["end"] - pad)
        last = intervals[-1]
        if last["end"] >= duration - 0.25 and last["duration"] >= min_outer_silence:
            end = min(duration, last["start"] + pad)
    if end - start < 1.0:
        raise PipelineError(
            f"Detected active range is too short: start={start:.3f}, end={end:.3f}"
        )
    return start, end, intervals


def read_paragraphs(path: Path) -> list[str]:
    raw = path.read_text(encoding="utf-8-sig").replace("\r\n", "\n").strip()
    if not raw:
        raise PipelineError(f"Narration script is empty: {path}")
    blocks = [re.sub(r"\s*\n\s*", "", block).strip() for block in re.split(r"\n\s*\n", raw)]
    blocks = [block for block in blocks if block]
    if len(blocks) == 1:
        lines = [line.strip() for line in raw.splitlines() if line.strip()]
        if len(lines) > 1:
            blocks = lines
    return blocks


def choose_boundaries(targets: list[float], candidates: list[float]) -> list[float]:
    if not targets:
        return []
    if len(candidates) < len(targets):
        return targets
    n, m = len(targets), len(candidates)
    infinity = float("inf")
    dp = [[infinity] * (m + 1) for _ in range(n + 1)]
    previous = [[None] * (m + 1) for _ in range(n + 1)]
    for j in range(m + 1):
        dp[0][j] = 0.0
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            if dp[i][j - 1] < dp[i][j]:
                dp[i][j] = dp[i][j - 1]
                previous[i][j] = (i, j - 1, False)
            value = dp[i - 1][j - 1] + (candidates[j - 1] - targets[i - 1]) ** 2
            if value < dp[i][j]:
                dp[i][j] = value
                previous[i][j] = (i - 1, j - 1, True)
    chosen = []
    i, j = n, m
    while i > 0:
        step = previous[i][j]
        if step is None:
            return targets
        prev_i, prev_j, took = step
        if took:
            chosen.append(candidates[j - 1])
        i, j = prev_i, prev_j
    return list(reversed(chosen))


def split_caption(text: str, max_chars: int = 31) -> list[str]:
    if "|" in text:
        return [part.strip() for part in text.split("|", 1) if part.strip()]
    compact = text.strip()
    if len(compact) <= max_chars:
        return [compact]
    midpoint = len(compact) // 2
    candidates = [
        index + 1
        for index, char in enumerate(compact)
        if char in "、。！？,.!?：:；;）】」』"
        and max(8, midpoint - 14)
        <= index
        <= min(len(compact) - 8, midpoint + 14)
    ]
    split_at = (
        min(candidates, key=lambda value: abs(value - midpoint))
        if candidates
        else midpoint
    )
    return [compact[:split_at].strip(), compact[split_at:].strip()]


def align_cues(
    paragraphs: list[str],
    duration: float,
    pauses: list[float],
) -> list[dict[str, Any]]:
    start = min(0.32, max(0.0, duration * 0.01))
    end = max(start + 0.5, duration - min(0.55, duration * 0.01))
    weights = [max(1, len(re.sub(r"[、。！？\s]", "", text))) for text in paragraphs]
    total = sum(weights)
    targets = []
    cumulative = 0
    for weight in weights[:-1]:
        cumulative += weight
        targets.append(start + (end - start) * cumulative / total)
    candidates = sorted(
        {
            round(value, 3)
            for value in pauses
            if start + 0.55 < value < end - 0.55
        }
    )
    boundaries = choose_boundaries(targets, candidates)
    points = [start, *boundaries, end]
    cues: list[dict[str, Any]] = []
    for index, text in enumerate(paragraphs):
        cues.append(
            {
                "index": index + 1,
                "start": round(points[index], 3),
                "end": round(points[index + 1], 3),
                "text": text,
                "lines": split_caption(text),
            }
        )
    return cues


def srt_time(value: float) -> str:
    milliseconds = max(0, int(round(value * 1000)))
    hours, remainder = divmod(milliseconds, 3_600_000)
    minutes, remainder = divmod(remainder, 60_000)
    seconds, milliseconds = divmod(remainder, 1000)
    return f"{hours:02d}:{minutes:02d}:{seconds:02d},{milliseconds:03d}"


def write_srt(cues: list[dict[str, Any]], path: Path) -> None:
    blocks = []
    for cue in cues:
        text = "\n".join(cue.get("lines") or [cue["text"]])
        blocks.append(
            f"{cue['index']}\n{srt_time(cue['start'])} --> {srt_time(cue['end'])}\n{text}"
        )
    path.write_text("\n\n".join(blocks) + "\n", encoding="utf-8")


def ass_time(value: float) -> str:
    centiseconds = max(0, int(round(value * 100)))
    hours, remainder = divmod(centiseconds, 360_000)
    minutes, remainder = divmod(remainder, 6000)
    seconds, centiseconds = divmod(remainder, 100)
    return f"{hours}:{minutes:02d}:{seconds:02d}.{centiseconds:02d}"


def ass_escape(text: str) -> str:
    return text.replace("\\", r"\\").replace("{", r"\{").replace("}", r"\}")


def write_ass(cues: list[dict[str, Any]], path: Path) -> None:
    header = """[Script Info]
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080
ScaledBorderAndShadow: yes
WrapStyle: 2

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Caption,Yu Gothic UI,44,&H00FFFFFF,&H000000FF,&H00101422,&H78000000,-1,0,0,0,100,100,0,0,1,2,0,2,120,120,118,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
    events = []
    for cue in cues:
        lines = cue.get("lines") or [cue["text"]]
        text = r"\N".join(ass_escape(line) for line in lines)
        events.append(
            f"Dialogue: 0,{ass_time(cue['start'])},{ass_time(cue['end'])},Caption,,0,0,0,,{text}"
        )
    path.write_text(header + "\n".join(events) + "\n", encoding="utf-8-sig")


def find_fonts(*, required: bool = True) -> dict[str, Path | None]:
    candidates = [
        Path(os.environ.get("WINDIR", r"C:\Windows")) / "Fonts",
        Path.home() / "AppData" / "Local" / "Microsoft" / "Windows" / "Fonts",
    ]
    names = {
        "bold": ("YuGothB.ttc", "NotoSansJP-VF.ttf", "meiryob.ttc"),
        "regular": ("YuGothM.ttc", "NotoSansJP-VF.ttf", "meiryo.ttc"),
    }
    result: dict[str, Path | None] = {"bold": None, "regular": None}
    for style, filenames in names.items():
        for directory in candidates:
            for filename in filenames:
                path = directory / filename
                if path.exists():
                    result[style] = path
                    break
            if result[style]:
                break
    if required and not all(result.values()):
        raise PipelineError(f"A Japanese font could not be found: {result}")
    return result


def fit_font(draw: Any, text: str, font_path: Path, max_size: int, max_width: int) -> Any:
    from PIL import ImageFont

    size = max_size
    while size >= 18:
        font = ImageFont.truetype(str(font_path), size)
        if draw.textbbox((0, 0), text, font=font)[2] <= max_width:
            return font
        size -= 2
    return ImageFont.truetype(str(font_path), 18)


def gradient_image(width: int, height: int) -> Any:
    from PIL import Image, ImageDraw

    image = Image.new("RGB", (width, height), "#0B1020")
    draw = ImageDraw.Draw(image)
    left = (11, 16, 32)
    right = (36, 26, 73)
    for x in range(width):
        ratio = x / max(1, width - 1)
        color = tuple(int(left[i] * (1 - ratio) + right[i] * ratio) for i in range(3))
        draw.line([(x, 0), (x, height)], fill=color)
    return image


def draw_centered(draw: Any, box: tuple[int, int, int, int], text: str, font: Any, fill: str) -> None:
    left, top, right, bottom = box
    bounds = draw.textbbox((0, 0), text, font=font)
    width = bounds[2] - bounds[0]
    height = bounds[3] - bounds[1]
    draw.text(
        ((left + right - width) / 2, (top + bottom - height) / 2 - bounds[1]),
        text,
        font=font,
        fill=fill,
    )


def create_visuals(title: str, tagline: str, output_dir: Path) -> tuple[Path, Path]:
    from PIL import ImageDraw, ImageFont

    fonts = find_fonts()
    assert fonts["bold"] and fonts["regular"]
    base = gradient_image(1920, 1080)
    draw = ImageDraw.Draw(base, "RGBA")
    draw.rectangle((0, 0, 1920, 10), fill="#FF8A3D")
    draw.rectangle((0, 10, 1920, 15), fill="#6C63FF")
    draw.rectangle((100, 74, 1820, 994), fill=(5, 8, 22, 110))
    title_font = fit_font(draw, title, fonts["bold"], 72, 1180)
    tagline_font = ImageFont.truetype(str(fonts["regular"]), 36)
    draw.text((140, 96), title, font=title_font, fill="white")
    draw.text((143, 197), tagline, font=tagline_font, fill="#CBD5E1")
    badge_font = ImageFont.truetype(str(fonts["bold"]), 26)
    draw.rectangle((1450, 112, 1735, 170), fill=(108, 99, 255, 215))
    draw_centered(draw, (1450, 112, 1735, 170), "日本語ナレーション", badge_font, "white")
    boxes = [
        ((190, 296, 580, 400), "RECORD", "#FFB27A", (255, 138, 61, 36), "#FF8A3D"),
        ((765, 296, 1155, 400), "SKILL", "#B8B5FF", (108, 99, 255, 40), "#8B86FF"),
        ((1340, 296, 1730, 400), "REPLAY", "#FFB27A", (255, 138, 61, 36), "#FF8A3D"),
    ]
    box_font = ImageFont.truetype(str(fonts["bold"]), 38)
    arrow_font = ImageFont.truetype(str(fonts["bold"]), 48)
    for box, label, text_color, fill_color, outline in boxes:
        draw.rectangle(box, fill=fill_color, outline=outline, width=3)
        draw_centered(draw, box, label, box_font, text_color)
    draw.text((660, 312), "→", font=arrow_font, fill="#94A3B8")
    draw.text((1235, 312), "→", font=arrow_font, fill="#94A3B8")
    draw.rectangle((140, 758, 1780, 982), fill=(3, 6, 17, 205), outline=(255, 255, 255, 26), width=2)
    small_font = ImageFont.truetype(str(fonts["regular"]), 20)
    draw.text((165, 783), "VOICE  •  CODEX WORKFLOW", font=small_font, fill="#94A3B8")
    draw.rectangle((140, 1048, 1780, 1054), fill=(255, 138, 61, 184))
    base_path = output_dir / "base.png"
    base.save(base_path)

    thumb = gradient_image(1280, 720)
    tdraw = ImageDraw.Draw(thumb, "RGBA")
    tdraw.rectangle((0, 0, 1280, 8), fill="#FF8A3D")
    tdraw.rectangle((0, 8, 1280, 13), fill="#6C63FF")
    tdraw.rectangle((54, 44, 1226, 670), fill=(5, 8, 22, 118))
    thumb_title_font = fit_font(tdraw, title, fonts["bold"], 68, 830)
    tdraw.text((84, 73), title, font=thumb_title_font, fill="white")
    tdraw.text((88, 178), tagline, font=ImageFont.truetype(str(fonts["regular"]), 34), fill="#CBD5E1")
    tdraw.rectangle((960, 82, 1172, 134), fill=(108, 99, 255, 225))
    draw_centered(tdraw, (960, 82, 1172, 134), "日本語解説", ImageFont.truetype(str(fonts["bold"]), 28), "white")
    thumb_boxes = [
        ((95, 302, 395, 402), "RECORD", "#FFB27A", (255, 138, 61, 38), "#FF8A3D"),
        ((490, 302, 790, 402), "SKILL", "#B8B5FF", (108, 99, 255, 45), "#8B86FF"),
        ((885, 302, 1185, 402), "REPLAY", "#FFB27A", (255, 138, 61, 38), "#FF8A3D"),
    ]
    thumb_box_font = ImageFont.truetype(str(fonts["bold"]), 40)
    for box, label, text_color, fill_color, outline in thumb_boxes:
        tdraw.rectangle(box, fill=fill_color, outline=outline, width=3)
        draw_centered(tdraw, box, label, thumb_box_font, text_color)
    tdraw.text((438, 315), "→", font=arrow_font, fill="#94A3B8")
    tdraw.text((832, 315), "→", font=arrow_font, fill="#94A3B8")
    footer = ImageFont.truetype(str(fonts["bold"]), 30)
    draw_centered(tdraw, (100, 500, 1180, 565), "SHOW ONCE.  REUSE FOREVER.", footer, "#FF8A3D")
    draw_centered(tdraw, (100, 560, 1180, 620), "VOICE  •  CODEX WORKFLOW", ImageFont.truetype(str(fonts["regular"]), 22), "#94A3B8")
    tdraw.rectangle((88, 632, 1182, 637), fill=(255, 138, 61, 190))
    thumbnail_path = output_dir / "thumbnail.jpg"
    thumb.save(thumbnail_path, quality=94, optimize=True)
    return base_path, thumbnail_path


def escape_filter_path(path: Path) -> str:
    return str(path.resolve()).replace("\\", "/").replace(":", r"\:").replace("'", r"\'")


def verify_video(video_path: Path, contact_sheet: Path) -> dict[str, Any]:
    info = probe(video_path)
    streams = info.get("streams", [])
    video_stream = next((item for item in streams if item.get("width")), None)
    audio_stream = next((item for item in streams if item.get("sample_rate")), None)
    if not video_stream or not audio_stream:
        raise PipelineError("Rendered file is missing a video or audio stream.")
    if video_stream.get("codec_name") != "h264":
        raise PipelineError(f"Unexpected video codec: {video_stream.get('codec_name')}")
    if audio_stream.get("codec_name") != "aac":
        raise PipelineError(f"Unexpected audio codec: {audio_stream.get('codec_name')}")
    if (video_stream.get("width"), video_stream.get("height")) != (1920, 1080):
        raise PipelineError(
            f"Unexpected resolution: {video_stream.get('width')}x{video_stream.get('height')}"
        )
    sink = "NUL" if os.name == "nt" else "/dev/null"
    run([executable("ffmpeg"), "-v", "error", "-i", str(video_path), "-f", "null", sink])
    duration = float(info["format"]["duration"])
    frames = [max(1, int(duration * ratio * 30)) for ratio in (0.1, 0.5, 0.9)]
    selector = "+".join(f"eq(n,{frame})" for frame in frames)
    run(
        [
            executable("ffmpeg"),
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-i",
            str(video_path),
            "-vf",
            f"select='{selector}',scale=960:540,tile=3x1",
            "-frames:v",
            "1",
            str(contact_sheet),
        ]
    )
    return {
        "duration_seconds": duration,
        "size_bytes": int(info["format"]["size"]),
        "video_codec": video_stream.get("codec_name"),
        "audio_codec": audio_stream.get("codec_name"),
        "width": video_stream.get("width"),
        "height": video_stream.get("height"),
        "frame_rate": video_stream.get("r_frame_rate"),
        "sample_rate": audio_stream.get("sample_rate"),
        "channels": audio_stream.get("channels"),
        "full_decode": "ok",
    }


def cmd_build(args: argparse.Namespace) -> None:
    audio_path = Path(args.audio).expanduser().resolve()
    script_path = Path(args.script).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    if not audio_path.exists():
        raise PipelineError(f"Audio file not found: {audio_path}")
    if not script_path.exists():
        raise PipelineError(f"Narration script not found: {script_path}")

    if args.no_auto_trim:
        trim_start, trim_end, outer_silences = 0.0, duration_seconds(audio_path), []
    else:
        trim_start, trim_end, outer_silences = detect_active_bounds(
            audio_path,
            noise_db=args.outer_noise_db,
            min_outer_silence=args.min_outer_silence,
            pad=args.trim_pad,
        )
    prepared_audio = output_dir / "audio_prepared.mp3"
    run(
        [
            executable("ffmpeg"),
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-i",
            str(audio_path),
            "-ss",
            f"{trim_start:.3f}",
            "-to",
            f"{trim_end:.3f}",
            "-af",
            "highpass=f=70,lowpass=f=12000,loudnorm=I=-16:TP=-1.5:LRA=11",
            "-ar",
            str(SAMPLE_RATE),
            "-codec:a",
            "libmp3lame",
            "-b:a",
            "192k",
            str(prepared_audio),
        ]
    )
    prepared_duration = duration_seconds(prepared_audio)

    if args.cues:
        cues_path = Path(args.cues).expanduser().resolve()
        cues = json.loads(cues_path.read_text(encoding="utf-8"))
        if isinstance(cues, dict):
            cues = cues.get("cues", [])
    else:
        paragraphs = read_paragraphs(script_path)
        pauses = silence_intervals(
            prepared_audio,
            noise_db=args.pause_noise_db,
            min_duration=args.min_pause,
        )
        cues = align_cues(paragraphs, prepared_duration, [item["mid"] for item in pauses])
    if not isinstance(cues, list) or not cues:
        raise PipelineError("Caption cues are empty or invalid.")

    cues_output = output_dir / "cues.json"
    cues_output.write_text(json.dumps(cues, ensure_ascii=False, indent=2), encoding="utf-8")
    srt_path = output_dir / "captions.srt"
    ass_path = output_dir / "captions.ass"
    write_srt(cues, srt_path)
    write_ass(cues, ass_path)
    base_path, thumbnail_path = create_visuals(args.title, args.tagline, output_dir)

    video_path = output_dir / args.output_name
    ass_filter_path = escape_filter_path(ass_path)
    filter_graph = (
        "[1:a]asplit=2[aout][aw];"
        "[aw]showwaves=s=1580x190:mode=cline:scale=sqrt:colors=0xFF1687:r=30,"
        "format=rgba,colorkey=0x000000:0.08:0.0[wave];"
        "[0:v]format=rgba[base];"
        "[base][wave]overlay=x=170:y=475:shortest=1[vwave];"
        f"[vwave]ass=filename='{ass_filter_path}'[vout]"
    )
    run(
        [
            executable("ffmpeg"),
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-loop",
            "1",
            "-framerate",
            "30",
            "-i",
            str(base_path),
            "-i",
            str(prepared_audio),
            "-filter_complex",
            filter_graph,
            "-map",
            "[vout]",
            "-map",
            "[aout]",
            "-t",
            f"{prepared_duration:.3f}",
            "-c:v",
            "libx264",
            "-preset",
            args.preset,
            "-crf",
            str(args.crf),
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            "-movflags",
            "+faststart",
            str(video_path),
        ],
        timeout=args.render_timeout,
    )
    contact_sheet = output_dir / "contact_sheet.jpg"
    verification = verify_video(video_path, contact_sheet)
    manifest = {
        "status": "READY",
        "input_audio": str(audio_path),
        "trim_start": round(trim_start, 3),
        "trim_end": round(trim_end, 3),
        "outer_silence_count": len(outer_silences),
        "prepared_audio": str(prepared_audio),
        "cues": str(cues_output),
        "srt": str(srt_path),
        "ass": str(ass_path),
        "video": str(video_path),
        "thumbnail": str(thumbnail_path),
        "contact_sheet": str(contact_sheet),
        "audio_levels": volume_stats(video_path),
        "verification": verification,
    }
    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    emit(manifest)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    check_parser = sub.add_parser("check", help="Verify dependencies")
    check_parser.set_defaults(func=cmd_check)

    reference = sub.add_parser("reference", help="Fetch metadata and captions")
    reference.add_argument("--url", required=True)
    reference.add_argument("--language", default="en")
    reference.add_argument("--output-dir", required=True)
    reference.add_argument("--allow-auto", action="store_true")
    reference.set_defaults(func=cmd_reference)

    devices = sub.add_parser("devices", help="List DirectShow audio devices")
    devices.set_defaults(func=cmd_devices)

    record_start = sub.add_parser("record-start", help="Start microphone recording")
    record_start.add_argument("--device", required=True)
    record_start.add_argument("--output-dir", required=True)
    record_start.add_argument("--startup-timeout", type=float, default=6.0)
    record_start.add_argument("--minimum-bytes", type=int, default=48_000)
    record_start.set_defaults(func=cmd_record_start)

    record_status = sub.add_parser("record-status", help="Inspect active recording")
    record_status.add_argument("--output-dir", required=True)
    record_status.set_defaults(func=cmd_record_status)

    record_stop = sub.add_parser("record-stop", help="Stop and convert recording")
    record_stop.add_argument("--output-dir", required=True)
    record_stop.add_argument("--minimum-bytes", type=int, default=96_000)
    record_stop.add_argument("--keep-raw", action="store_true")
    record_stop.set_defaults(func=cmd_record_stop)

    build = sub.add_parser("build", help="Build and verify narrated MP4")
    build.add_argument("--audio", required=True)
    build.add_argument("--script", required=True)
    build.add_argument("--output-dir", required=True)
    build.add_argument("--title", required=True)
    build.add_argument("--tagline", required=True)
    build.add_argument("--cues", help="Reuse and edit an existing cues JSON")
    build.add_argument("--output-name", default="video.mp4")
    build.add_argument("--no-auto-trim", action="store_true")
    build.add_argument("--outer-noise-db", type=float, default=-45.0)
    build.add_argument("--min-outer-silence", type=float, default=1.0)
    build.add_argument("--trim-pad", type=float, default=0.25)
    build.add_argument("--pause-noise-db", type=float, default=-40.0)
    build.add_argument("--min-pause", type=float, default=0.35)
    build.add_argument("--crf", type=int, default=19)
    build.add_argument("--preset", default="fast")
    build.add_argument("--render-timeout", type=float, default=900.0)
    build.set_defaults(func=cmd_build)
    return parser


def main() -> None:
    args = build_parser().parse_args()
    try:
        args.func(args)
    except PipelineError as exc:
        emit({"status": "ERROR", "error": str(exc)})
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
