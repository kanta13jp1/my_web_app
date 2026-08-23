"""Launch pinned Wan2.2 without placing a customer prompt in the OS command line."""

from __future__ import annotations

import os
import runpy
import sys
from pathlib import Path


def main() -> None:
    source_dir = Path(os.environ["WAN_SOURCE_DIR"]).resolve()
    prompt_file = Path(os.environ["VIDEO_PROMPT_FILE"]).resolve()
    prompt = prompt_file.read_text(encoding="utf-8").strip()
    if not prompt or len(prompt) > 1000:
        raise ValueError("invalid_prompt_file")
    sys.path.insert(0, str(source_dir))
    sys.argv.extend(["--prompt", prompt])
    runpy.run_path(str(source_dir / "generate.py"), run_name="__main__")


if __name__ == "__main__":
    main()
