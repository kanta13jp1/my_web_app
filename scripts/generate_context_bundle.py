#!/usr/bin/env python3
"""Build a revision-labelled six-file context bundle without claiming test passes."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

INPUTS = ("README.md", "project_tree.txt", "TEST_COVERAGE.md",
          "pubspec.yaml", "USER_MANUAL.md", "DETAILED_DESIGN.md")


BEGIN = "<!-- generated-ci-evidence:begin -->"
END = "<!-- generated-ci-evidence:end -->"


def render_coverage(original, revision, evidence):
    if original.count(BEGIN) != original.count(END) or original.count(BEGIN) > 1:
        raise ValueError("Ambiguous generated coverage markers")
    if BEGIN in original:
        start, end = original.index(BEGIN), original.index(END)
        if end < start:
            raise ValueError("Reversed generated coverage markers")
        original = original[:start] + original[end + len(END):]
    lines = [BEGIN, "## Generated CI evidence", "",
             f"Source revision: {revision}", ""]
    if evidence is None:
        lines.append("Unverified: no matching completed CI evidence supplied.")
    else:
        lines.extend([f"Run ID: {evidence['id']}",
                      f"Workflow conclusion: {evidence['conclusion']}",
                      "Workflow success alone does not mean every test ran.", "",
                      "| Test step | Reported outcome |", "| --- | --- |"])
        steps = evidence.get("test_steps", {})
        for name in ("flutter_test", "flutter_web_test", "deno_test"):
            lines.append(f"| {name} | {steps.get(name, 'not reported')} |")
    lines.extend(["", END])
    return original.rstrip("\n") + "\n\n" + "\n".join(lines) + "\n"


def build_bundle(contents, tracked_paths, revision, test_run=None):
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("A full source revision is required")
    missing = [name for name in INPUTS if name not in contents]
    if missing:
        raise ValueError("Missing required inputs: " + ", ".join(missing))
    files = dict(contents)
    files["project_tree.txt"] = "\n".join(sorted(set(tracked_paths))) + "\n"
    provenance = {"source_revision": revision, "test_run": None, "inputs": {}}
    if test_run is not None:
        if test_run.get("head_sha") != revision:
            raise ValueError("Test evidence revision does not match source")
        if test_run.get("status") != "completed":
            raise ValueError("Test evidence is not completed")
        if test_run.get("conclusion") not in ("success", "failure", "cancelled", "timed_out"):
            raise ValueError("Unknown test conclusion")
        if (not isinstance(test_run.get("id"), int) or isinstance(test_run["id"], bool)
                or test_run["id"] <= 0):
            raise ValueError("A numeric run ID is required")
        provenance["test_run"] = {key: test_run[key] for key in
                                  ("id", "head_sha", "status", "conclusion")}
        steps = test_run.get("test_steps", {})
        allowed_steps = {"flutter_test", "flutter_web_test", "deno_test"}
        allowed_outcomes = {"success", "failure", "cancelled", "skipped"}
        if (not isinstance(steps, dict) or not set(steps).issubset(allowed_steps)
                or any(value not in allowed_outcomes for value in steps.values())):
            raise ValueError("Invalid test-step outcomes")
        provenance["test_run"]["test_steps"] = dict(steps)
    files["TEST_COVERAGE.md"] = render_coverage(
        contents["TEST_COVERAGE.md"], revision, provenance["test_run"])
    lines = ["# AI context snapshot", "", f"Source revision: {revision}", "",
             "TEST_COVERAGE.md is preserved source documentation, not proof of "
             "current test execution.",
             "Test run: " + (json.dumps(provenance["test_run"], sort_keys=True)
                            if test_run else "unverified; no run evidence supplied"), ""]
    for name in INPUTS:
        text = files[name]
        provenance["inputs"][name] = {
            "sha256": hashlib.sha256(text.encode("utf-8")).hexdigest(),
            "generated": name in ("project_tree.txt", "TEST_COVERAGE.md"),
        }
        lines.extend([f"## {name}", "", text, ""])
    return files["project_tree.txt"], "\n".join(lines), provenance


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--test-run-json", type=Path,
                        help="Completed CI evidence for this exact checked-out SHA")
    args = parser.parse_args()
    root = Path(subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"], text=True).strip())
    output = args.output_dir.resolve()
    if output == root or not output.is_relative_to(root / ".ci-logs"):
        parser.error("Output must be a subdirectory of .ci-logs")
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
    # Read committed blobs, never dirty working files or untracked private files.
    paths = subprocess.check_output(
        ["git", "ls-tree", "-r", "--name-only", "-z", revision], cwd=root
    ).decode("utf-8").rstrip("\0").split("\0")
    contents = {name: subprocess.check_output(
        ["git", "show", f"{revision}:{name}"], cwd=root
    ).decode("utf-8") for name in INPUTS}
    evidence = (json.loads(args.test_run_json.read_text(encoding="utf-8"))
                if args.test_run_json else None)
    tree, bundle, metadata = build_bundle(contents, paths, revision, evidence)
    output.mkdir(parents=True, exist_ok=True)
    (output / "project_tree.txt").write_text(tree, encoding="utf-8")
    (output / "context.md").write_text(bundle, encoding="utf-8")
    (output / "TEST_COVERAGE.md").write_text(
        render_coverage(contents["TEST_COVERAGE.md"], revision, metadata["test_run"]),
        encoding="utf-8")
    (output / "manifest.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
