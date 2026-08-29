#!/usr/bin/env python3
"""Validate the repository-side rootless Podman and Dev Container contract."""

from __future__ import annotations

import json
import sys
import tomllib
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
FLUTTER_IMAGE = (
    "ghcr.io/cirruslabs/flutter:3.38.10@"
    "sha256:3a94866984c440444661873d06668b0c38817923b931780e7932370618c484ed"
)
BASE_IMAGE = (
    "mcr.microsoft.com/devcontainers/base:ubuntu-24.04@"
    "sha256:d94c97dd9cacf183d0a6fd12a8e87b526e9e928307674ae9c94139139c0c6eae"
)
EXPECTED_SETTINGS = {
    "containers.containerClient": "com.microsoft.visualstudio.containers.podman",
    "containers.orchestratorClient": "com.microsoft.visualstudio.orchestrators.podmancompose",
    "dev.containers.dockerPath": "podman",
}
REQUIRED_RUN_ARGS = {
    "--userns=keep-id",
    "--cap-drop=ALL",
    "--security-opt=no-new-privileges",
}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def validate_settings(settings: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    for key, expected in EXPECTED_SETTINGS.items():
        if settings.get(key) != expected:
            errors.append(f"{key} must be {expected!r}.")
    return errors


def validate_devcontainer(config: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    for field in ("containerUser", "remoteUser"):
        if config.get(field) in (None, "", "root", "0"):
            errors.append(f"devcontainer {field} must be a named non-root user.")

    if config.get("updateRemoteUserUID") is not False:
        errors.append("updateRemoteUserUID must be false for the fixed keep-id mapping.")

    run_args = set(config.get("runArgs", []))
    missing = sorted(REQUIRED_RUN_ARGS - run_args)
    if missing:
        errors.append("devcontainer runArgs missing: " + ", ".join(missing) + ".")

    forbidden_fragments = ("privileged", "docker.sock", "podman.sock", "network=host")
    serialized = json.dumps(config).lower()
    for fragment in forbidden_fragments:
        if fragment in serialized:
            errors.append(f"devcontainer must not contain {fragment!r}.")

    ports = config.get("forwardPorts")
    if not isinstance(ports, list) or not ports:
        errors.append("devcontainer forwardPorts must contain an unprivileged app port.")
    else:
        for port in ports:
            if not isinstance(port, int) or port < 1024:
                errors.append(f"devcontainer forwarded port must be >= 1024: {port!r}.")

    requirements = config.get("hostRequirements", {})
    if requirements.get("memory") != "8gb" or requirements.get("storage") != "40gb":
        errors.append("hostRequirements must retain the 8gb memory and 40gb storage gates.")
    return errors


def validate_dockerfile(text: str) -> list[str]:
    errors: list[str] = []
    normalized = text.strip()
    if f"FROM {FLUTTER_IMAGE} AS flutter_sdk" not in normalized:
        errors.append("Flutter builder image must be version and digest pinned.")
    if f"FROM {BASE_IMAGE}" not in normalized:
        errors.append("Dev Container base image must be version and digest pinned.")
    if normalized.splitlines()[-1].strip() != "USER vscode":
        errors.append("Dockerfile must finish as USER vscode.")
    if "COPY --chown=vscode:vscode" not in normalized:
        errors.append("Flutter SDK must be owned by the non-root vscode user.")
    if "gpasswd --delete vscode sudo" not in normalized:
        errors.append("Dockerfile must remove vscode from the sudo group.")
    for forbidden in ("chmod 777", "EXPOSE 80", "USER root"):
        if forbidden.lower() in normalized.lower():
            errors.append(f"Dockerfile must not contain {forbidden!r}.")
    return errors


def validate_supabase_ports(config: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    port_paths = (
        ("api", "port"),
        ("db", "port"),
        ("db", "shadow_port"),
        ("studio", "port"),
        ("inbucket", "port"),
    )
    for section, key in port_paths:
        value = config.get(section, {}).get(key)
        if not isinstance(value, int) or value < 1024:
            errors.append(f"supabase.{section}.{key} must use a port >= 1024.")
    if config.get("studio", {}).get("api_url") != "http://127.0.0.1":
        errors.append("Supabase Studio API must remain bound to 127.0.0.1.")
    return errors


def validate_setup_script(text: str) -> list[str]:
    errors: list[str] = []
    required = (
        "RedHat.Podman",
        "ms-azuretools.vscode-containers",
        "ms-vscode-remote.remote-containers",
    )
    for marker in required:
        if marker not in text:
            errors.append(f"Windows setup script must include {marker}.")
    return errors


def validate_repository(root: Path) -> list[str]:
    errors: list[str] = []
    errors.extend(validate_settings(load_json(root / ".vscode" / "settings.json")))
    errors.extend(validate_devcontainer(load_json(root / ".devcontainer" / "devcontainer.json")))
    errors.extend(
        validate_dockerfile((root / ".devcontainer" / "Dockerfile").read_text(encoding="utf-8"))
    )
    with (root / "supabase" / "config.toml").open("rb") as handle:
        errors.extend(validate_supabase_ports(tomllib.load(handle)))
    errors.extend(
        validate_setup_script(
            (root / "scripts" / "setup_windows_dev.ps1").read_text(encoding="utf-8-sig")
        )
    )
    runbook = (root / "docs" / "ROOTLESS_CONTAINER_SETUP.md").read_text(encoding="utf-8")
    for marker in (
        "containers.containerClient",
        "dev.containers.dockerPath",
        "podman machine inspect",
        "volume permission",
        "特権ポート",
        "supabase start",
        "flutter run",
    ):
        if marker not in runbook:
            errors.append(f"rootless runbook missing {marker!r}.")
    return errors


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    errors = validate_repository(REPO_ROOT)
    print("Rootless container setup: " + ("PASS" if not errors else "FAIL"))
    for error in errors:
        print(f"error: {error}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
