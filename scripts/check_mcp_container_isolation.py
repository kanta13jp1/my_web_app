#!/usr/bin/env python3
"""Validate the #1645 MCP container isolation contract and PoC smoke."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = REPO_ROOT / "config" / "mcp-container-isolation.json"
REQUIRED_HIGH_RISK_SCOPES = {
    "delete",
    "send",
    "purchase",
    "external_share",
    "credential_access",
    "shell_execute",
    "filesystem_write",
    "production_write",
}
REQUIRED_FLOW_STEPS = {
    "discover",
    "classify",
    "approve",
    "launch_isolated",
    "audit",
    "fallback",
}
ALLOWED_RISKS = {"low", "medium", "high", "denied"}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def string_list(value: Any, *, allow_empty: bool = False) -> bool:
    return isinstance(value, list) and (allow_empty or bool(value)) and all(
        isinstance(item, str) for item in value
    )


def repo_path(root: Path, relative_path: str) -> Path:
    path = Path(relative_path)
    if path.is_absolute():
        raise ValueError(f"path must be relative to repo root: {relative_path}")
    return root / path


def lower_set(value: Any) -> set[str]:
    if not isinstance(value, list):
        return set()
    return {str(item).strip().lower() for item in value}


def validate_compose_contract(compose_text: str) -> list[str]:
    errors: list[str] = []
    normalized = compose_text.lower().replace("'", '"')
    if 'network_mode: "none"' not in normalized and "network_mode: none" not in normalized:
        errors.append("docker-compose.yml must set network_mode: none.")
    if "read_only: true" not in normalized:
        errors.append("docker-compose.yml must set read_only: true.")
    if "cap_drop:" not in normalized or "- all" not in normalized:
        errors.append("docker-compose.yml must drop all Linux capabilities.")
    if "no-new-privileges:true" not in normalized:
        errors.append("docker-compose.yml must set no-new-privileges:true.")

    forbidden = {
        "privileged: true": "privileged containers are not allowed.",
        "network_mode: host": "host networking is not allowed.",
        "ports:": "published ports are not allowed for the stdio PoC.",
        "volumes:": "host volumes are not allowed for the stdio PoC.",
        "secrets:": "compose secrets are not allowed for the low-risk PoC.",
    }
    for marker, message in forbidden.items():
        if marker in normalized:
            errors.append(message)
    return errors


def validate_dockerfile_contract(dockerfile_text: str) -> list[str]:
    errors: list[str] = []
    normalized = dockerfile_text.lower()
    if "user mcp" not in normalized:
        errors.append("Dockerfile must switch to the non-root mcp user.")
    if "user root" in normalized:
        errors.append("Dockerfile must not switch back to root.")
    if "expose " in normalized:
        errors.append("Dockerfile must not expose ports for the stdio PoC.")
    if "add http://" in normalized or "add https://" in normalized:
        errors.append("Dockerfile must not fetch remote URLs with ADD.")
    return errors


def validate_contract(root: Path, contract: dict[str, Any]) -> list[str]:
    errors: list[str] = []

    if contract.get("schemaVersion") != 1:
        errors.append("schemaVersion must be 1.")
    if contract.get("status") != "active":
        errors.append("status must be active.")
    if contract.get("issue") != 1645:
        errors.append("issue must be 1645.")
    if contract.get("defaultIsolationDecision") != "container_or_deny":
        errors.append("defaultIsolationDecision must be container_or_deny.")

    owner = contract.get("ownerModel")
    if not isinstance(owner, dict):
        errors.append("ownerModel must be an object.")
    elif owner.get("activeInstances") != ["Claude Code #1", "Codex #1"]:
        errors.append("ownerModel.activeInstances must be Claude Code #1 + Codex #1 only.")

    gate = contract.get("highRiskApprovalGate")
    if not isinstance(gate, dict):
        errors.append("highRiskApprovalGate must be an object.")
        gate_policy = ""
        gate_scopes: set[str] = set()
    else:
        gate_policy = str(gate.get("policy", ""))
        gate_scopes = lower_set(gate.get("scopes"))
        if gate_policy != "docs/AGENT_TOOL_POLICY.md":
            errors.append("highRiskApprovalGate.policy must point to docs/AGENT_TOOL_POLICY.md.")
        if str(gate.get("requiredApproval", "")).lower() != "ceo":
            errors.append("highRiskApprovalGate.requiredApproval must be CEO.")
        if gate.get("failureMode") != "fail_closed":
            errors.append("highRiskApprovalGate.failureMode must be fail_closed.")
        missing = sorted(REQUIRED_HIGH_RISK_SCOPES - gate_scopes)
        if missing:
            errors.append("highRiskApprovalGate.scopes missing: " + ", ".join(missing) + ".")

    steps = {
        str(item.get("step", ""))
        for item in contract.get("dynamicMcpFlow", [])
        if isinstance(item, dict)
    }
    missing_steps = sorted(REQUIRED_FLOW_STEPS - steps)
    if missing_steps:
        errors.append("dynamicMcpFlow missing steps: " + ", ".join(missing_steps) + ".")

    matrix = contract.get("serverExecutionMatrix")
    if not isinstance(matrix, list) or not matrix:
        errors.append("serverExecutionMatrix must be a non-empty list.")
        matrix = []

    for index, entry in enumerate(matrix):
        if not isinstance(entry, dict):
            errors.append(f"serverExecutionMatrix[{index}] must be an object.")
            continue
        entry_id = str(entry.get("id", f"<index {index}>"))
        for field in (
            "managedMcpId",
            "risk",
            "executionForm",
            "permissions",
            "containerIsolation",
            "auditLog",
            "failureFallback",
            "approvalRequiredFor",
            "approvalGate",
        ):
            if field not in entry:
                errors.append(f"{entry_id}: missing {field}.")

        risk = str(entry.get("risk", "")).lower()
        if risk not in ALLOWED_RISKS:
            errors.append(f"{entry_id}: risk must be one of {', '.join(sorted(ALLOWED_RISKS))}.")

        permissions = lower_set(entry.get("permissions"))
        approvals = lower_set(entry.get("approvalRequiredFor"))
        if not string_list(entry.get("permissions")):
            errors.append(f"{entry_id}: permissions must be a non-empty string list.")
        if not string_list(entry.get("approvalRequiredFor")):
            errors.append(f"{entry_id}: approvalRequiredFor must be a non-empty string list.")
        if not str(entry.get("auditLog", "")).strip():
            errors.append(f"{entry_id}: auditLog must be non-empty.")
        if not str(entry.get("failureFallback", "")).strip():
            errors.append(f"{entry_id}: failureFallback must be non-empty.")

        isolation = entry.get("containerIsolation")
        if not isinstance(isolation, dict):
            errors.append(f"{entry_id}: containerIsolation must be an object.")
        else:
            if not string_list(isolation.get("capDrop")) or "ALL" not in isolation.get("capDrop", []):
                errors.append(f"{entry_id}: containerIsolation.capDrop must include ALL.")
            if not isinstance(isolation.get("readOnlyRootFilesystem"), bool):
                errors.append(f"{entry_id}: readOnlyRootFilesystem must be boolean.")
            if not isinstance(isolation.get("runAsNonRoot"), bool):
                errors.append(f"{entry_id}: runAsNonRoot must be boolean.")
            if not isinstance(isolation.get("secrets"), list):
                errors.append(f"{entry_id}: containerIsolation.secrets must be a list.")
            if isolation.get("ports") != []:
                errors.append(f"{entry_id}: containerIsolation.ports must be empty.")

        high_scope_mentions = (permissions | approvals) & REQUIRED_HIGH_RISK_SCOPES
        if risk == "low" and permissions & REQUIRED_HIGH_RISK_SCOPES:
            errors.append(f"{entry_id}: low-risk entries cannot request high-risk permissions.")
        if risk in {"high", "denied"} or high_scope_mentions:
            if entry.get("approvalGate") != gate_policy:
                errors.append(f"{entry_id}: high-risk scopes must reference {gate_policy}.")
            missing_approvals = sorted((permissions & REQUIRED_HIGH_RISK_SCOPES) - approvals)
            if missing_approvals:
                errors.append(
                    f"{entry_id}: high-risk permissions missing approvalRequiredFor: "
                    + ", ".join(missing_approvals)
                    + "."
                )

    poc = contract.get("pocLaunch")
    if not isinstance(poc, dict):
        errors.append("pocLaunch must be an object.")
        return errors

    if poc.get("risk") != "low":
        errors.append("pocLaunch.risk must be low.")
    if poc.get("networkMode") != "none":
        errors.append("pocLaunch.networkMode must be none.")
    if poc.get("readOnlyRootFilesystem") is not True:
        errors.append("pocLaunch.readOnlyRootFilesystem must be true.")
    if poc.get("runAsNonRoot") is not True:
        errors.append("pocLaunch.runAsNonRoot must be true.")
    if poc.get("noNewPrivileges") is not True:
        errors.append("pocLaunch.noNewPrivileges must be true.")
    if "ALL" not in poc.get("capDrop", []):
        errors.append("pocLaunch.capDrop must include ALL.")
    if poc.get("ports") != []:
        errors.append("pocLaunch.ports must be empty.")
    if poc.get("secrets") != []:
        errors.append("pocLaunch.secrets must be empty.")
    if not str(poc.get("auditLog", "")).strip():
        errors.append("pocLaunch.auditLog must be non-empty.")

    for field in ("composeFile", "dockerfile", "fixtureInput"):
        value = poc.get(field)
        if not isinstance(value, str) or not value:
            errors.append(f"pocLaunch.{field} must be a relative path.")
            continue
        try:
            path = repo_path(root, value)
        except ValueError as exc:
            errors.append(str(exc))
            continue
        if not path.exists():
            errors.append(f"pocLaunch.{field} does not exist: {value}.")

    compose_file = poc.get("composeFile")
    if isinstance(compose_file, str):
        path = repo_path(root, compose_file)
        if path.exists():
            errors.extend(validate_compose_contract(path.read_text(encoding="utf-8")))

    dockerfile = poc.get("dockerfile")
    if isinstance(dockerfile, str):
        path = repo_path(root, dockerfile)
        if path.exists():
            errors.extend(validate_dockerfile_contract(path.read_text(encoding="utf-8")))

    raw_contract = json.dumps(contract, ensure_ascii=False)
    if "Codex #2" in raw_contract or "Codex #3" in raw_contract:
        errors.append("contract must not assign active work to Codex #2 or Codex #3.")

    return errors


def direct_smoke(root: Path, contract: dict[str, Any]) -> list[str]:
    poc = contract.get("pocLaunch", {})
    if not isinstance(poc, dict):
        return ["pocLaunch must be valid before direct smoke."]
    fixture = repo_path(root, str(poc.get("fixtureInput", "")))
    server = root / "tools" / "mcp-container-isolation" / "mcp_stdio_ping.py"
    if not fixture.exists() or not server.exists():
        return ["direct smoke fixture or server is missing."]

    proc = subprocess.run(
        [sys.executable, str(server)],
        input=fixture.read_text(encoding="utf-8"),
        text=True,
        cwd=root,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        return [f"direct stdio smoke failed with exit {proc.returncode}: {proc.stderr.strip()}"]

    responses: list[dict[str, Any]] = []
    for line in proc.stdout.splitlines():
        try:
            responses.append(json.loads(line))
        except json.JSONDecodeError as exc:
            return [f"direct stdio smoke emitted invalid JSON: {exc}"]

    tools_response = next((item for item in responses if item.get("id") == "tools"), None)
    if not tools_response:
        return ["direct stdio smoke did not return a tools/list response."]
    tools = tools_response.get("result", {}).get("tools", [])
    tool_names = {item.get("name") for item in tools if isinstance(item, dict)}
    if "echo.ping" not in tool_names:
        return ["direct stdio smoke did not expose echo.ping."]

    call_response = next((item for item in responses if item.get("id") == "call"), None)
    content = call_response.get("result", {}).get("content", []) if isinstance(call_response, dict) else []
    texts = [str(item.get("text", "")) for item in content if isinstance(item, dict)]
    if not any("container-isolated" in text for text in texts):
        return ["direct stdio smoke did not echo the container-isolated payload."]
    return []


def docker_smoke(root: Path, contract: dict[str, Any], *, require_docker: bool) -> tuple[list[str], list[str]]:
    docker = shutil.which("docker")
    if docker is None:
        message = "docker command is not available; Docker launch smoke skipped locally."
        return ([message] if require_docker else []), ([] if require_docker else [message])

    poc = contract.get("pocLaunch", {})
    if not isinstance(poc, dict):
        return (["pocLaunch must be valid before Docker smoke."], [])

    compose = repo_path(root, str(poc.get("composeFile", "")))
    fixture = repo_path(root, str(poc.get("fixtureInput", "")))
    compose_args = [docker, "compose", "-f", str(compose)]

    build = subprocess.run(
        [*compose_args, "build"],
        cwd=compose.parent,
        text=True,
        capture_output=True,
        check=False,
    )
    if build.returncode != 0:
        return ([f"Docker compose build failed with exit {build.returncode}: {build.stderr.strip()}"], [])

    run = subprocess.run(
        [*compose_args, "run", "--rm", "-T", "mcp-low-risk-poc"],
        cwd=compose.parent,
        input=fixture.read_text(encoding="utf-8"),
        text=True,
        capture_output=True,
        check=False,
    )
    if run.returncode != 0:
        return ([f"Docker compose run failed with exit {run.returncode}: {run.stderr.strip()}"], [])
    if "container-isolated" not in run.stdout:
        return (["Docker compose run did not echo the container-isolated payload."], [])
    return ([], ["Docker launch smoke passed."])


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--skip-direct-smoke", action="store_true")
    parser.add_argument("--run-docker", action="store_true")
    parser.add_argument("--require-docker", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    args = parse_args(argv)
    root = REPO_ROOT
    contract = load_json(args.config)
    errors = validate_contract(root, contract)
    warnings: list[str] = []

    if not args.skip_direct_smoke:
        errors.extend(direct_smoke(root, contract))

    if args.run_docker:
        docker_errors, docker_warnings = docker_smoke(root, contract, require_docker=args.require_docker)
        errors.extend(docker_errors)
        warnings.extend(docker_warnings)

    report = {
        "config": str(args.config),
        "valid": not errors,
        "warnings": warnings,
        "errors": errors,
    }
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print("MCP container isolation: " + ("PASS" if not errors else "FAIL"))
        for warning in warnings:
            print(f"warning: {warning}")
        for error in errors:
            print(f"error: {error}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
