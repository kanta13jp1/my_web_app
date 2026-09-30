#!/usr/bin/env python3
"""Fetch, normalize, and diff Hedra's official model catalog.

The watcher performs one authenticated request per run.  It keeps a stable
snapshot in the repository, emits machine-readable and Markdown reports, and
publishes small GitHub Actions outputs for the notification step.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


CATALOG_URL = "https://api.hedra.com/web-app/public/models"
DOCS_URL = "https://www.hedra.com/docs/api-reference/public/list-models"
MAX_RESPONSE_BYTES = 5 * 1024 * 1024
SCHEMA_VERSION = 1
SET_LIKE_FIELDS = frozenset({"aspect_ratios", "durations", "resolutions"})
UTC = dt.timezone.utc


class WatchError(RuntimeError):
    """A safe, user-facing watcher failure."""


def now_iso() -> str:
    return (
        dt.datetime.now(UTC)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def canonicalize(value: Any, *, field: str = "") -> Any:
    """Return JSON-compatible data with stable object and set-like ordering."""
    if isinstance(value, dict):
        return {
            str(key): canonicalize(item, field=str(key))
            for key, item in sorted(value.items(), key=lambda pair: str(pair[0]))
        }
    if isinstance(value, list):
        items = [canonicalize(item) for item in value]
        if field in SET_LIKE_FIELDS:
            return sorted(
                items,
                key=lambda item: json.dumps(
                    item,
                    ensure_ascii=False,
                    sort_keys=True,
                    separators=(",", ":"),
                ),
            )
        return items
    if value is None or isinstance(value, (bool, int, float, str)):
        return value
    raise WatchError(f"unsupported catalog value type: {type(value).__name__}")


def normalize_catalog(payload: Any) -> list[dict[str, Any]]:
    if not isinstance(payload, list):
        raise WatchError("Hedra model response must be a JSON array")
    if not payload:
        raise WatchError("Hedra model response must not be empty")

    models: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    for index, raw_model in enumerate(payload):
        if not isinstance(raw_model, dict):
            raise WatchError(f"model at index {index} must be a JSON object")
        model_id = raw_model.get("id")
        if not isinstance(model_id, str) or not model_id.strip():
            raise WatchError(f"model at index {index} has no non-empty id")
        if model_id in seen_ids:
            raise WatchError(f"duplicate Hedra model id: {model_id}")
        seen_ids.add(model_id)
        normalized = canonicalize(raw_model)
        assert isinstance(normalized, dict)
        models.append(normalized)

    return sorted(models, key=lambda model: str(model["id"]))


def stable_digest(models: list[dict[str, Any]]) -> str:
    encoded = json.dumps(
        models,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def load_snapshot(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    try:
        snapshot = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise WatchError(f"cannot read prior snapshot: {exc}") from exc
    if not isinstance(snapshot, dict) or not isinstance(snapshot.get("models"), list):
        raise WatchError("prior snapshot has an invalid schema")
    return snapshot


def compact_text(value: Any, *, limit: int = 160) -> str:
    text = re.sub(r"\s+", " ", str(value)).strip()
    text = text.replace("`", "'").replace("@", "＠")
    return text[:limit]


def model_summary(model: dict[str, Any]) -> dict[str, str]:
    return {
        "id": compact_text(model.get("id", "")),
        "name": compact_text(model.get("name", "")),
        "type": compact_text(model.get("type", "")),
    }


def diff_catalogs(
    previous: list[dict[str, Any]],
    current: list[dict[str, Any]],
) -> dict[str, list[dict[str, Any]]]:
    old_by_id = {str(model["id"]): model for model in previous}
    new_by_id = {str(model["id"]): model for model in current}
    old_ids = set(old_by_id)
    new_ids = set(new_by_id)

    added = [model_summary(new_by_id[model_id]) for model_id in sorted(new_ids - old_ids)]
    removed = [
        model_summary(old_by_id[model_id]) for model_id in sorted(old_ids - new_ids)
    ]
    changed: list[dict[str, Any]] = []
    for model_id in sorted(old_ids & new_ids):
        old_model = old_by_id[model_id]
        new_model = new_by_id[model_id]
        if old_model == new_model:
            continue
        changed_fields = sorted(
            key
            for key in set(old_model) | set(new_model)
            if old_model.get(key) != new_model.get(key)
        )
        changed.append(
            {
                **model_summary(new_model),
                "changed_fields": changed_fields,
            }
        )
    return {"added": added, "removed": removed, "changed": changed}


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def process_catalog(
    payload: Any,
    *,
    snapshot_path: Path,
    checked_at: str,
) -> dict[str, Any]:
    current_models = normalize_catalog(payload)
    current_digest = stable_digest(current_models)
    previous_snapshot = load_snapshot(snapshot_path)

    if previous_snapshot is None:
        previous_models: list[dict[str, Any]] = []
        previous_digest = ""
        differences = {"added": [], "removed": [], "changed": []}
        status = "baseline_created"
        changed = False
    else:
        previous_models = normalize_catalog(previous_snapshot["models"])
        previous_digest = stable_digest(previous_models)
        differences = diff_catalogs(previous_models, current_models)
        changed = any(differences.values())
        status = "changed" if changed else "unchanged"

    if previous_snapshot is None or changed:
        write_json(
            snapshot_path,
            {
                "schema_version": SCHEMA_VERSION,
                "source": CATALOG_URL,
                "checked_at": checked_at,
                "digest": current_digest,
                "model_count": len(current_models),
                "models": current_models,
            },
        )

    event_seed = f"{checked_at[:10]}:{previous_digest}:{current_digest}"
    event_key = hashlib.sha256(event_seed.encode("utf-8")).hexdigest()[:20]
    return {
        "schema_version": SCHEMA_VERSION,
        "checked_at": checked_at,
        "source": CATALOG_URL,
        "documentation": DOCS_URL,
        "status": status,
        "changed": changed,
        "event_key": event_key,
        "previous_digest": previous_digest,
        "digest": current_digest,
        "previous_model_count": len(previous_models),
        "model_count": len(current_models),
        "differences": differences,
    }


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Hedra Model Catalog Watch",
        "",
        f"- Checked at: `{report.get('checked_at', 'unknown')}`",
        f"- Status: `{report.get('status', 'error')}`",
        f"- Models: `{report.get('model_count', 0)}`",
        f"- API: {CATALOG_URL}",
        f"- Official documentation: {DOCS_URL}",
        "",
    ]
    if report.get("status") == "error":
        lines.extend(["## Error", "", str(report.get("error", "unknown error")), ""])
        return "\n".join(lines)

    if report.get("status") == "baseline_created":
        lines.extend(
            [
                "The first successful run created the comparison baseline.",
                "No change notification is emitted for baseline creation.",
                "",
            ]
        )
        return "\n".join(lines)

    differences = report.get("differences") or {}
    lines.extend(
        [
            "## Changes",
            "",
            f"- Added: `{len(differences.get('added', []))}`",
            f"- Removed: `{len(differences.get('removed', []))}`",
            f"- Changed: `{len(differences.get('changed', []))}`",
            "",
        ]
    )
    for heading, key in (
        ("Added models", "added"),
        ("Removed models", "removed"),
        ("Changed models", "changed"),
    ):
        items = differences.get(key, [])
        if not items:
            continue
        lines.extend([f"### {heading}", ""])
        for item in items:
            detail = ""
            if item.get("changed_fields"):
                detail = f"; fields: {', '.join(item['changed_fields'])}"
            lines.append(
                f"- `{item.get('id', '')}` {item.get('name', '')} "
                f"(`{item.get('type', '')}`){detail}"
            )
        lines.append("")
    lines.extend(
        [
            (
                "The normalized snapshot and JSON report are retained as workflow "
                "artifacts and repository inputs for later catalog validation."
            ),
            "",
        ]
    )
    return "\n".join(lines)


def fetch_catalog(api_key: str, timeout: int) -> Any:
    request = urllib.request.Request(
        CATALOG_URL,
        headers={
            "Accept": "application/json",
            "User-Agent": (
                "my_web_app-hedra-model-watch/1.0 "
                "(+https://github.com/kanta13jp1/my_web_app)"
            ),
            "X-API-Key": api_key,
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read(MAX_RESPONSE_BYTES + 1)
            if len(raw) > MAX_RESPONSE_BYTES:
                raise WatchError("Hedra model response exceeded 5 MiB")
    except urllib.error.HTTPError as exc:
        raise WatchError(f"Hedra model request returned HTTP {exc.code}") from exc
    except urllib.error.URLError as exc:
        raise WatchError(f"Hedra model request failed: {exc.reason}") from exc
    except TimeoutError as exc:
        raise WatchError("Hedra model request timed out") from exc

    try:
        return json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise WatchError("Hedra model response was not valid UTF-8 JSON") from exc


def write_outputs(report: dict[str, Any]) -> None:
    output_path = os.environ.get("GITHUB_OUTPUT")
    if not output_path:
        return
    differences = report.get("differences") or {}
    values = {
        "status": report.get("status", "error"),
        "changed": str(bool(report.get("changed"))).lower(),
        "event_key": report.get("event_key", ""),
        "digest": report.get("digest", ""),
        "model_count": report.get("model_count", 0),
        "added_count": len(differences.get("added", [])),
        "removed_count": len(differences.get("removed", [])),
        "modified_count": len(differences.get("changed", [])),
    }
    with Path(output_path).open("a", encoding="utf-8") as output:
        for key, value in values.items():
            output.write(f"{key}={value}\n")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--snapshot",
        default="docs/hedra-model-watch/models.json",
    )
    parser.add_argument(
        "--report",
        default="docs/hedra-model-watch/latest-report.md",
    )
    parser.add_argument(
        "--json-report",
        default="docs/hedra-model-watch/latest-report.json",
    )
    parser.add_argument("--fixture", help="Read a local catalog fixture instead of HTTP")
    parser.add_argument("--checked-at", default=None)
    parser.add_argument("--timeout", type=int, default=20)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    checked_at = args.checked_at or now_iso()
    snapshot_path = Path(args.snapshot)
    report_path = Path(args.report)
    json_report_path = Path(args.json_report)

    try:
        if args.fixture:
            payload = json.loads(Path(args.fixture).read_text(encoding="utf-8"))
        else:
            api_key = os.environ.get("HEDRA_API_KEY", "").strip()
            if not api_key:
                raise WatchError("HEDRA_API_KEY is not configured")
            payload = fetch_catalog(api_key, args.timeout)
        report = process_catalog(
            payload,
            snapshot_path=snapshot_path,
            checked_at=checked_at,
        )
        exit_code = 0
    except (OSError, json.JSONDecodeError, WatchError) as exc:
        report = {
            "schema_version": SCHEMA_VERSION,
            "checked_at": checked_at,
            "source": CATALOG_URL,
            "documentation": DOCS_URL,
            "status": "error",
            "changed": False,
            "event_key": "",
            "digest": "",
            "model_count": 0,
            "differences": {"added": [], "removed": [], "changed": []},
            "error": str(exc),
        }
        exit_code = 1

    write_json(json_report_path, report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(render_markdown(report), encoding="utf-8")
    write_outputs(report)
    print(render_markdown(report))
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
