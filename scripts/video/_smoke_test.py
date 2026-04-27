"""Self-contained smoke tests for the NotebookLM video pipeline scripts.

Stands alone — no pytest, no fixtures, no extra dependencies. Run from
the repo root:

    python scripts/video/_smoke_test.py

Exit code 0 = all components pass, non-zero = first failing component.

Covered:
  - scripts/video/build_srt.py   (Scribe JSON → SRT, ASR corrections, force split)
  - scripts/embed_video_in_philosophy.py  (regex insert, dup-guard, validation)
  - scripts/video/make_cards.py  (PNG dimensions, bg color, JP wrap)

Win版#132 part 37 — closes the only remaining work item that does not
require an actual workflow_dispatch run with YouTube quota cost.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
PYTHON = sys.executable
PASS_PREFIX = "[PASS]"
FAIL_PREFIX = "[FAIL]"


def run_subprocess(args: list[str], env: dict | None = None, expect_returncode: int = 0) -> subprocess.CompletedProcess:
    full_env = os.environ.copy()
    full_env["PYTHONUTF8"] = "1"
    if env:
        full_env.update(env)
    proc = subprocess.run(args, capture_output=True, text=True, env=full_env, encoding="utf-8")
    if proc.returncode != expect_returncode:
        raise AssertionError(
            f"command {args!r} exited {proc.returncode}, expected {expect_returncode}\n"
            f"stdout: {proc.stdout}\nstderr: {proc.stderr}"
        )
    return proc


def test_build_srt() -> None:
    """build_srt.py: 4-rule cue splitter + ASR_CORRECTIONS env."""
    words = []

    def w(text: str, start: float, end: float, t: str = "word") -> None:
        words.append({"text": text, "start": start, "end": end, "type": t})

    # Scenario 1: hard punct break
    w("今日は", 0.0, 0.4)
    w("良い", 0.4, 0.6)
    w("天気", 0.6, 0.9)
    w("です", 0.9, 1.1)
    w("。", 1.1, 1.2)
    # Scenario 2: hard cap force split (single word > 28 chars)
    w("超長文がここから始まりますが句読点が一切ない場合のhard cap動作確認テスト", 5.0, 8.0)
    # Scenario 3: audio_event wrap + ASR substitution
    w(" ", 8.0, 8.5, "spacing")
    w("laughter", 8.5, 9.0, "audio_event")
    w("お笑いでした", 9.0, 9.5)
    w("。", 9.5, 9.6)

    with tempfile.TemporaryDirectory() as tmp:
        in_path = Path(tmp) / "scribe.json"
        out_path = Path(tmp) / "master.srt"
        in_path.write_text(json.dumps({"words": words}, ensure_ascii=False), encoding="utf-8")

        run_subprocess(
            [PYTHON, str(REPO_ROOT / "scripts" / "video" / "build_srt.py"), str(in_path), str(out_path)],
            env={"ASR_CORRECTIONS": json.dumps({"お笑い": "コメディ"}, ensure_ascii=False)},
        )

        srt = out_path.read_text(encoding="utf-8")

    assert "今日は良い天気です。" in srt, f"hard punct cue missing\n{srt}"
    assert "コメディ" in srt and "お笑い" not in srt, f"ASR substitution failed\n{srt}"
    assert "(laughter)" in srt, f"audio_event paren wrap missing\n{srt}"
    # Force split: 33-char word should produce two cues, neither exceeding 28 chars on the line.
    cue_lines = [line for line in srt.splitlines() if line and not line[0].isdigit() and "-->" not in line]
    for line in cue_lines:
        assert len(line) <= 28, f"cue exceeds 28-char hard cap: {line!r} (len={len(line)})"


def test_embed_video_dup_guard() -> None:
    """embed_video_in_philosophy.py: dry-run formatting + duplicate ID rejection."""
    target = REPO_ROOT / "lib" / "pages" / "philosophy_page.dart"
    assert target.exists(), f"philosophy_page.dart not found at {target}"

    embed_script = REPO_ROOT / "scripts" / "embed_video_in_philosophy.py"

    # Dry-run with valid input → exit 0
    proc = run_subprocess([
        PYTHON, str(embed_script),
        "--video-id", "AbCdEf1234",
        "--label", "Smoke test label",
        "--duration", "5:42",
        "--description", "Smoke test description",
        "--dry-run",
    ])
    assert "_Video(" in proc.stdout, f"dry-run did not emit _Video block\n{proc.stdout}"
    assert "id: 'AbCdEf1234'" in proc.stdout, f"dry-run missing video id\n{proc.stdout}"

    # Bad video-id → exit 2
    run_subprocess(
        [PYTHON, str(embed_script), "--video-id", "BAD",
         "--label", "x", "--duration", "5:42", "--description", "x", "--dry-run"],
        expect_returncode=2,
    )

    # Bad duration → exit 2
    run_subprocess(
        [PYTHON, str(embed_script), "--video-id", "AbCdEf1234",
         "--label", "x", "--duration", "BADDUR", "--description", "x", "--dry-run"],
        expect_returncode=2,
    )

    # Duplicate (existing video #1 ID) → exit 1
    run_subprocess(
        [PYTHON, str(embed_script), "--video-id", "Zclp_zK9cYM",
         "--label", "dup", "--duration", "5:42", "--description", "x", "--dry-run"],
        expect_returncode=1,
    )


def test_make_cards() -> None:
    """make_cards.py: 1280x720 PNG output, correct bg color, CARD_TITLE required."""
    try:
        from PIL import Image  # noqa: F401
    except ImportError:
        print(f"{FAIL_PREFIX} make_cards: PIL not installed (pip install pillow)", file=sys.stderr)
        raise SystemExit(2)

    make_cards = REPO_ROOT / "scripts" / "video" / "make_cards.py"

    with tempfile.TemporaryDirectory() as tmp:
        out_dir = Path(tmp) / "cards"

        # Empty CARD_TITLE → exit 1
        run_subprocess(
            [PYTHON, str(make_cards), "--output-dir", str(out_dir)],
            env={"CARD_TITLE": ""},
            expect_returncode=1,
        )

        # Valid CARD_TITLE → renders both PNGs
        run_subprocess(
            [PYTHON, str(make_cards), "--output-dir", str(out_dir)],
            env={"CARD_TITLE": "Smoke Test Title", "CARD_SERIES": "#99"},
        )

        intro = out_dir / "intro.png"
        outro = out_dir / "outro.png"
        assert intro.exists() and outro.exists(), "intro.png or outro.png not produced"

        from PIL import Image as PILImage
        for path in (intro, outro):
            img = PILImage.open(path)
            assert img.size == (1280, 720), f"{path.name} size {img.size} != (1280, 720)"
            assert img.mode == "RGB", f"{path.name} mode {img.mode} != RGB"
            assert img.getpixel((0, 0)) == (15, 17, 30), f"{path.name} bg pixel(0,0) != #0F111E"


def main() -> int:
    cases = [
        ("build_srt", test_build_srt),
        ("embed_video", test_embed_video_dup_guard),
        ("make_cards", test_make_cards),
    ]
    failed = 0
    for name, fn in cases:
        try:
            fn()
        except AssertionError as e:
            print(f"{FAIL_PREFIX} {name}: {e}", file=sys.stderr)
            failed += 1
            continue
        except Exception as e:
            print(f"{FAIL_PREFIX} {name}: {type(e).__name__}: {e}", file=sys.stderr)
            failed += 1
            continue
        print(f"{PASS_PREFIX} {name}")

    if failed:
        print(f"\n{failed}/{len(cases)} smoke tests failed.", file=sys.stderr)
        return 1
    print(f"\nAll {len(cases)} smoke tests passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
