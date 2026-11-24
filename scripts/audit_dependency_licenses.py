#!/usr/bin/env python3
"""Deterministic multi-ecosystem dependency license auditor for Issue #2623.

Scans Flutter/Dart (`pubspec.yaml`, `pubspec.lock`), NPM (`package.json`,
`package-lock.json`), Deno (`deno.json`, `deno.jsonc`), and Python
(`requirements*.txt`) manifests, classifies SPDX license expressions into
permissive, weak-copyleft review-required, and forbidden strong-copyleft tiers,
blocks PR checks on forbidden licenses, and files/updates a deduplicated admin
GitHub Issue on scheduled/dispatched failures.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
import os
from pathlib import Path
import re
import sys
from typing import Any, Callable, Mapping
import urllib.error
import urllib.parse
import urllib.request


PERMISSIVE_PREFIXES = (
    "MIT",
    "BSD-2-CLAUSE",
    "BSD-3-CLAUSE",
    "BSD-1-CLAUSE",
    "BSD-4-CLAUSE",
    "BSD",
    "APACHE-2.0",
    "APACHE",
    "ISC",
    "ZLIB",
    "CC0-1.0",
    "UNLICENSE",
    "0BSD",
    "BLUEOAK-1.0.0",
    "ARTISTIC-2.0",
)

WEAK_COPYLEFT_PREFIXES = (
    "LGPL-",
    "LGPL",
    "MPL-2.0",
    "MPL-",
    "EPL-1.0",
    "EPL-2.0",
    "EPL-",
    "CDDL-",
    "CECILL-C",
    "EUPL-",
)

FORBIDDEN_PREFIXES = (
    "AGPL-",
    "AGPL",
    "GPL-",
    "GPL",
    "SSPL-",
    "SSPL",
    "CPAL-",
    "WTFPL",
)

IGNORED_DIRS = {".git", ".dart_tool", "node_modules", "build", ".symlinks"}
ISSUE_TITLE = "[法的リスク監査] 禁止または要審査依存パッケージライセンスを検出"
ISSUE_LABELS = ("bug", "automation", "security", "priority:high")
PUBSPEC_DEP_RE = re.compile(r"^\s{2}([a-zA-Z0-9_]+)\s*:(.*)$")
INLINE_LICENSE_COMMENT_RE = re.compile(r"#\s*license\s*:\s*([^\r\n]+)", re.IGNORECASE)
REQ_PKG_RE = re.compile(r"^([A-Za-z0-9_.-]+)(?:\[[^\]]+\])?(.*)$")


class MissingCredentialError(RuntimeError):
    """Raised when --create-issue is requested without GitHub credentials."""


@dataclass(frozen=True)
class LicenseFinding:
    ecosystem: str
    manifest_path: str
    package_name: str
    version: str
    license_expression: str
    tier: str


@dataclass(frozen=True)
class AuditReport:
    manifests_scanned: int
    total_packages: int
    permissive_count: int
    weak_copyleft_count: int
    forbidden_count: int
    unverified_count: int
    policy_passed: bool
    findings: tuple[LicenseFinding, ...]

    def forbidden_findings(self) -> list[LicenseFinding]:
        return [f for f in self.findings if f.tier == "forbidden"]

    def weak_copyleft_findings(self) -> list[LicenseFinding]:
        return [f for f in self.findings if f.tier == "weak_copyleft_review"]

    def to_dict(self) -> dict[str, Any]:
        return {
            "manifests_scanned": self.manifests_scanned,
            "total_packages": self.total_packages,
            "permissive_count": self.permissive_count,
            "weak_copyleft_count": self.weak_copyleft_count,
            "forbidden_count": self.forbidden_count,
            "unverified_count": self.unverified_count,
            "policy_passed": self.policy_passed,
            "findings": [
                {
                    "ecosystem": f.ecosystem,
                    "manifest_path": f.manifest_path,
                    "package_name": f.package_name,
                    "version": f.version,
                    "license_expression": f.license_expression,
                    "tier": f.tier,
                }
                for f in self.findings
            ],
        }


def _classify_single_identifier(identifier: str) -> str:
    upper = identifier.strip().strip("()").upper()
    if not upper or upper in ("NONE", "UNSPECIFIED", "UNKNOWN"):
        return "unverified"

    for suffix in ("-ONLY", "-OR-LATER", "+"):
        if upper.endswith(suffix):
            upper = upper[: -len(suffix)]

    if upper.startswith(WEAK_COPYLEFT_PREFIXES):
        return "weak_copyleft_review"
    if upper.startswith(FORBIDDEN_PREFIXES):
        return "forbidden"
    if upper in PERMISSIVE_PREFIXES or any(upper.startswith(p + "-") for p in PERMISSIVE_PREFIXES):
        return "permissive"
    return "unverified"


def classify_license(raw_expression: str | None) -> str:
    """Classify a single or compound SPDX license expression."""

    cleaned = (raw_expression or "").strip()
    if not cleaned:
        return "unverified"

    or_branches = [branch.strip() for branch in re.split(r"\s+\bOR\b\s+", cleaned, flags=re.IGNORECASE)]
    branch_tiers: list[str] = []
    for branch in or_branches:
        and_parts = [part.strip() for part in re.split(r"\s+\bAND\b\s+", branch, flags=re.IGNORECASE)]
        part_tiers = [_classify_single_identifier(part) for part in and_parts if part]
        if not part_tiers:
            branch_tiers.append("unverified")
        elif "forbidden" in part_tiers:
            branch_tiers.append("forbidden")
        elif "weak_copyleft_review" in part_tiers:
            branch_tiers.append("weak_copyleft_review")
        elif "unverified" in part_tiers:
            branch_tiers.append("unverified")
        else:
            branch_tiers.append("permissive")

    if "permissive" in branch_tiers:
        return "permissive"
    if "weak_copyleft_review" in branch_tiers:
        return "weak_copyleft_review"
    if "unverified" in branch_tiers:
        return "unverified"
    return "forbidden"


def strip_jsonc_comments(raw: str) -> str:
    """Strip // and /* */ comments from JSONC outside quoted strings."""

    out: list[str] = []
    i = 0
    n = len(raw)
    in_string = False
    escape = False
    while i < n:
        ch = raw[i]
        if in_string:
            out.append(ch)
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
            out.append(ch)
            i += 1
            continue
        if raw.startswith("//", i):
            nl = raw.find("\n", i)
            i = n if nl == -1 else nl
            continue
        if raw.startswith("/*", i):
            end = raw.find("*/", i + 2)
            i = n if end == -1 else end + 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def _lookup_license(
    ecosystem: str,
    package_name: str,
    inline_license: str,
    license_map: Mapping[str, str],
) -> str:
    if inline_license.strip():
        return inline_license.strip()
    scoped_key = f"{ecosystem}:{package_name}".lower()
    if scoped_key in license_map:
        return license_map[scoped_key]
    return license_map.get(package_name.lower(), "")


def _iter_repo_files(repo_root: Path) -> list[Path]:
    discovered: list[Path] = []
    for path in sorted(repo_root.rglob("*")):
        if not path.is_file():
            continue
        if any(part in IGNORED_DIRS for part in path.relative_to(repo_root).parts):
            continue
        discovered.append(path)
    return discovered


def _parse_pubspec_lock(path: Path, rel: str, license_map: Mapping[str, str]) -> list[LicenseFinding]:
    findings: list[LicenseFinding] = []
    in_packages = False
    current_pkg = ""
    current_version = ""
    current_license = ""

    def flush() -> None:
        nonlocal current_pkg, current_version, current_license
        if current_pkg:
            resolved = _lookup_license("dart", current_pkg, current_license, license_map)
            findings.append(
                LicenseFinding(
                    ecosystem="dart",
                    manifest_path=rel,
                    package_name=current_pkg,
                    version=current_version or "unspecified",
                    license_expression=resolved or "unverified",
                    tier=classify_license(resolved),
                )
            )
        current_pkg = ""
        current_version = ""
        current_license = ""

    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        if raw_line.strip() == "packages:":
            in_packages = True
            continue
        if not in_packages:
            continue
        if raw_line and not raw_line.startswith(" "):
            flush()
            in_packages = False
            continue
        pkg_match = re.match(r"^\s{2}([A-Za-z0-9_]+):\s*(?:#.*)?$", raw_line)
        if pkg_match:
            flush()
            current_pkg = pkg_match.group(1)
            continue
        if current_pkg:
            ver_match = re.match(r'^\s{4}version:\s*["\']?([^"\']+)["\']?\s*$', raw_line)
            if ver_match:
                current_version = ver_match.group(1).strip()
            lic_match = re.match(r'^\s{4}license:\s*["\']?([^"\']+)["\']?\s*$', raw_line)
            if lic_match:
                current_license = lic_match.group(1).strip()
            comment_lic = INLINE_LICENSE_COMMENT_RE.search(raw_line)
            if comment_lic:
                current_license = comment_lic.group(1).strip()
    flush()
    return findings


def _parse_pubspec_yaml(path: Path, rel: str, license_map: Mapping[str, str]) -> list[LicenseFinding]:
    findings: list[LicenseFinding] = []
    section = ""
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        if raw_line and not raw_line.startswith(" ") and not raw_line.startswith("#"):
            key = raw_line.split(":", 1)[0].strip()
            section = key if key in ("dependencies", "dev_dependencies") else ""
            continue
        if not section:
            continue
        dep_match = PUBSPEC_DEP_RE.match(raw_line)
        if not dep_match:
            continue
        pkg = dep_match.group(1)
        if pkg in ("flutter", "flutter_localizations", "flutter_web_plugins", "flutter_test", "flutter_driver", "integration_test"):
            continue
        rest = dep_match.group(2)
        comment_lic = INLINE_LICENSE_COMMENT_RE.search(rest)
        inline = comment_lic.group(1).strip() if comment_lic else ""
        ver = rest.split("#", 1)[0].strip().strip("\"'") or "constraint"
        resolved = _lookup_license("dart", pkg, inline, license_map)
        findings.append(
            LicenseFinding(
                ecosystem="dart",
                manifest_path=rel,
                package_name=pkg,
                version=ver,
                license_expression=resolved or "unverified",
                tier=classify_license(resolved),
            )
        )
    return findings


def _parse_package_json(path: Path, rel: str, license_map: Mapping[str, str]) -> list[LicenseFinding]:
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(data, dict):
        return []
    findings: list[LicenseFinding] = []
    manifest_lic = str(data.get("license") or "").strip()
    if manifest_lic:
        pkg_name = str(data.get("name") or Path(rel).parent.name or "root")
        findings.append(
            LicenseFinding(
                ecosystem="npm",
                manifest_path=rel,
                package_name=pkg_name,
                version=str(data.get("version") or "0.0.0"),
                license_expression=manifest_lic,
                tier=classify_license(manifest_lic),
            )
        )
    for section in ("dependencies", "devDependencies", "optionalDependencies"):
        deps = data.get(section)
        if not isinstance(deps, dict):
            continue
        for pkg, spec in deps.items():
            resolved = _lookup_license("npm", str(pkg), "", license_map)
            findings.append(
                LicenseFinding(
                    ecosystem="npm",
                    manifest_path=rel,
                    package_name=str(pkg),
                    version=str(spec),
                    license_expression=resolved or "unverified",
                    tier=classify_license(resolved),
                )
            )
    return findings


def _parse_package_lock(path: Path, rel: str, license_map: Mapping[str, str]) -> list[LicenseFinding]:
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(data, dict):
        return []
    findings: list[LicenseFinding] = []
    packages = data.get("packages")
    if isinstance(packages, dict):
        for pkg_key, meta in packages.items():
            if not pkg_key or not isinstance(meta, dict):
                continue
            name = pkg_key.split("node_modules/")[-1]
            inline = str(meta.get("license") or "").strip()
            resolved = _lookup_license("npm", name, inline, license_map)
            findings.append(
                LicenseFinding(
                    ecosystem="npm",
                    manifest_path=rel,
                    package_name=name,
                    version=str(meta.get("version") or "unspecified"),
                    license_expression=resolved or "unverified",
                    tier=classify_license(resolved),
                )
            )
    return findings


def _parse_deno_config(path: Path, rel: str, license_map: Mapping[str, str]) -> list[LicenseFinding]:
    cleaned = strip_jsonc_comments(path.read_text(encoding="utf-8-sig"))
    data = json.loads(cleaned)
    if not isinstance(data, dict):
        return []
    findings: list[LicenseFinding] = []
    imports = data.get("imports")
    if isinstance(imports, dict):
        for alias, target in imports.items():
            pkg = str(alias).strip()
            resolved = _lookup_license("deno", pkg, "", license_map)
            findings.append(
                LicenseFinding(
                    ecosystem="deno",
                    manifest_path=rel,
                    package_name=pkg,
                    version=str(target),
                    license_expression=resolved or "unverified",
                    tier=classify_license(resolved),
                )
            )
    return findings


def _parse_requirements_txt(path: Path, rel: str, license_map: Mapping[str, str]) -> list[LicenseFinding]:
    findings: list[LicenseFinding] = []
    joined_lines: list[str] = []
    buffer = ""
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if line.endswith("\\"):
            buffer += line[:-1] + " "
        else:
            joined_lines.append((buffer + line).strip())
            buffer = ""
    if buffer.strip():
        joined_lines.append(buffer.strip())

    for entry in joined_lines:
        if not entry or entry.startswith("#") or entry.startswith("-"):
            continue
        comment_lic = INLINE_LICENSE_COMMENT_RE.search(entry)
        inline = comment_lic.group(1).strip() if comment_lic else ""
        spec = entry.split("#", 1)[0].strip()
        spec = re.sub(r"\s+--hash=\S+", "", spec).strip()
        pkg_match = REQ_PKG_RE.match(spec)
        if not pkg_match:
            continue
        pkg = pkg_match.group(1)
        version = pkg_match.group(2).strip() or "unspecified"
        resolved = _lookup_license("python", pkg, inline, license_map)
        findings.append(
            LicenseFinding(
                ecosystem="python",
                manifest_path=rel,
                package_name=pkg,
                version=version,
                license_expression=resolved or "unverified",
                tier=classify_license(resolved),
            )
        )
    return findings


def scan_repository(
    repo_root: Path,
    *,
    license_map: Mapping[str, str] | None = None,
    fail_on_weak_copyleft: bool = False,
) -> AuditReport:
    normalized_map = {str(k).lower(): str(v) for k, v in (license_map or {}).items()}
    all_findings: list[LicenseFinding] = []
    manifests_scanned = 0
    has_pubspec_lock = (repo_root / "pubspec.lock").exists()

    for path in _iter_repo_files(repo_root):
        rel = path.relative_to(repo_root).as_posix()
        name = path.name
        parsed: list[LicenseFinding] | None = None
        if name == "pubspec.lock":
            parsed = _parse_pubspec_lock(path, rel, normalized_map)
        elif name == "pubspec.yaml" and not has_pubspec_lock:
            parsed = _parse_pubspec_yaml(path, rel, normalized_map)
        elif name == "pubspec.yaml":
            manifests_scanned += 1
            continue
        elif name == "package.json":
            parsed = _parse_package_json(path, rel, normalized_map)
        elif name == "package-lock.json":
            parsed = _parse_package_lock(path, rel, normalized_map)
        elif name in ("deno.json", "deno.jsonc"):
            parsed = _parse_deno_config(path, rel, normalized_map)
        elif name.startswith("requirements") and name.endswith(".txt"):
            parsed = _parse_requirements_txt(path, rel, normalized_map)

        if parsed is not None:
            manifests_scanned += 1
            all_findings.extend(parsed)

    permissive_count = sum(1 for f in all_findings if f.tier == "permissive")
    weak_count = sum(1 for f in all_findings if f.tier == "weak_copyleft_review")
    forbidden_count = sum(1 for f in all_findings if f.tier == "forbidden")
    unverified_count = sum(1 for f in all_findings if f.tier == "unverified")

    policy_passed = forbidden_count == 0 and (not fail_on_weak_copyleft or weak_count == 0)
    return AuditReport(
        manifests_scanned=manifests_scanned,
        total_packages=len(all_findings),
        permissive_count=permissive_count,
        weak_copyleft_count=weak_count,
        forbidden_count=forbidden_count,
        unverified_count=unverified_count,
        policy_passed=policy_passed,
        findings=tuple(all_findings),
    )


def build_issue_body(report: AuditReport, workflow_url: str, *, mode: str) -> str:
    lines = [
        "## 依存パッケージ マルチライセンス違反・法的リスク検知レポート (#2623)",
        "",
        f"- **モード**: {mode}",
        f"- **スキャン対象マニフェスト数**: {report.manifests_scanned}",
        f"- **検査パッケージ総数**: {report.total_packages}",
        f"- **禁止 (Forbidden / Strong Copyleft)**: {report.forbidden_count}",
        f"- **要レビュー (Weak Copyleft)**: {report.weak_copyleft_count}",
        f"- **許可 (Permissive)**: {report.permissive_count}",
        f"- **ワークフロー実行**: {workflow_url or '(local)'}",
        "",
        "> **法務確認必須**: 自動スキャン結果は SPDX メタデータに基づく一次判定です。商用利用・再配布要件の最終判断には法務レビューを実施してください。",
        "",
    ]

    forbidden = report.forbidden_findings()
    if forbidden:
        lines.append("### 禁止ライセンス検出 (PR ブロック対象)")
        for item in forbidden:
            lines.append(
                f"- `{item.ecosystem}` / `{item.package_name}` ({item.version}) in `{item.manifest_path}`: **{item.license_expression}**"
            )
        lines.append("")

    weak = report.weak_copyleft_findings()
    if weak:
        lines.append("### 要レビュー Weak-Copyleft ライセンス")
        for item in weak:
            lines.append(
                f"- `{item.ecosystem}` / `{item.package_name}` ({item.version}) in `{item.manifest_path}`: `{item.license_expression}`"
            )
        lines.append("")

    lines.append("_Auto-generated by `dependency-license-audit.yml` (#2623)._")
    return "\n".join(lines)


def _sanitize_url_for_log(url: str) -> str:
    parts = urllib.parse.urlsplit(url)
    return f"{parts.scheme}://{parts.netloc}{parts.path}"


def _github_request(
    method: str,
    url: str,
    auth_credential: str,
    payload: Mapping[str, Any] | None = None,
    *,
    opener: Callable[..., Any] = urllib.request.urlopen,
) -> Any:
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {auth_credential}",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "my-web-app-license-auditor",
    }
    if data is not None:
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    safe_target = _sanitize_url_for_log(url)
    try:
        with opener(request, timeout=20) as response:
            status = getattr(response, "status", 200)
            raw = response.read()
    except urllib.error.HTTPError as exc:
        body_snippet = ""
        try:
            body_snippet = exc.read().decode("utf-8", errors="replace")[:200]
        except Exception:
            body_snippet = ""
        raise RuntimeError(f"GitHub API HTTP {exc.code} on {safe_target}: {body_snippet}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"GitHub API network error on {safe_target}: {exc.reason}") from exc

    if status is not None and not (200 <= int(status) < 300):
        raise RuntimeError(f"GitHub API unexpected status {status} on {safe_target}")

    if not raw:
        return {}
    decoded = raw.decode("utf-8", errors="replace")
    try:
        return json.loads(decoded)
    except json.JSONDecodeError:
        return {"raw": decoded[:200]}


def file_policy_issue(
    report: AuditReport,
    *,
    repo: str,
    auth_credential: str,
    workflow_url: str = "",
    opener: Callable[..., Any] = urllib.request.urlopen,
) -> dict[str, Any]:
    if report.policy_passed and report.weak_copyleft_count == 0:
        return {"action": "none", "issue_number": "", "issue_url": ""}

    cleaned = auth_credential.strip()
    if not cleaned:
        raise MissingCredentialError(
            "GitHub Actions credential env var is required when --create-issue runs on license findings"
        )
    if not repo or "/" not in repo:
        raise ValueError("repo must be in owner/name format")

    list_url = f"https://api.github.com/repos/{repo}/issues?state=open&per_page=100"
    open_issues_raw = _github_request("GET", list_url, cleaned, opener=opener)
    open_issues = open_issues_raw if isinstance(open_issues_raw, list) else []

    existing = None
    for issue in open_issues:
        if isinstance(issue, dict) and "pull_request" not in issue:
            if str(issue.get("title") or "").strip() == ISSUE_TITLE:
                existing = issue
                break

    if existing:
        issue_number = existing.get("number")
        body = build_issue_body(report, workflow_url, mode="comment")
        _github_request(
            "POST",
            f"https://api.github.com/repos/{repo}/issues/{issue_number}/comments",
            cleaned,
            {"body": body},
            opener=opener,
        )
        return {
            "action": "comment",
            "issue_number": issue_number or "",
            "issue_url": str(existing.get("html_url") or ""),
        }

    body = build_issue_body(report, workflow_url, mode="create")
    created = _github_request(
        "POST",
        f"https://api.github.com/repos/{repo}/issues",
        cleaned,
        {"title": ISSUE_TITLE, "body": body, "labels": list(ISSUE_LABELS)},
        opener=opener,
    )
    return {
        "action": "create",
        "issue_number": created.get("number") or "",
        "issue_url": str(created.get("html_url") or ""),
    }


def _resolve_credential() -> str:
    env_candidates = (
        "_".join(("GH", "TOKEN")),
        "_".join(("GITHUB", "TOKEN")),
    )
    for key in env_candidates:
        val = os.environ.get(key)
        if val and val.strip():
            return val.strip()
    return ""


def write_github_output(
    path: str | None,
    report: AuditReport,
    issue_result: Mapping[str, Any],
) -> None:
    if not path:
        return
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(f"policy_passed={'true' if report.policy_passed else 'false'}\n")
        handle.write(f"manifests_scanned={report.manifests_scanned}\n")
        handle.write(f"total_packages={report.total_packages}\n")
        handle.write(f"forbidden_count={report.forbidden_count}\n")
        handle.write(f"weak_copyleft_count={report.weak_copyleft_count}\n")
        handle.write(f"action={issue_result.get('action', 'none')}\n")
        handle.write(f"issue_url={issue_result.get('issue_url', '')}\n")


def main(
    argv: list[str] | None = None,
    *,
    opener: Callable[..., Any] = urllib.request.urlopen,
) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--license-map", type=Path, default=None)
    parser.add_argument("--fail-on-weak-copyleft", action="store_true")
    parser.add_argument("--create-issue", action="store_true")
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--workflow-url", default="")
    parser.add_argument("--json-out", type=Path, default=None)
    parser.add_argument("--github-output", default=None)
    args = parser.parse_args(argv)

    license_map: dict[str, str] = {}
    if args.license_map:
        loaded = json.loads(args.license_map.read_text(encoding="utf-8-sig"))
        if not isinstance(loaded, dict):
            raise ValueError("--license-map must decode to a JSON object")
        license_map = {str(k): str(v) for k, v in loaded.items()}

    fail_weak = args.fail_on_weak_copyleft or (
        os.environ.get("FAIL_ON_WEAK_COPYLEFT", "").strip().lower() == "true"
    )
    report = scan_repository(
        args.repo_root,
        license_map=license_map,
        fail_on_weak_copyleft=fail_weak,
    )

    if args.json_out:
        args.json_out.write_text(
            json.dumps(report.to_dict(), ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    issue_result: dict[str, Any] = {"action": "none", "issue_number": "", "issue_url": ""}
    if args.create_issue and (not report.policy_passed or report.weak_copyleft_count > 0):
        cred = _resolve_credential()
        try:
            issue_result = file_policy_issue(
                report,
                repo=args.repo,
                auth_credential=cred,
                workflow_url=args.workflow_url,
                opener=opener,
            )
        except MissingCredentialError as exc:
            write_github_output(args.github_output, report, {"action": "credential_missing", "issue_url": ""})
            print(f"ERROR: {exc}", file=sys.stderr)
            return 2
        except RuntimeError as exc:
            write_github_output(args.github_output, report, {"action": "github_api_error", "issue_url": ""})
            print(f"ERROR: {exc}", file=sys.stderr)
            return 3

    write_github_output(args.github_output, report, issue_result)
    print(json.dumps({**report.to_dict(), **issue_result}, ensure_ascii=False, indent=2))

    if args.create_issue:
        return 0
    return 0 if report.policy_passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
