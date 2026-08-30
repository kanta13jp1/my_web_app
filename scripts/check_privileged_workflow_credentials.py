#!/usr/bin/env python3
"""Check the staged GitHub Actions shared-secret migration contract."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path


DEFAULT_ROOT = Path(".github/workflows")
DEFAULT_MANIFEST = Path(".github/privileged-workflow-credentials.json")
TOP_LEVEL_KEY = re.compile(r"^(?P<key>[A-Za-z0-9_-]+):(?P<value>.*)$")
JOB_KEY = re.compile(r"^  (?P<name>[A-Za-z0-9_-]+):\s*(?:#.*)?$")
SCALAR_ENVIRONMENT = re.compile(
    r"^    environment:\s*(?P<name>[A-Za-z0-9._-]+)\s*(?:#.*)?$"
)
ENVIRONMENT_NAME = re.compile(
    r"^      name:\s*(?P<name>[A-Za-z0-9._-]+)\s*(?:#.*)?$"
)
SECRET_EXPRESSION = re.compile(
    r"\bsecrets\.(?P<name>ANTHROPIC_API_KEY|SUPABASE_SERVICE_ROLE_KEY)\b"
)
NON_PR_EVENT_GUARD = re.compile(
    r"^github\.event_name\s*==\s*['\"](?:workflow_dispatch|schedule|push|workflow_run)['\"]"
)
PULL_REQUEST_EXCLUSION = re.compile(
    r"github\.event_name\s*!=\s*['\"]pull_request['\"]"
)


@dataclass(frozen=True)
class Violation:
    subject: str
    message: str


def _top_level_blocks(lines: list[str]) -> dict[str, tuple[int, int, str]]:
    starts: list[tuple[int, str, str]] = []
    for index, line in enumerate(lines):
        match = TOP_LEVEL_KEY.match(line)
        if match:
            starts.append((index, match.group("key"), match.group("value").strip()))
    blocks: dict[str, tuple[int, int, str]] = {}
    for offset, (start, key, value) in enumerate(starts):
        end = starts[offset + 1][0] if offset + 1 < len(starts) else len(lines)
        blocks[key] = (start, end, value)
    return blocks


def _job_blocks(lines: list[str]) -> list[tuple[str, int, int]]:
    jobs = _top_level_blocks(lines).get("jobs")
    if jobs is None:
        return []
    starts: list[tuple[str, int]] = []
    for index in range(jobs[0] + 1, jobs[1]):
        match = JOB_KEY.match(lines[index])
        if match:
            starts.append((match.group("name"), index))
    return [
        (name, start, starts[offset + 1][1] if offset + 1 < len(starts) else jobs[1])
        for offset, (name, start) in enumerate(starts)
    ]


def _event_names(lines: list[str]) -> set[str]:
    block = _top_level_blocks(lines).get("on")
    if block is None:
        return set()
    start, end, value = block
    if value and not value.startswith("["):
        return {value.strip()}
    if value.startswith("["):
        return {item.strip() for item in value.strip("[]").split(",") if item.strip()}
    return {
        match.group("name")
        for line in lines[start + 1 : end]
        if (match := re.match(r"^  (?P<name>[A-Za-z0-9_-]+):", line))
    }


def _secret_names(lines: list[str]) -> set[str]:
    return {match.group("name") for line in lines for match in SECRET_EXPRESSION.finditer(line)}


def _job_environment(lines: list[str]) -> tuple[str | None, bool | None]:
    scalar_names = [
        match.group("name")
        for line in lines
        if (match := SCALAR_ENVIRONMENT.match(line))
    ]
    if len(scalar_names) == 1:
        return scalar_names[0], None
    for index, line in enumerate(lines):
        if line != "    environment:":
            continue
        nested: list[str] = []
        for candidate in lines[index + 1 :]:
            if candidate and not candidate.startswith("      "):
                break
            nested.append(candidate)
        names = [
            match.group("name")
            for candidate in nested
            if (match := ENVIRONMENT_NAME.match(candidate))
        ]
        deployments = [
            match.group("value") == "true"
            for candidate in nested
            if (
                match := re.match(
                    r"^      deployment:\s*(?P<value>true|false)\s*(?:#.*)?$",
                    candidate,
                )
            )
        ]
        if len(names) == 1 and len(deployments) == 1:
            return names[0], deployments[0]
    return None, None


def _job_if_expression(lines: list[str]) -> str:
    for line in lines:
        match = re.match(r"^    if:\s*(?P<value>.+)$", line)
        if match:
            return match.group("value").strip()
    return ""


def _pull_request_is_excluded(expression: str) -> bool:
    if not expression:
        return False
    if PULL_REQUEST_EXCLUSION.search(expression):
        return True
    if "pull_request" in expression:
        return False
    return bool(NON_PR_EVENT_GUARD.match(expression))


def load_manifest(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def find_violations(root: Path, manifest_path: Path) -> list[Violation]:
    violations: list[Violation] = []
    manifest = load_manifest(manifest_path)
    if manifest.get("schema_version") != 1:
        violations.append(Violation(str(manifest_path), "schema_version must be 1"))

    tracked = manifest.get("tracked_repository_secrets")
    if tracked != ["ANTHROPIC_API_KEY", "SUPABASE_SERVICE_ROLE_KEY"]:
        violations.append(
            Violation(
                str(manifest_path),
                "tracked_repository_secrets must contain the two migration targets in stable order",
            )
        )

    environments = manifest.get("environments")
    if not isinstance(environments, dict) or not environments:
        return [*violations, Violation(str(manifest_path), "environments must be a non-empty object")]

    declared_by_workflow: dict[str, str] = {}
    for environment, raw_config in environments.items():
        subject = f"{manifest_path}:{environment}"
        if not isinstance(raw_config, dict):
            violations.append(Violation(subject, "environment configuration must be an object"))
            continue
        if raw_config.get("deployment_branch_policy") != ["main"]:
            violations.append(Violation(subject, "deployment_branch_policy must be exactly ['main']"))
        if raw_config.get("deployment_tracking") is not False:
            violations.append(Violation(subject, "deployment_tracking must be false"))
        if not raw_config.get("trust_boundary") or not raw_config.get("purpose"):
            violations.append(Violation(subject, "trust_boundary and purpose are required"))
        if not raw_config.get("least_privilege_targets"):
            violations.append(Violation(subject, "least_privilege_targets is required"))
        workflows = raw_config.get("workflows")
        if not isinstance(workflows, list) or not workflows:
            violations.append(Violation(subject, "workflows must be a non-empty list"))
            continue
        for workflow in workflows:
            if workflow in declared_by_workflow:
                violations.append(
                    Violation(
                        subject,
                        f"{workflow} is already assigned to {declared_by_workflow[workflow]}",
                    )
                )
            else:
                declared_by_workflow[workflow] = environment

    actual_consumers: set[str] = set()
    files = sorted([*root.glob("*.yml"), *root.glob("*.yaml")])
    for path in files:
        lines = path.read_text(encoding="utf-8-sig").splitlines()
        workflow_secrets = _secret_names(lines)
        if not workflow_secrets:
            continue
        actual_consumers.add(path.name)
        expected_environment = declared_by_workflow.get(path.name)
        if expected_environment is None:
            violations.append(Violation(str(path), "tracked secret consumer is missing from the manifest"))
            continue

        blocks = _top_level_blocks(lines)
        jobs_block = blocks.get("jobs")
        if jobs_block is None:
            violations.append(Violation(str(path), "tracked secret consumer has no jobs block"))
            continue
        global_secrets = _secret_names(lines[: jobs_block[0]])
        events = _event_names(lines)
        environment_config = environments[expected_environment]
        targets = environment_config.get("least_privilege_targets", {})
        missing_targets = sorted(workflow_secrets - set(targets))
        if missing_targets:
            violations.append(
                Violation(
                    str(path),
                    f"manifest environment `{expected_environment}` lacks least-privilege targets for {missing_targets}",
                )
            )
        for job_name, start, end in _job_blocks(lines):
            job_lines = lines[start:end]
            job_secrets = global_secrets | _secret_names(job_lines)
            if not job_secrets:
                continue
            actual_environment, deployment_tracking = _job_environment(job_lines)
            if actual_environment != expected_environment:
                violations.append(
                    Violation(
                        f"{path}:{start + 1}",
                        f"job `{job_name}` uses {sorted(job_secrets)} and must declare environment `{expected_environment}`",
                    )
                )
            elif deployment_tracking is not False:
                violations.append(
                    Violation(
                        f"{path}:{start + 1}",
                        f"job `{job_name}` must set environment deployment to false",
                    )
                )
            if "pull_request" in events and not _pull_request_is_excluded(
                _job_if_expression(job_lines)
            ):
                violations.append(
                    Violation(
                        f"{path}:{start + 1}",
                        f"job `{job_name}` may expose a tracked secret to an internal pull_request",
                    )
                )

    missing_files = sorted(set(declared_by_workflow) - actual_consumers)
    for workflow in missing_files:
        violations.append(
            Violation(
                f"{manifest_path}:{workflow}",
                "manifest entry is stale because the workflow no longer consumes a tracked secret",
            )
        )
    return violations


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="backslashreplace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    args = parser.parse_args(argv)

    violations = find_violations(args.root, args.manifest)
    if violations:
        for violation in violations:
            print(f"{violation.subject}: {violation.message}")
        return 1
    print(
        "OK: privileged workflow credential inventory, environments, and PR boundaries match"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
