#!/usr/bin/env python3
"""Audit Docker disk use and optionally prune without deleting volumes.

The default mode is read-only. Applying cleanup requires an exact confirmation
phrase and deliberately omits every Docker/Supabase volume deletion flag. This
keeps local Supabase database volumes outside the automated cleanup boundary.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from typing import Callable


CONFIRMATION_PHRASE = "PRUNE_WITHOUT_VOLUMES"
PROTECTED_VOLUME_PATTERN = re.compile(
    r"(?:^|[-_.])(supabase|postgres|postgresql|pgdata|database|db[-_.]?data)(?:$|[-_.])",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class CommandResult:
    code: int
    stdout: str
    stderr: str


@dataclass(frozen=True)
class VolumeRecord:
    name: str
    driver: str
    labels: str
    protected: bool


Runner = Callable[[list[str], int], CommandResult]


def run_command(command: list[str], timeout: int = 30) -> CommandResult:
    try:
        result = subprocess.run(
            command,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
        )
    except FileNotFoundError as error:
        return CommandResult(127, "", str(error))
    except subprocess.TimeoutExpired as error:
        stdout = error.stdout if isinstance(error.stdout, str) else ""
        stderr = error.stderr if isinstance(error.stderr, str) else ""
        return CommandResult(124, stdout.strip(), stderr.strip() or "command timed out")
    except OSError as error:
        return CommandResult(126, "", str(error))
    return CommandResult(result.returncode, result.stdout.strip(), result.stderr.strip())


def parse_json_lines(raw: str) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            rows.append(value)
    return rows


def field(row: dict[str, object], *names: str) -> str:
    for name in names:
        value = row.get(name)
        if value is not None:
            return str(value)
    return ""


def is_protected_volume(name: str, labels: str = "") -> bool:
    searchable = f"{name} {labels}".replace("/", "-")
    return bool(PROTECTED_VOLUME_PATTERN.search(searchable))


def parse_volumes(raw: str) -> list[VolumeRecord]:
    volumes: list[VolumeRecord] = []
    for row in parse_json_lines(raw):
        name = field(row, "Name", "name")
        labels = field(row, "Labels", "labels")
        volumes.append(
            VolumeRecord(
                name=name,
                driver=field(row, "Driver", "driver"),
                labels=labels,
                protected=is_protected_volume(name, labels),
            )
        )
    return volumes


def safe_prune_command(older_than_hours: int) -> list[str]:
    if older_than_hours < 24:
        raise ValueError("older_than_hours must be at least 24")
    # Never add --volumes here. Volume cleanup is an explicit manual operation
    # after the backup procedure in docs/CONTAINER_RESOURCE_CLEANUP.md.
    return [
        "docker",
        "system",
        "prune",
        "--force",
        "--filter",
        f"until={older_than_hours}h",
    ]


def audit(runner: Runner = run_command) -> dict[str, object]:
    if shutil.which("docker") is None:
        return {
            "docker_status": "unavailable",
            "docker_error": "docker executable not found",
            "disk_usage": "",
            "stopped_containers": [],
            "volumes": [],
            "protected_volumes": [],
        }

    info = runner(["docker", "info", "--format", "{{json .ServerVersion}}"], 15)
    if info.code != 0:
        return {
            "docker_status": "unavailable",
            "docker_error": info.stderr or info.stdout or "docker daemon unavailable",
            "disk_usage": "",
            "stopped_containers": [],
            "volumes": [],
            "protected_volumes": [],
        }

    disk = runner(["docker", "system", "df"], 30)
    containers = runner(
        ["docker", "ps", "-a", "--filter", "status=exited", "--format", "{{json .}}"],
        30,
    )
    volume_result = runner(["docker", "volume", "ls", "--format", "{{json .}}"], 30)
    volumes = parse_volumes(volume_result.stdout) if volume_result.code == 0 else []
    return {
        "docker_status": "ready",
        "docker_server_version": info.stdout.strip('"'),
        "docker_error": "",
        "disk_usage": disk.stdout if disk.code == 0 else "",
        "stopped_containers": parse_json_lines(containers.stdout),
        "volumes": [asdict(volume) for volume in volumes],
        "protected_volumes": [volume.name for volume in volumes if volume.protected],
        "inventory_errors": [
            message
            for message in (
                disk.stderr if disk.code != 0 else "",
                containers.stderr if containers.code != 0 else "",
                volume_result.stderr if volume_result.code != 0 else "",
            )
            if message
        ],
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Run the volume-excluding prune after the exact confirmation phrase is supplied.",
    )
    parser.add_argument(
        "--confirm",
        default="",
        help=f"Required with --apply; must equal {CONFIRMATION_PHRASE}.",
    )
    parser.add_argument(
        "--older-than-hours",
        type=int,
        default=168,
        help="Only prune resources unused for at least this many hours (minimum: 24).",
    )
    parser.add_argument("--json", action="store_true", help="Print machine-readable JSON only.")
    return parser.parse_args(argv)


def execute(argv: list[str], runner: Runner = run_command) -> tuple[int, dict[str, object]]:
    args = parse_args(argv)
    try:
        prune_command = safe_prune_command(args.older_than_hours)
    except ValueError as error:
        return 2, {"status": "refused", "reason": str(error)}

    report = audit(runner)
    report.update(
        {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "mode": "apply" if args.apply else "dry-run",
            "status": "audited",
            "safe_prune_command": prune_command,
            "volumes_deleted": False,
            "supabase_no_backup_used": False,
        }
    )
    if not args.apply:
        return 0, report
    if args.confirm != CONFIRMATION_PHRASE:
        report.update(
            {
                "status": "refused",
                "reason": f"--confirm must equal {CONFIRMATION_PHRASE}",
            }
        )
        return 2, report
    if report["docker_status"] != "ready":
        report.update({"status": "failed", "reason": "docker is unavailable"})
        return 1, report

    result = runner(prune_command, 300)
    report.update(
        {
            "status": "success" if result.code == 0 else "failed",
            "prune_returncode": result.code,
            "prune_stdout": result.stdout,
            "prune_stderr": result.stderr,
        }
    )
    return (0 if result.code == 0 else 1), report


def print_human(report: dict[str, object]) -> None:
    print("=== Container Cleanup Guard ===")
    print(f"mode: {report.get('mode', 'unknown')}")
    print(f"status: {report.get('status', 'unknown')}")
    print(f"docker: {report.get('docker_status', 'unknown')}")
    if report.get("docker_error"):
        print(f"docker error: {report['docker_error']}")
    protected = report.get("protected_volumes") or []
    print(f"protected volume candidates: {len(protected)}")
    for name in protected:
        print(f"- {name}")
    print("volumes deleted: no")
    command = report.get("safe_prune_command")
    if command:
        print("safe prune: " + " ".join(str(part) for part in command))
    if report.get("reason"):
        print(f"reason: {report['reason']}")
    if report.get("disk_usage"):
        print("\nDocker disk usage:\n" + str(report["disk_usage"]))
    if report.get("prune_stdout"):
        print("\nPrune result:\n" + str(report["prune_stdout"]))


def main(argv: list[str]) -> int:
    code, report = execute(argv)
    if "--json" in argv:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print_human(report)
    return code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
