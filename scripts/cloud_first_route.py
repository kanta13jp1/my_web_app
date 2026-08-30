#!/usr/bin/env python3
"""Choose a cloud-first execution route from cheap local resource signals."""

from __future__ import annotations

import argparse
import ctypes
import json
import os
import shutil
from dataclasses import asdict, dataclass
from pathlib import Path


MIN_FREE_DISK_GIB = 30.0
MIN_FREE_MEMORY_GIB = 4.0
MAX_MEMORY_USED_PERCENT = 85.0


@dataclass(frozen=True)
class ResourceSnapshot:
    disk_free_gib: float
    memory_free_gib: float | None
    memory_used_percent: float | None


@dataclass(frozen=True)
class RouteDecision:
    route: str
    reasons: tuple[str, ...]
    snapshot: ResourceSnapshot


def decide_route(snapshot: ResourceSnapshot) -> RouteDecision:
    reasons: list[str] = []
    if snapshot.disk_free_gib < MIN_FREE_DISK_GIB:
        reasons.append(
            f"free disk {snapshot.disk_free_gib:.2f} GiB is below "
            f"{MIN_FREE_DISK_GIB:.0f} GiB"
        )
    if (
        snapshot.memory_free_gib is not None
        and snapshot.memory_free_gib < MIN_FREE_MEMORY_GIB
    ):
        reasons.append(
            f"free memory {snapshot.memory_free_gib:.2f} GiB is below "
            f"{MIN_FREE_MEMORY_GIB:.0f} GiB"
        )
    if (
        snapshot.memory_used_percent is not None
        and snapshot.memory_used_percent >= MAX_MEMORY_USED_PERCENT
    ):
        reasons.append(
            f"memory use {snapshot.memory_used_percent:.1f}% is at or above "
            f"{MAX_MEMORY_USED_PERCENT:.0f}%"
        )
    return RouteDecision(
        route="cloud_required" if reasons else "cloud_preferred",
        reasons=tuple(reasons),
        snapshot=snapshot,
    )


def _windows_memory() -> tuple[float, float] | None:
    if os.name != "nt":
        return None

    class MemoryStatusEx(ctypes.Structure):
        _fields_ = [
            ("dwLength", ctypes.c_ulong),
            ("dwMemoryLoad", ctypes.c_ulong),
            ("ullTotalPhys", ctypes.c_ulonglong),
            ("ullAvailPhys", ctypes.c_ulonglong),
            ("ullTotalPageFile", ctypes.c_ulonglong),
            ("ullAvailPageFile", ctypes.c_ulonglong),
            ("ullTotalVirtual", ctypes.c_ulonglong),
            ("ullAvailVirtual", ctypes.c_ulonglong),
            ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
        ]

    status = MemoryStatusEx()
    status.dwLength = ctypes.sizeof(status)
    if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status)):
        return None
    gib = 1024**3
    return status.ullAvailPhys / gib, float(status.dwMemoryLoad)


def _linux_memory() -> tuple[float, float] | None:
    meminfo = Path("/proc/meminfo")
    if not meminfo.is_file():
        return None
    values: dict[str, int] = {}
    for line in meminfo.read_text(encoding="utf-8").splitlines():
        key, _, value = line.partition(":")
        if key in {"MemTotal", "MemAvailable"}:
            values[key] = int(value.strip().split()[0])
    total = values.get("MemTotal")
    available = values.get("MemAvailable")
    if not total or available is None:
        return None
    free_gib = available * 1024 / (1024**3)
    used_percent = (1 - available / total) * 100
    return free_gib, used_percent


def read_snapshot(path: Path) -> ResourceSnapshot:
    disk_free_gib = shutil.disk_usage(path).free / (1024**3)
    memory = _windows_memory() or _linux_memory()
    return ResourceSnapshot(
        disk_free_gib=disk_free_gib,
        memory_free_gib=memory[0] if memory else None,
        memory_used_percent=memory[1] if memory else None,
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--path", type=Path, default=Path.cwd())
    parser.add_argument("--json", action="store_true", dest="as_json")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    decision = decide_route(read_snapshot(args.path.resolve()))
    if args.as_json:
        payload = asdict(decision)
        payload["reasons"] = list(decision.reasons)
        print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
        return 0

    snapshot = decision.snapshot
    memory_free = (
        f"{snapshot.memory_free_gib:.2f} GiB"
        if snapshot.memory_free_gib is not None
        else "unknown"
    )
    memory_used = (
        f"{snapshot.memory_used_percent:.1f}%"
        if snapshot.memory_used_percent is not None
        else "unknown"
    )
    print(f"Cloud-first route: {decision.route.upper()}")
    print(f"- Free disk: {snapshot.disk_free_gib:.2f} GiB")
    print(f"- Free memory: {memory_free}")
    print(f"- Memory used: {memory_used}")
    for reason in decision.reasons:
        print(f"- Trigger: {reason}")
    print("- Local: sparse editing and lightweight policy checks only")
    print("- Cloud: GitHub Actions owns analyze, tests, builds, and artifacts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
