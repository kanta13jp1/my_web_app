#!/usr/bin/env python3
"""Deterministic multi-root workspace spec validator, renderer, and parity checker (#2695)."""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path
from typing import Any


SPEC_REL = "config/multiroot_workspace_spec.json"
REQUIRED_ROOT_PATHS = {".", "lib", "test", "supabase"}
REQUIRED_IGNORE_MARKERS = {".env", ".env.*", ".dart_tool/", "build/"}


def _read_json(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return data


def validate_spec(spec: dict[str, Any], repo_root: Path) -> list[str]:
    """Validate workspace specification completeness and repo directory parity."""
    violations: list[str] = []

    folders = spec.get("folders")
    if not isinstance(folders, list) or not folders:
        violations.append("spec.folders must be a non-empty list")
        folder_paths: set[str] = set()
    else:
        folder_paths = set()
        for entry in folders:
            if not isinstance(entry, dict):
                violations.append("each folder entry must be a JSON object")
                continue
            rel = str(entry.get("path") or "").strip()
            name = str(entry.get("name") or "").strip()
            if not name or not rel:
                violations.append("folder entry must include non-empty name and path")
                continue
            if ".." in Path(rel).parts or Path(rel).is_absolute():
                violations.append(f"folder path must be workspace-relative without '..': {rel!r}")
                continue
            folder_paths.add(rel)
            if not (repo_root / rel).exists():
                violations.append(f"configured workspace folder does not exist: {rel}")

        missing_roots = sorted(REQUIRED_ROOT_PATHS - folder_paths)
        if missing_roots:
            violations.append(f"spec.folders missing required cross-stack roots: {missing_roots}")

    settings = spec.get("settings")
    if not isinstance(settings, dict):
        violations.append("spec.settings must be a JSON object")
    else:
        if settings.get("deno.enable") is not True:
            violations.append("spec.settings must enable deno.enable=true for Supabase Edge Functions")
        if settings.get("deno.config") != "supabase/functions/deno.json":
            violations.append("spec.settings.deno.config must point to supabase/functions/deno.json")
        if settings.get("dart.mcpServer") is not True:
            violations.append("spec.settings.dart.mcpServer must be true for Flutter cross-stack tooling")

    ignore_patterns = spec.get("cursorignore_patterns")
    if not isinstance(ignore_patterns, list):
        violations.append("spec.cursorignore_patterns must be a list")
    else:
        ignore_set = {str(item).strip() for item in ignore_patterns}
        missing_ignores = sorted(REQUIRED_IGNORE_MARKERS - ignore_set)
        if missing_ignores:
            violations.append(f"spec.cursorignore_patterns missing safety boundaries: {missing_ignores}")

    rule = spec.get("cross_stack_rule")
    if not isinstance(rule, dict):
        violations.append("spec.cross_stack_rule must be a JSON object")
    else:
        globs = rule.get("globs")
        guidelines = rule.get("guidelines")
        if not isinstance(globs, list) or not any("lib/" in str(g) for g in globs) or not any(
            "supabase/" in str(g) for g in globs
        ):
            violations.append("spec.cross_stack_rule.globs must cover both lib/ and supabase/")
        if not isinstance(guidelines, list) or len(guidelines) < 3:
            violations.append("spec.cross_stack_rule.guidelines must include at least 3 concrete rules")

    return violations


def render_code_workspace(spec: dict[str, Any]) -> str:
    payload = {
        "folders": spec["folders"],
        "settings": spec["settings"],
        "extensions": spec["extensions"],
    }
    return json.dumps(payload, ensure_ascii=False, indent=2) + "\n"


def render_cursorignore(spec: dict[str, Any]) -> str:
    lines = [str(line) for line in spec["cursorignore_patterns"]]
    return "\n".join(lines).rstrip() + "\n"


def render_cross_stack_mdc(spec: dict[str, Any]) -> str:
    rule = spec["cross_stack_rule"]
    globs = ", ".join(str(g) for g in rule["globs"])
    always_apply = "true" if rule.get("alwaysApply") else "false"
    lines = [
        "---",
        f"description: {rule['description']}",
        f"globs: {globs}",
        f"alwaysApply: {always_apply}",
        "---",
        "",
        "# Flutter Web + Supabase Cross-Stack Rules (#2695)",
        "",
    ]
    for item in rule["guidelines"]:
        lines.append(f"- {item}")
    return "\n".join(lines) + "\n"


def inspect_workspace_readiness(
    repo_root: Path,
    *,
    require_generated: bool = False,
) -> dict[str, Any]:
    """Validate workspace spec, VS Code parity, AI review gate allowlist, and optional emitted files."""
    violations: list[str] = []
    spec_path = repo_root / SPEC_REL
    if not spec_path.exists():
        return {
            "issue": 2695,
            "ok": False,
            "require_generated": require_generated,
            "violations": [f"{SPEC_REL} missing"],
            "rendered_files": [],
        }

    spec = _read_json(spec_path)
    violations.extend(validate_spec(spec, repo_root))

    vscode_ext_path = repo_root / ".vscode" / "extensions.json"
    if vscode_ext_path.exists():
        vscode_ext = _read_json(vscode_ext_path)
        expected_recs = set(vscode_ext.get("recommendations", []))
        actual_recs = set(spec.get("extensions", {}).get("recommendations", []))
        missing_recs = sorted(expected_recs - actual_recs)
        if missing_recs:
            violations.append(f"spec.extensions missing .vscode recommendations: {missing_recs}")

    gate_path = repo_root / "scripts" / "ai_review_gate.py"
    if gate_path.exists():
        gate_text = gate_path.read_text(encoding="utf-8-sig")
        for entry_name in (".code-workspace", ".mdc", ".cursorignore"):
            if entry_name not in gate_text:
                violations.append(f"scripts/ai_review_gate.py missing allowlist entry `{entry_name}`")

    rendered: dict[str, str] = {}
    if not violations or spec.get("folders"):
        rendered = {
            str(spec.get("workspace_file", "my_web_app.code-workspace")): render_code_workspace(spec),
            str(spec.get("cursorignore_file", ".cursorignore")): render_cursorignore(spec),
            str(spec.get("rule_file", ".cursor/rules/flutter_supabase_cross_stack.mdc")): render_cross_stack_mdc(spec),
        }

    if require_generated:
        for rel, expected_text in rendered.items():
            target = repo_root / rel
            if not target.exists():
                violations.append(f"generated artifact missing: {rel}")
                continue
            raw = target.read_bytes()
            if raw.startswith(b"\xef\xbb\xbf"):
                violations.append(f"{rel} must not contain UTF-8 BOM")
            if b"\r\n" in raw:
                violations.append(f"{rel} must use LF line endings")
            actual_text = raw.decode("utf-8", errors="replace")
            if actual_text != expected_text:
                violations.append(f"{rel} differs from deterministic render of {SPEC_REL}")

    return {
        "issue": 2695,
        "ok": len(violations) == 0,
        "require_generated": require_generated,
        "violations": violations,
        "rendered_files": sorted(rendered.keys()),
    }


def write_generated_artifacts(repo_root: Path) -> list[str]:
    spec = _read_json(repo_root / SPEC_REL)
    violations = validate_spec(spec, repo_root)
    if violations:
        raise ValueError(f"cannot write invalid workspace spec: {violations}")
    outputs = {
        str(spec["workspace_file"]): render_code_workspace(spec),
        str(spec["cursorignore_file"]): render_cursorignore(spec),
        str(spec["rule_file"]): render_cross_stack_mdc(spec),
    }
    written: list[str] = []
    for rel, content in outputs.items():
        target = repo_root / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8", newline="\n")
        written.append(rel)
    return written


def run_self_test(repo_root: Path) -> dict[str, Any]:
    readiness = inspect_workspace_readiness(repo_root, require_generated=False)
    if not readiness["ok"]:
        raise RuntimeError(f"workspace spec readiness failed: {readiness['violations']}")

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        for folder in ("lib", "test", "supabase", "scripts", ".vscode"):
            (tmp / folder).mkdir(parents=True, exist_ok=True)
        for rel in (
            SPEC_REL,
            ".vscode/extensions.json",
            "scripts/ai_review_gate.py",
        ):
            src = repo_root / rel
            if src.exists():
                dst = tmp / rel
                dst.parent.mkdir(parents=True, exist_ok=True)
                dst.write_bytes(src.read_bytes())

        written = write_generated_artifacts(tmp)
        assert len(written) == 3
        check_ok = inspect_workspace_readiness(tmp, require_generated=True)
        assert check_ok["ok"] is True, check_ok["violations"]

        # Detect drift when emitted file is modified manually
        ci_target = tmp / ".cursorignore"
        ci_target.write_text("# drifted\n", encoding="utf-8", newline="\n")
        check_drift = inspect_workspace_readiness(tmp, require_generated=True)
        assert check_drift["ok"] is False

    return {"self_test": "passed", "rendered_files": readiness["rendered_files"], "checks": 3}


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check-spec", action="store_true", default=False)
    mode.add_argument("--check-generated", action="store_true", default=False)
    mode.add_argument("--write", action="store_true", default=False)
    parser.add_argument("--dry-run", action="store_true", default=False)
    parser.add_argument("--self-test", action="store_true", default=False)
    parser.add_argument("--json-out", type=Path, default=None)
    parser.add_argument("--markdown-out", type=Path, default=None)
    parser.add_argument("--github-output", type=Path, default=None)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    root = args.repo_root.resolve()

    if args.self_test:
        print(json.dumps(run_self_test(root), ensure_ascii=False))
        return 0

    if args.write:
        written = write_generated_artifacts(root)
        print(f"Generated workspace files: {', '.join(written)}")
        return 0

    result = inspect_workspace_readiness(root, require_generated=args.check_generated)
    lines = [
        "### Multi-Root Workspace Readiness (#2695)",
        f"- OK: `{result['ok']}` | Require Generated: `{result['require_generated']}`",
        f"- Targets: `{', '.join(result['rendered_files'])}`",
        *[f"- Violation: {item}" for item in result["violations"]],
    ]
    md = "\n".join(lines) + "\n"
    print(md, end="")

    if args.json_out is not None:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if args.markdown_out is not None:
        args.markdown_out.parent.mkdir(parents=True, exist_ok=True)
        args.markdown_out.write_text(md, encoding="utf-8")
    if args.github_output is not None:
        args.github_output.parent.mkdir(parents=True, exist_ok=True)
        with args.github_output.open("a", encoding="utf-8") as handle:
            handle.write(f"workspace_ok={str(result['ok']).lower()}\n")

    if args.dry_run:
        return 0
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
