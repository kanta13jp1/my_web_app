#!/usr/bin/env python3
"""Dry-run validator for AppStream Image Assistant pipeline manifests (#2798)."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Sequence

_SHA256_RE = re.compile(r"^[0-9a-fA-F]{64}$")
_URI_RE = re.compile(r"^(?:s3|https)://[^\s]+$")


@dataclass(frozen=True)
class RolloutStagePlan:
    fleet_name: str
    stage: str
    order: int


@dataclass(frozen=True)
class PipelineManifestCheckResult:
    ok: bool
    app_version: str
    errors: tuple[str, ...]
    rollout_plan: tuple[RolloutStagePlan, ...]
    admin_notification: dict[str, Any] | None


def build_admin_notification_payload(
    *,
    app_version: str,
    installer_uri: str,
    rollout_plan: Sequence[RolloutStagePlan],
    notify_channel: str,
    dry_run: bool = True,
) -> dict[str, Any]:
    """Build a structured admin notification payload without live AWS calls."""
    return {
        "event": "image_pipeline_dry_run" if dry_run else "image_pipeline_completed",
        "appVersion": app_version,
        "installerUri": installer_uri,
        "notifyChannel": notify_channel,
        "fleets": [asdict(item) for item in rollout_plan],
    }


def validate_image_pipeline_manifest(
    manifest: dict[str, Any],
) -> PipelineManifestCheckResult:
    """Validate an image pipeline dry-run manifest and build rollout stages."""
    errors: list[str] = []
    app_version = str(manifest.get("appVersion", "")).strip()
    installer_uri = str(manifest.get("installerUri", "")).strip()
    sha256 = str(manifest.get("sha256", "")).strip()
    notify_channel = str(manifest.get("notifyChannel", "")).strip()
    raw_fleets = manifest.get("targetFleets")

    if not app_version:
        errors.append("appVersion must be non-empty")
    if not _URI_RE.match(installer_uri):
        errors.append("installerUri must start with s3:// or https://")
    if not _SHA256_RE.match(sha256):
        errors.append("sha256 must be a valid 64-character hex digest")
    if not notify_channel:
        errors.append("notifyChannel must be non-empty")

    rollout_plan: list[RolloutStagePlan] = []
    if not isinstance(raw_fleets, list) or len(raw_fleets) == 0:
        errors.append("targetFleets must be a non-empty list")
    else:
        for idx, item in enumerate(raw_fleets, start=1):
            if not isinstance(item, dict):
                errors.append(f"targetFleets[{idx - 1}] must be an object")
                continue
            name = str(item.get("name", "")).strip()
            stage = str(item.get("rolloutStage", "")).strip() or "staging"
            if not name:
                errors.append(f"targetFleets[{idx - 1}].name must be non-empty")
                continue
            rollout_plan.append(
                RolloutStagePlan(fleet_name=name, stage=stage, order=idx)
            )

    if errors:
        return PipelineManifestCheckResult(
            ok=False,
            app_version=app_version,
            errors=tuple(errors),
            rollout_plan=(),
            admin_notification=None,
        )

    notification = build_admin_notification_payload(
        app_version=app_version,
        installer_uri=installer_uri,
        rollout_plan=rollout_plan,
        notify_channel=notify_channel,
        dry_run=True,
    )
    return PipelineManifestCheckResult(
        ok=True,
        app_version=app_version,
        errors=(),
        rollout_plan=tuple(rollout_plan),
        admin_notification=notification,
    )


def sample_dry_run_manifest() -> dict[str, Any]:
    return {
        "appVersion": "1.0.2550",
        "installerUri": "s3://example-appstream-builds/my_web_app-1.0.2550.msi",
        "sha256": "a" * 64,
        "notifyChannel": "ops-release-alerts",
        "targetFleets": [
            {"name": "canary-fleet", "rolloutStage": "canary"},
            {"name": "prod-fleet-jp", "rolloutStage": "production"},
        ],
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate AppStream Image Assistant dry-run manifest.",
    )
    parser.add_argument("--manifest", default="")
    parser.add_argument("--sample-dry-run", action="store_true")
    parser.add_argument("--fail-on-error", action="store_true")
    args = parser.parse_args(argv)

    if args.manifest:
        payload = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    else:
        payload = sample_dry_run_manifest()

    res = validate_image_pipeline_manifest(payload)
    print(json.dumps(asdict(res), ensure_ascii=False, indent=2))
    if args.fail_on_error and not res.ok:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
