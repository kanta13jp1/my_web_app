#!/usr/bin/env python3
"""Safe multibyte UTF-8 text replacement fallback CLI (#1387).

Designed as a fail-closed, deterministic fallback when multibyte UTF-8 text
(such as Japanese prose or emoji in large Markdown/code files) fails patch
context matching. Prefer running with ``PYTHONUTF8=1``.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile


@dataclass(frozen=True)
class ReplaceResult:
    file: str
    match_count: int
    replaced_count: int
    changed: bool
    dry_run: bool
    backup_path: str | None
    utf8_env_active: bool


def is_utf8_runtime_active() -> bool:
    """Return True when PYTHONUTF8=1 or Python UTF-8 mode is active."""
    return os.environ.get("PYTHONUTF8") == "1" or bool(getattr(sys.flags, "utf8_mode", 0))


def _resolve_text_arg(
    inline_value: str | None,
    file_path: str | None,
    *,
    label: str,
) -> str:
    if inline_value is not None and file_path is not None:
        raise ValueError(f"Specify either --{label} or --{label}-file, not both.")
    if file_path is not None:
        src = Path(file_path)
        if not src.is_file():
            raise FileNotFoundError(f"--{label}-file not found: {src}")
        return src.read_text(encoding="utf-8")
    if inline_value is not None:
        return inline_value
    raise ValueError(f"Either --{label} or --{label}-file is required.")


def apply_utf8_replace(
    target_path: Path,
    find_text: str,
    replace_text: str,
    *,
    use_regex: bool = False,
    max_count: int = 0,
    expected_count: int | None = None,
    create_backup: bool = False,
    dry_run: bool = False,
    require_utf8_env: bool = False,
) -> ReplaceResult:
    """Safely replace UTF-8 text in ``target_path`` with strict validation."""
    utf8_active = is_utf8_runtime_active()
    if require_utf8_env and not utf8_active:
        raise RuntimeError(
            "PYTHONUTF8=1 or Python UTF-8 mode (-X utf8) is required when --require-utf8-env is set."
        )
    if not find_text:
        raise ValueError("Search pattern must not be empty.")
    if max_count < 0:
        raise ValueError("--count must be >= 0.")
    if expected_count is not None and expected_count < 1:
        raise ValueError("--expected-count must be >= 1.")
    if not target_path.is_file():
        raise FileNotFoundError(f"Target file not found: {target_path}")

    raw_bytes = target_path.read_bytes()
    try:
        original = raw_bytes.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ValueError(f"Target file is not valid UTF-8: {target_path} ({exc})") from exc

    if use_regex:
        pattern = re.compile(find_text, flags=re.MULTILINE)
        match_count = sum(1 for _ in pattern.finditer(original))
        sub_count = max_count if max_count > 0 else 0
        updated, replaced_count = pattern.subn(
            lambda _m: replace_text,
            original,
            count=sub_count,
        )
    else:
        match_count = original.count(find_text)
        if max_count > 0:
            updated = original.replace(find_text, replace_text, max_count)
            replaced_count = min(match_count, max_count)
        else:
            updated = original.replace(find_text, replace_text)
            replaced_count = match_count

    if match_count == 0:
        raise LookupError(f"Pattern not found in {target_path}")
    if expected_count is not None and match_count != expected_count:
        raise ValueError(
            f"Expected {expected_count} match(es) in {target_path}, found {match_count}."
        )

    changed = updated != original
    backup_str: str | None = None

    if not dry_run and changed:
        if create_backup:
            backup_path = target_path.with_name(f"{target_path.name}.bak")
            shutil.copy2(target_path, backup_path)
            backup_str = str(backup_path)

        parent = target_path.parent
        tmp_path: Path | None = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="wb",
                dir=parent,
                prefix=f".{target_path.name}.",
                suffix=".tmp",
                delete=False,
            ) as tmp:
                tmp_path = Path(tmp.name)
                tmp.write(updated.encode("utf-8"))
            os.replace(tmp_path, target_path)
            tmp_path = None
        finally:
            if tmp_path is not None and tmp_path.exists():
                tmp_path.unlink(missing_ok=True)

    return ReplaceResult(
        file=str(target_path),
        match_count=match_count,
        replaced_count=replaced_count,
        changed=changed,
        dry_run=dry_run,
        backup_path=backup_str,
        utf8_env_active=utf8_active,
    )


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", required=True, help="Target UTF-8 file path")
    parser.add_argument("--find", default=None, help="Literal or regex text to search")
    parser.add_argument("--find-file", default=None, help="Read search text from UTF-8 file")
    parser.add_argument("--replace", default=None, help="Replacement text")
    parser.add_argument("--replace-file", default=None, help="Read replacement text from UTF-8 file")
    parser.add_argument("--regex", action="store_true", help="Treat --find as a Python regex")
    parser.add_argument("--count", type=int, default=0, help="Max replacements (0 = replace all)")
    parser.add_argument(
        "--expected-count",
        type=int,
        default=None,
        help="Fail closed unless total match count equals this number",
    )
    parser.add_argument("--backup", action="store_true", help="Write <file>.bak before updating")
    parser.add_argument("--dry-run", action="store_true", help="Inspect matches without writing")
    parser.add_argument(
        "--require-utf8-env",
        action="store_true",
        help="Fail unless PYTHONUTF8=1 or Python UTF-8 mode is enabled",
    )
    parser.add_argument("--json", action="store_true", help="Emit JSON summary on stdout")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        find_text = _resolve_text_arg(args.find, args.find_file, label="find")
        replace_text = _resolve_text_arg(args.replace, args.replace_file, label="replace")
        result = apply_utf8_replace(
            Path(args.file),
            find_text,
            replace_text,
            use_regex=args.regex,
            max_count=args.count,
            expected_count=args.expected_count,
            create_backup=args.backup,
            dry_run=args.dry_run,
            require_utf8_env=args.require_utf8_env,
        )
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(asdict(result), ensure_ascii=False))
    else:
        mode = "DRY-RUN" if result.dry_run else "UPDATED"
        print(
            f"[{mode}] {result.file}: matched={result.match_count} "
            f"replaced={result.replaced_count} changed={result.changed}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
