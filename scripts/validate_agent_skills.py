#!/usr/bin/env python3
"""Validate canonical A/B agent skills without executing arbitrary shell text."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import unquote, urlsplit

import yaml


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = REPO_ROOT / ".agents" / "skills" / "ci-manifest.json"
SKILL_NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
MARKDOWN_LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
ALLOWED_FRONTMATTER_KEYS = {"name", "description"}
ALLOWED_EXTERNAL_SMOKES = {
    ("git", "--version"),
    ("notebooklm", "ask", "--help"),
}


@dataclass
class ValidationReport:
    skills: int = 0
    grade_counts: dict[str, int] = field(default_factory=lambda: {"A": 0, "B": 0})
    ui_metadata_checked: int = 0
    links_checked: int = 0
    smokes_run: int = 0
    smokes_skipped: int = 0
    errors: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.errors


def _unquote_yaml_scalar(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] == '"':
        try:
            decoded = json.loads(value)
        except json.JSONDecodeError:
            return value
        return decoded if isinstance(decoded, str) else value
    if len(value) >= 2 and value[0] == value[-1] == "'":
        return value[1:-1].replace("''", "'")
    return value


def parse_frontmatter(skill_file: Path) -> tuple[dict[str, str], str]:
    text = skill_file.read_text(encoding="utf-8-sig")
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        raise ValueError("frontmatter must start on line 1 with ---")

    try:
        closing_index = next(
            index for index, line in enumerate(lines[1:], start=1) if line.strip() == "---"
        )
    except StopIteration as exc:
        raise ValueError("frontmatter closing --- is missing") from exc

    metadata: dict[str, str] = {}
    block_key: str | None = None
    block_lines: list[str] = []

    def flush_block() -> None:
        nonlocal block_key, block_lines
        if block_key is not None:
            metadata[block_key] = " ".join(part.strip() for part in block_lines).strip()
        block_key = None
        block_lines = []

    for line_number, line in enumerate(lines[1:closing_index], start=2):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line[0].isspace():
            if block_key is None:
                raise ValueError(f"line {line_number}: unexpected indentation")
            block_lines.append(line)
            continue

        flush_block()
        if ":" not in line:
            raise ValueError(f"line {line_number}: expected key: value")
        key, raw_value = line.split(":", 1)
        key = key.strip()
        if key in metadata:
            raise ValueError(f"line {line_number}: duplicate key {key}")
        raw_value = raw_value.strip()
        if raw_value in {"|", ">"}:
            block_key = key
        else:
            metadata[key] = _unquote_yaml_scalar(raw_value)
    flush_block()

    body = "\n".join(lines[closing_index + 1 :]).strip()
    return metadata, body


def validate_frontmatter(skill_name: str, skill_file: Path) -> list[str]:
    try:
        metadata, body = parse_frontmatter(skill_file)
    except (OSError, UnicodeError, ValueError) as exc:
        return [f"{skill_name}: {exc}"]

    errors: list[str] = []
    extra_keys = sorted(set(metadata) - ALLOWED_FRONTMATTER_KEYS)
    missing_keys = sorted(ALLOWED_FRONTMATTER_KEYS - set(metadata))
    if extra_keys:
        errors.append(f"{skill_name}: unsupported frontmatter keys: {', '.join(extra_keys)}")
    if missing_keys:
        errors.append(f"{skill_name}: missing frontmatter keys: {', '.join(missing_keys)}")

    declared_name = metadata.get("name", "")
    if declared_name != skill_name:
        errors.append(f"{skill_name}: frontmatter name must match the directory")
    if not SKILL_NAME_RE.fullmatch(declared_name) or len(declared_name) > 64:
        errors.append(f"{skill_name}: name must be <=64 lowercase letters, digits, and hyphens")
    if not metadata.get("description", "").strip():
        errors.append(f"{skill_name}: description must not be empty")
    if not body:
        errors.append(f"{skill_name}: SKILL.md body must not be empty")
    return errors


def validate_openai_metadata(skill_name: str, metadata_file: Path) -> list[str]:
    try:
        text = metadata_file.read_text(encoding="utf-8")
    except FileNotFoundError:
        return [f"{skill_name}: missing agents/openai.yaml"]
    except UnicodeDecodeError as exc:
        return [f"{skill_name}: agents/openai.yaml must be valid UTF-8: {exc}"]
    except OSError as exc:
        return [f"{skill_name}: agents/openai.yaml could not be read: {exc}"]

    try:
        metadata = yaml.safe_load(text)
    except yaml.YAMLError as exc:
        return [f"{skill_name}: invalid agents/openai.yaml: {exc}"]
    if not isinstance(metadata, dict):
        return [f"{skill_name}: agents/openai.yaml must contain a mapping"]

    interface = metadata.get("interface")
    if not isinstance(interface, dict):
        return [f"{skill_name}: agents/openai.yaml requires an interface mapping"]

    errors: list[str] = []
    required_fields = ("display_name", "short_description", "default_prompt")
    for field_name in required_fields:
        value = interface.get(field_name)
        if not isinstance(value, str) or not value.strip():
            errors.append(
                f"{skill_name}: interface.{field_name} must be a non-empty string"
            )

    short_description = interface.get("short_description")
    if isinstance(short_description, str) and not 25 <= len(short_description) <= 64:
        errors.append(
            f"{skill_name}: interface.short_description must be 25..64 characters"
        )

    default_prompt = interface.get("default_prompt")
    if isinstance(default_prompt, str) and f"${skill_name}" not in default_prompt:
        errors.append(
            f"{skill_name}: interface.default_prompt must mention ${skill_name}"
        )

    quoted_fields: set[str] = set()
    field_pattern = re.compile(
        r'^\s{2}(display_name|short_description|default_prompt):\s*(".*")\s*$'
    )
    for line in text.splitlines():
        match = field_pattern.fullmatch(line)
        if match:
            quoted_fields.add(match.group(1))
    unquoted_fields = sorted(set(required_fields) - quoted_fields)
    if unquoted_fields:
        errors.append(
            f"{skill_name}: quote UI string fields: {', '.join(unquoted_fields)}"
        )

    policy = metadata.get("policy")
    if policy is not None:
        if not isinstance(policy, dict):
            errors.append(f"{skill_name}: policy must be a mapping")
        elif "allow_implicit_invocation" in policy and not isinstance(
            policy["allow_implicit_invocation"], bool
        ):
            errors.append(
                f"{skill_name}: policy.allow_implicit_invocation must be boolean"
            )
    return errors


def iter_markdown_targets(markdown_file: Path) -> list[str]:
    targets: list[str] = []
    in_fence = False
    fence_marker = ""
    for line in markdown_file.read_text(encoding="utf-8-sig").splitlines():
        stripped = line.lstrip()
        if stripped.startswith(("```", "~~~")):
            marker = stripped[:3]
            if not in_fence:
                in_fence = True
                fence_marker = marker
            elif marker == fence_marker:
                in_fence = False
                fence_marker = ""
            continue
        if in_fence:
            continue
        targets.extend(match.group(1).strip() for match in MARKDOWN_LINK_RE.finditer(line))
    return targets


def _link_path(target: str) -> str | None:
    if target.startswith("<") and ">" in target:
        target = target[1 : target.index(">")]
    else:
        target = target.split(maxsplit=1)[0]
    if not target or target.startswith(("#", "//")):
        return None
    parsed = urlsplit(target)
    if parsed.scheme or parsed.netloc:
        return None
    return unquote(parsed.path) or None


def validate_links(repo_root: Path, skill_dir: Path) -> tuple[int, list[str]]:
    checked = 0
    errors: list[str] = []
    root = repo_root.resolve()
    for markdown_file in sorted(skill_dir.rglob("*.md")):
        for target in iter_markdown_targets(markdown_file):
            raw_path = _link_path(target)
            if raw_path is None:
                continue
            checked += 1
            candidate = (
                root / raw_path.lstrip("/")
                if raw_path.startswith("/")
                else markdown_file.parent / raw_path
            ).resolve()
            try:
                candidate.relative_to(root)
            except ValueError:
                errors.append(f"{markdown_file.relative_to(root)}: link escapes repository: {target}")
                continue
            if not candidate.exists():
                errors.append(f"{markdown_file.relative_to(root)}: missing link target: {target}")
    return checked, errors


def _safe_smoke_command(repo_root: Path, argv: list[str]) -> tuple[list[str], str | None]:
    if not argv or not all(isinstance(part, str) and part for part in argv):
        raise ValueError("argv must be a non-empty list of strings")
    if argv[0] == "{python}":
        if len(argv) != 3 or argv[2] != "--help":
            raise ValueError("Python smoke commands must be {python} <repo-script.py> --help")
        script = (repo_root / argv[1]).resolve()
        try:
            script.relative_to(repo_root.resolve())
        except ValueError as exc:
            raise ValueError("Python smoke script escapes the repository") from exc
        if script.suffix != ".py" or not script.is_file():
            raise ValueError(f"Python smoke script does not exist: {argv[1]}")
        return [sys.executable, str(script), "--help"], None

    command_tuple = tuple(argv)
    if command_tuple not in ALLOWED_EXTERNAL_SMOKES:
        raise ValueError(f"external smoke command is not allowlisted: {' '.join(argv)}")
    executable = shutil.which(argv[0])
    return argv, None if executable else argv[0]


def run_smoke(
    repo_root: Path,
    skill_name: str,
    smoke: dict[str, object],
    report: ValidationReport,
) -> None:
    argv_value = smoke.get("argv")
    argv = argv_value if isinstance(argv_value, list) else []
    required = smoke.get("required", True)
    timeout_value = smoke.get("timeout_seconds", 20)
    if not isinstance(required, bool):
        report.errors.append(f"{skill_name}: smoke required must be boolean")
        return
    if not isinstance(timeout_value, int) or not 1 <= timeout_value <= 60:
        report.errors.append(f"{skill_name}: smoke timeout_seconds must be 1..60")
        return
    try:
        command, missing_executable = _safe_smoke_command(repo_root, argv)
    except ValueError as exc:
        report.errors.append(f"{skill_name}: {exc}")
        return
    if missing_executable:
        if required:
            report.errors.append(f"{skill_name}: missing required executable: {missing_executable}")
        else:
            report.smokes_skipped += 1
            print(f"SKIP smoke {skill_name}: {missing_executable} is not installed")
        return

    environment = os.environ.copy()
    environment["PYTHONUTF8"] = "1"
    try:
        result = subprocess.run(
            command,
            cwd=repo_root,
            env=environment,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout_value,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        report.errors.append(f"{skill_name}: smoke failed to start: {exc}")
        return
    report.smokes_run += 1
    if result.returncode != 0:
        output = (result.stdout + result.stderr).strip()[-1000:]
        report.errors.append(
            f"{skill_name}: smoke exited {result.returncode}: {' '.join(argv)}\n{output}"
        )
    else:
        print(f"PASS smoke {skill_name}: {' '.join(argv)}")


def validate_repository(repo_root: Path, manifest_path: Path) -> ValidationReport:
    report = ValidationReport()
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        report.errors.append(f"manifest: {exc}")
        return report
    if not isinstance(manifest, dict) or manifest.get("schema_version") != 1:
        report.errors.append("manifest: schema_version must be 1")
        return report
    entries = manifest.get("skills")
    if not isinstance(entries, list):
        report.errors.append("manifest: skills must be a list")
        return report

    skills_root = repo_root / ".agents" / "skills"
    actual_names = {
        path.name for path in skills_root.iterdir() if path.is_dir() and (path / "SKILL.md").is_file()
    }
    manifest_names: set[str] = set()

    for entry in entries:
        if not isinstance(entry, dict):
            report.errors.append("manifest: each skill entry must be an object")
            continue
        name = entry.get("name")
        grade = entry.get("grade")
        smokes = entry.get("cli_smoke")
        if not isinstance(name, str) or not name:
            report.errors.append("manifest: each skill requires a name")
            continue
        if name in manifest_names:
            report.errors.append(f"manifest: duplicate skill {name}")
            continue
        manifest_names.add(name)
        if grade not in {"A", "B"}:
            report.errors.append(f"{name}: grade must be A or B")
            continue
        report.grade_counts[grade] += 1
        if not isinstance(smokes, list) or not smokes:
            report.errors.append(f"{name}: cli_smoke must contain at least one command")
            continue

        skill_dir = skills_root / name
        skill_file = skill_dir / "SKILL.md"
        if not skill_file.is_file():
            report.errors.append(f"{name}: missing .agents/skills/{name}/SKILL.md")
            continue
        report.skills += 1
        report.errors.extend(validate_frontmatter(name, skill_file))
        report.ui_metadata_checked += 1
        report.errors.extend(
            validate_openai_metadata(name, skill_dir / "agents" / "openai.yaml")
        )
        checked, link_errors = validate_links(repo_root, skill_dir)
        report.links_checked += checked
        report.errors.extend(link_errors)
        for smoke in smokes:
            if not isinstance(smoke, dict):
                report.errors.append(f"{name}: each cli_smoke entry must be an object")
                continue
            run_smoke(repo_root, name, smoke, report)

    missing = sorted(actual_names - manifest_names)
    stale = sorted(manifest_names - actual_names)
    if missing:
        report.errors.append(f"manifest: active skills missing A/B classification: {', '.join(missing)}")
    if stale:
        report.errors.append(f"manifest: classified skills missing from repository: {', '.join(stale)}")
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    args = parser.parse_args(argv)
    manifest_path = args.manifest
    if not manifest_path.is_absolute():
        manifest_path = REPO_ROOT / manifest_path

    report = validate_repository(REPO_ROOT, manifest_path)
    print(
        "summary: "
        f"skills={report.skills} A={report.grade_counts['A']} B={report.grade_counts['B']} "
        f"ui={report.ui_metadata_checked} links={report.links_checked} "
        f"smoke_run={report.smokes_run} "
        f"smoke_skipped={report.smokes_skipped} errors={len(report.errors)}"
    )
    for error in report.errors:
        print(f"ERROR: {error}", file=sys.stderr)
    return 0 if report.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
