#!/usr/bin/env python3
"""Read-only MUSUBI release preflight. Never prints secret values."""

from __future__ import annotations

import argparse
import ctypes
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Any


SECRET_NAMES = {
    "staging": {
        "SUPABASE_PROJECT_ID_STAGING",
        "SUPABASE_URL_STAGING",
        "SUPABASE_ANON_KEY_STAGING",
        "SUPABASE_DB_PASSWORD_STAGING",
        "SUPABASE_ACCESS_TOKEN",
        "FIREBASE_SERVICE_ACCOUNT_STAGING",
        "FIREBASE_PROJECT_ID",
    },
    "production": {
        "SUPABASE_PROJECT_ID_PROD",
        "SUPABASE_URL_PROD",
        "SUPABASE_ANON_KEY_PROD",
        "SUPABASE_DB_PASSWORD_PROD",
        "SUPABASE_ACCESS_TOKEN",
        "FIREBASE_SERVICE_ACCOUNT_PROD",
        "FIREBASE_PROJECT_ID",
    },
}


def run(command: list[str], cwd: Path, timeout: int = 15) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            command,
            cwd=cwd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
            check=False,
            shell=False,
        )
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout if isinstance(exc.stdout, str) else ""
        stderr = exc.stderr if isinstance(exc.stderr, str) else ""
        detail = f"{stderr}\ncommand timed out after {timeout}s".strip()
        return subprocess.CompletedProcess(command, 124, stdout, detail)


def memory_used_percent() -> float | None:
    if os.name == "nt":
        class MemoryStatus(ctypes.Structure):
            _fields_ = [
                ("length", ctypes.c_ulong),
                ("memory_load", ctypes.c_ulong),
                ("total_physical", ctypes.c_ulonglong),
                ("available_physical", ctypes.c_ulonglong),
                ("total_page_file", ctypes.c_ulonglong),
                ("available_page_file", ctypes.c_ulonglong),
                ("total_virtual", ctypes.c_ulonglong),
                ("available_virtual", ctypes.c_ulonglong),
                ("available_extended_virtual", ctypes.c_ulonglong),
            ]

        status = MemoryStatus()
        status.length = ctypes.sizeof(MemoryStatus)
        if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status)):
            return float(status.memory_load)
        return None

    meminfo = Path("/proc/meminfo")
    if meminfo.exists():
        values: dict[str, int] = {}
        for line in meminfo.read_text(encoding="utf-8").splitlines():
            key, value = line.split(":", 1)
            values[key] = int(value.strip().split()[0])
        total = values.get("MemTotal")
        available = values.get("MemAvailable")
        if total and available is not None:
            return round((1 - available / total) * 100, 1)
    return None


def finding(level: str, code: str, message: str) -> dict[str, str]:
    return {"level": level, "code": code, "message": message}


def git_value(repo: Path, *args: str) -> str | None:
    result = run(["git", *args], repo)
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def github_secret_names(repo: Path) -> tuple[set[str] | None, str | None]:
    if shutil.which("gh") is None:
        return None, "gh CLIが見つかりません"
    result = run(["gh", "secret", "list", "--app", "actions", "--json", "name"], repo)
    if result.returncode != 0:
        detail = result.stderr.strip().splitlines()
        return None, detail[-1] if detail else "GitHub Secrets一覧を取得できません"
    try:
        rows = json.loads(result.stdout)
        return {str(row["name"]) for row in rows}, None
    except (json.JSONDecodeError, KeyError, TypeError) as exc:
        return None, f"GitHub Secrets応答を解析できません: {exc}"


def inspect(args: argparse.Namespace) -> dict[str, Any]:
    repo = Path(args.repo).resolve()
    findings: list[dict[str, str]] = []
    used_memory = memory_used_percent()
    if used_memory is not None and used_memory >= args.memory_block_threshold:
        findings.append(
            finding(
                "BLOCK",
                "memory",
                f"メモリ使用率{used_memory:.1f}%です。Gitや重い処理を開始せずcheckpointを保存してください",
            )
        )
        return {
            "environment": args.environment,
            "repo": str(repo),
            "branch": "skipped-high-memory",
            "head": "skipped-high-memory",
            "dirty_paths": None,
            "memory_used_percent": used_memory,
            "findings": findings,
            "safe_to_continue": False,
        }

    root = git_value(repo, "rev-parse", "--show-toplevel")
    if root is None:
        findings.append(finding("BLOCK", "git-root", "Gitリポジトリではありません"))
        root_path = repo
    else:
        root_path = Path(root)
        findings.append(finding("PASS", "git-root", str(root_path)))

    if used_memory is None:
        findings.append(finding("WARN", "memory", "メモリ使用率を取得できません"))
    elif used_memory >= args.memory_warn_threshold:
        findings.append(finding("WARN", "memory", f"メモリ使用率{used_memory:.1f}%です"))
    else:
        findings.append(finding("PASS", "memory", f"メモリ使用率{used_memory:.1f}%です"))

    branch = git_value(root_path, "branch", "--show-current") or "detached"
    head = git_value(root_path, "rev-parse", "--short=12", "HEAD") or "unknown"
    dirty_result = run(
        ["git", "status", "--porcelain=v1"],
        root_path,
        timeout=args.git_timeout,
    )
    if dirty_result.returncode == 124:
        dirty_count: int | None = None
        findings.append(
            finding(
                "BLOCK",
                "dirty-tree",
                f"git statusが{args.git_timeout}秒で完了しません。rootを編集せず専用worktreeを使ってください",
            )
        )
    elif dirty_result.returncode != 0:
        dirty_count = None
        findings.append(finding("BLOCK", "dirty-tree", "作業ツリー状態を確認できません"))
    else:
        dirty_count = len(dirty_result.stdout.splitlines())
        if dirty_count:
            findings.append(
                finding("WARN", "dirty-tree", f"既存変更が{dirty_count}パスあります。専用worktreeを使ってください")
            )
        else:
            findings.append(finding("PASS", "dirty-tree", "作業ツリーはcleanです"))

    required_files = ["AGENTS.md", "pubspec.yaml", ".github/workflows/deploy-staging.yml", ".github/workflows/deploy-prod.yml"]
    missing_files = [item for item in required_files if not (root_path / item).exists()]
    if missing_files:
        findings.append(finding("BLOCK", "required-files", "不足: " + ", ".join(missing_files)))
    else:
        findings.append(finding("PASS", "required-files", "主要リリースファイルが存在します"))

    required_tools = {"git", "python"}
    optional_tools = {"dart", "flutter", "supabase", "firebase", "docker", "gh"}
    missing_required = sorted(tool for tool in required_tools if shutil.which(tool) is None)
    missing_optional = sorted(tool for tool in optional_tools if shutil.which(tool) is None)
    if missing_required:
        findings.append(finding("BLOCK", "required-tools", "不足: " + ", ".join(missing_required)))
    else:
        findings.append(finding("PASS", "required-tools", "gitとpythonを利用できます"))
    if missing_optional:
        findings.append(finding("WARN", "optional-tools", "未検出: " + ", ".join(missing_optional)))

    if args.check_github_secrets:
        if args.environment == "local":
            findings.append(finding("WARN", "github-secrets", "local環境にはsecret gateがありません"))
        else:
            existing, error = github_secret_names(root_path)
            if error:
                findings.append(finding("BLOCK", "github-secrets", error))
            else:
                required = SECRET_NAMES[args.environment]
                missing = sorted(required - (existing or set()))
                if missing:
                    findings.append(finding("BLOCK", "github-secrets", "不足: " + ", ".join(missing)))
                else:
                    findings.append(
                        finding("PASS", "github-secrets", f"{args.environment}用secret名がすべて存在します")
                    )

    return {
        "environment": args.environment,
        "repo": str(root_path),
        "branch": branch,
        "head": head,
        "dirty_paths": dirty_count,
        "memory_used_percent": used_memory,
        "findings": findings,
        "safe_to_continue": not any(item["level"] == "BLOCK" for item in findings),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=".")
    parser.add_argument("--environment", choices=("local", "staging", "production"), default="local")
    parser.add_argument("--check-github-secrets", action="store_true")
    parser.add_argument("--memory-warn-threshold", type=float, default=80.0)
    parser.add_argument("--memory-block-threshold", type=float, default=90.0)
    parser.add_argument("--git-timeout", type=int, default=15)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    report = inspect(args)

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(f"MUSUBI preflight: environment={report['environment']} branch={report['branch']} head={report['head']}")
        for item in report["findings"]:
            print(f"[{item['level']}] {item['code']}: {item['message']}")
        print("SAFE_TO_CONTINUE=" + ("true" if report["safe_to_continue"] else "false"))
    return 0 if report["safe_to_continue"] else 2


if __name__ == "__main__":
    sys.exit(main())
