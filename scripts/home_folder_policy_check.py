#!/usr/bin/env python3
"""Policy & sync-manifest validator for home-folder persistence (#2799)."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Sequence

ALLOWED_BACKENDS = ("s3", "supabase_storage")


@dataclass(frozen=True)
class HomeFolderPolicyResult:
    ok: bool
    storage_backend: str
    errors: tuple[str, ...]
    validated_sync_paths: tuple[str, ...]


def validate_home_folder_policy(config: dict[str, Any]) -> HomeFolderPolicyResult:
    """Validate home-folder persistence, encryption, and transfer policies."""
    errors: list[str] = []
    enabled = bool(config.get("homeFolderEnabled", False))
    backend = str(config.get("storageBackend", "")).strip().lower()
    encrypted = bool(config.get("encryptionEnabled", False))
    public_blocked = bool(config.get("publicAccessBlocked", False))
    strict_mode = bool(config.get("strictSecurityMode", True))
    transfer = config.get("fileTransferPolicy")
    raw_paths = config.get("syncPaths")

    if not enabled:
        errors.append("homeFolderEnabled must be true")
    if backend not in ALLOWED_BACKENDS:
        errors.append(f"storageBackend must be one of {ALLOWED_BACKENDS}")
    if not encrypted:
        errors.append("encryptionEnabled must be true")
    if not public_blocked:
        errors.append("publicAccessBlocked must be true")

    if not isinstance(transfer, dict):
        errors.append("fileTransferPolicy must be an object")
    elif strict_mode:
        if bool(transfer.get("allowClipboardToLocal", False)):
            errors.append(
                "allowClipboardToLocal must be false in strictSecurityMode"
            )
        if bool(transfer.get("allowDownload", False)):
            errors.append("allowDownload must be false in strictSecurityMode")

    validated_paths: list[str] = []
    if not isinstance(raw_paths, list) or len(raw_paths) == 0:
        errors.append("syncPaths must be a non-empty list")
    else:
        for item in raw_paths:
            path_str = str(item).strip()
            if not path_str or ".." in path_str.replace("\\", "/").split("/"):
                errors.append(f"Unsafe or empty syncPath: {path_str!r}")
                continue
            validated_paths.append(path_str)

    return HomeFolderPolicyResult(
        ok=len(errors) == 0,
        storage_backend=backend,
        errors=tuple(errors),
        validated_sync_paths=tuple(validated_paths),
    )


def sample_home_folder_policy() -> dict[str, Any]:
    return {
        "homeFolderEnabled": True,
        "storageBackend": "supabase_storage",
        "encryptionEnabled": True,
        "publicAccessBlocked": True,
        "strictSecurityMode": True,
        "fileTransferPolicy": {
            "allowUpload": True,
            "allowDownload": False,
            "allowClipboardToLocal": False,
        },
        "syncPaths": ["user_workspace/notes", "user_workspace/exports"],
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate home-folder persistence & security policy.",
    )
    parser.add_argument("--manifest", default="")
    parser.add_argument("--sample-dry-run", action="store_true")
    parser.add_argument("--fail-on-error", action="store_true")
    args = parser.parse_args(argv)

    if args.manifest:
        payload = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    else:
        payload = sample_home_folder_policy()

    res = validate_home_folder_policy(payload)
    print(json.dumps(asdict(res), ensure_ascii=False, indent=2))
    if args.fail_on_error and not res.ok:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
