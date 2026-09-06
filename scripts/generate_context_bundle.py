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
        if not isinstance(test_run.get("id"), int) or isinstance(test_run["id"], bool):
            raise ValueError("A numeric run ID is required")
        provenance["test_run"] = {key: test_run[key] for key in
                                  ("id", "head_sha", "status", "conclusion")}
    lines = ["# AI context snapshot", "", f"Source revision: {revision}", "",
             "TEST_COVERAGE.md is preserved source documentation, not proof of "
             "current test execution.",
             "Test run: " + (json.dumps(provenance["test_run"], sort_keys=True)
                            if test_run else "unverified; no run evidence supplied"), ""]
    for name in INPUTS:
        text = files[name]
        provenance["inputs"][name] = {
            "sha256": hashlib.sha256(text.encode("utf-8")).hexdigest(),
            "generated": name == "project_tree.txt",
        }
        lines.extend([f"## {name}", "", text, ""])
    return files["project_tree.txt"], "\n".join(lines), provenance


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
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
    tree, bundle, metadata = build_bundle(contents, paths, revision)
    output.mkdir(parents=True, exist_ok=True)
    (output / "project_tree.txt").write_text(tree, encoding="utf-8")
    (output / "context.md").write_text(bundle, encoding="utf-8")
    (output / "manifest.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
