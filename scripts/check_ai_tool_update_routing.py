#!/usr/bin/env python3
"""Check #1787/#2535 AI-tool routing docs for owner and subagent policy."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_MARKERS: dict[str, tuple[str, ...]] = {
    "docs/AI_FALLBACK_RUNBOOK.md": (
        "#1787 2026-05 AI Tool Routing Update",
        "Claude Code #1 reviews adoption risk",
        "Codex #1 owns scoped implementation",
        "Codex #2 and Codex #3 stay historical",
        "docs/ai-tool-changelog/2026-05.md",
        ".github/agents/README.md",
    ),
    "docs/DEV_PROCESS_MULTI_AI.md": (
        "#2535 Guarded Subagent Routing Update",
        "Live top-level owners: Claude Code #1 and Codex #1 only.",
        "Codex #1 absorbs the old Codex #2 implementation lane",
        "Do not start old Codex",
        "subagents are allowed under Claude Code #1 or Codex #1",
        "docs/SUBAGENT_ORCHESTRATION_POLICY.md",
    ),
    ".github/agents/README.md": (
        "# Copilot Custom Agents Design",
        "advisory only",
        "Claude Code #1 owns adoption decisions",
        "Codex #1 owns scoped implementation PRs",
        "must not merge, deploy, write production data",
    ),
    "docs/SUBAGENT_ORCHESTRATION_POLICY.md": (
        "Guarded Subagent Orchestration Policy",
        "Claude Code #1 and Codex #1 remain the only",
        "Subagents are child workers owned by one of",
        "Do not use subagents when",
        "Subagent evidence:",
    ),
}


def missing_markers(root: Path = ROOT) -> list[str]:
    missing: list[str] = []
    for relative_path, markers in REQUIRED_MARKERS.items():
        path = root / relative_path
        if not path.exists():
            missing.append(f"{relative_path}: missing file")
            continue
        text = path.read_text(encoding="utf-8")
        for marker in markers:
            if marker not in text:
                missing.append(f"{relative_path}: missing marker {marker!r}")
    return missing


def main() -> int:
    missing = missing_markers()
    if missing:
        for item in missing:
            print(item)
        return 1
    print("#1787/#2535 AI-tool routing docs: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
