#!/usr/bin/env python3
"""AI system prompt history knowledge intake and diff/issue-payload tool."""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
import hashlib
import json
from typing import Any

PROMPT_CHANGE_LABELS: dict[str, str] = {
    "breaking": "Breaking Prompt Contract Change",
    "additive": "Additive Prompt Capability",
    "metadata": "Metadata or Whitespace Only",
}


@dataclass(frozen=True)
class NormalizedPromptSnapshot:
    provider: str
    model_name: str
    version_tag: str
    captured_at_iso: str
    sections: dict[str, str]
    content_digest: str
    verification_status: str


@dataclass(frozen=True)
class PromptHistoryDiffResult:
    severity: str
    changed: bool
    added_sections: list[str]
    removed_sections: list[str]
    modified_sections: list[str]


@dataclass(frozen=True)
class DryRunInvestigationIssuePayload:
    title: str
    labels: list[str]
    body: str
    dry_run: bool = True


def _normalize_iso(iso_text: str) -> str:
    cleaned = iso_text.strip()
    if cleaned.endswith("Z"):
        cleaned = cleaned[:-1] + "+00:00"
    dt = datetime.fromisoformat(cleaned)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def normalize_prompt_snapshot(raw_snapshot: dict[str, Any]) -> NormalizedPromptSnapshot:
    provider = str(raw_snapshot["provider"]).strip().lower()
    model_name = str(raw_snapshot["model_name"]).strip()
    version_tag = str(raw_snapshot["version_tag"]).strip()
    captured_at_iso = _normalize_iso(str(raw_snapshot["captured_at_iso"]))

    raw_sections = raw_snapshot.get("sections", {})
    sections = {
        str(k).strip(): str(v).replace("\r\n", "\n").strip()
        for k, v in sorted(raw_sections.items(), key=lambda item: str(item[0]))
        if str(k).strip()
    }
    digest_payload = json.dumps(
        {
            "provider": provider,
            "model_name": model_name,
            "version_tag": version_tag,
            "sections": sections,
        },
        ensure_ascii=False,
        sort_keys=True,
    )
    content_digest = hashlib.sha256(digest_payload.encode("utf-8")).hexdigest()[:16]
    verification_status = (
        str(raw_snapshot.get("verification_status", "")).strip() or "未確認"
    )
    return NormalizedPromptSnapshot(
        provider=provider,
        model_name=model_name,
        version_tag=version_tag,
        captured_at_iso=captured_at_iso,
        sections=sections,
        content_digest=content_digest,
        verification_status=verification_status,
    )


def diff_prompt_snapshots(
    previous_snapshot: NormalizedPromptSnapshot,
    current_snapshot: NormalizedPromptSnapshot,
) -> PromptHistoryDiffResult:
    prev_keys = set(previous_snapshot.sections.keys())
    curr_keys = set(current_snapshot.sections.keys())

    added = sorted(curr_keys - prev_keys)
    removed = sorted(prev_keys - curr_keys)
    modified = sorted(
        key
        for key in (prev_keys & curr_keys)
        if previous_snapshot.sections[key] != current_snapshot.sections[key]
    )

    if removed or modified:
        severity = "breaking"
    elif added:
        severity = "additive"
    else:
        severity = "metadata"

    return PromptHistoryDiffResult(
        severity=severity,
        changed=bool(added or removed or modified),
        added_sections=added,
        removed_sections=removed,
        modified_sections=modified,
    )


def build_investigation_issue_payload(
    diff: PromptHistoryDiffResult,
    current_snapshot: NormalizedPromptSnapshot,
) -> DryRunInvestigationIssuePayload | None:
    if not diff.changed:
        return None
    lines = [
        "## AI System Prompt Release Investigation (Dry-Run)",
        "",
        f"- Provider / Model: {current_snapshot.provider} / {current_snapshot.model_name}",
        f"- Version: {current_snapshot.version_tag}",
        f"- Severity: {diff.severity} ({PROMPT_CHANGE_LABELS[diff.severity]})",
        f"- Verification Status: {current_snapshot.verification_status}",
        "- Added sections: " + (", ".join(diff.added_sections) or "none"),
        "- Removed sections: " + (", ".join(diff.removed_sections) or "none"),
        "- Modified sections: " + (", ".join(diff.modified_sections) or "none"),
    ]
    return DryRunInvestigationIssuePayload(
        title=(
            f"[prompt-intake] {current_snapshot.provider} "
            f"{current_snapshot.model_name} {current_snapshot.version_tag} 仕様差異調査"
        ),
        labels=["automation", "notebooklm"],
        body="\n".join(lines),
        dry_run=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Normalize and diff AI system prompt history snapshots."
    )
    parser.add_argument(
        "--sample-dry-run",
        action="store_true",
        help="Run built-in snapshot diff and dry-run issue payload generation.",
    )
    parser.add_argument("--json", action="store_true", help="Emit JSON output.")
    args = parser.parse_args()

    if args.sample_dry_run:
        prev = normalize_prompt_snapshot(
            {
                "provider": "anthropic",
                "model_name": "claude-sonnet",
                "version_tag": "2026-10-01",
                "captured_at_iso": "2026-10-01T00:00:00Z",
                "sections": {"identity": "Be concise."},
            }
        )
        curr = normalize_prompt_snapshot(
            {
                "provider": "anthropic",
                "model_name": "claude-sonnet",
                "version_tag": "2026-11-01",
                "captured_at_iso": "2026-11-01T00:00:00Z",
                "sections": {"identity": "Be concise.", "tools": "Use schema."},
            }
        )
        diff = diff_prompt_snapshots(prev, curr)
        payload = build_investigation_issue_payload(diff, curr)
        out = {
            "ok": True,
            "diff": asdict(diff),
            "issue_payload": asdict(payload) if payload else None,
        }
        if args.json:
            print(json.dumps(out, ensure_ascii=False, indent=2))
        else:
            print(f"ok=True severity={diff.severity}")
        return 0

    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
