#!/usr/bin/env python3
"""
Audit stale EF references in client code.

Reads DEAD_LIST from deploy-prod.yml and checks if any retired EF names
are still referenced via invoke() in lib/ or scripts/.

Exit codes:
  0 = clean (no stale refs)
  1 = stale refs detected (CI fail)
  2 = script error
"""
import os
import re
import sys


def load_dead_list(workflow_path: str) -> list[str]:
    with open(workflow_path, encoding="utf-8") as f:
        content = f.read()
    m = re.search(r"DEAD_LIST=\(\n(.*?)\n\s*\)", content, re.DOTALL)
    if not m:
        print("ERROR: DEAD_LIST not found in deploy-prod.yml", file=sys.stderr)
        sys.exit(2)
    return re.findall(r"\s+(\S+)", m.group(1))


def scan_stale_refs(dead_list: list[str], search_dirs: list[str]) -> dict[str, list[str]]:
    stale: dict[str, list[str]] = {}
    for d in search_dirs:
        for root, _dirs, files in os.walk(d):
            for fname in files:
                if not (fname.endswith(".dart") or fname.endswith(".py") or fname.endswith(".ts")):
                    continue
                path = os.path.join(root, fname)
                try:
                    fc = open(path, encoding="utf-8").read()
                except Exception:
                    continue
                for ef in dead_list:
                    patterns = [
                        f"invoke('{ef}'",
                        f'invoke("{ef}"',
                        f"/functions/v1/{ef}",
                        f"/{ef}?",
                    ]
                    for p in patterns:
                        if p in fc:
                            stale.setdefault(ef, []).append(path)
                            break
    return stale


def main() -> int:
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    workflow = os.path.join(repo_root, ".github", "workflows", "deploy-prod.yml")

    if not os.path.exists(workflow):
        print(f"ERROR: {workflow} not found", file=sys.stderr)
        return 2

    dead_list = load_dead_list(workflow)
    print(f"Loaded {len(dead_list)} retired EF names from DEAD_LIST")

    search_dirs = [
        os.path.join(repo_root, "lib"),
        os.path.join(repo_root, "scripts"),
    ]

    stale = scan_stale_refs(dead_list, search_dirs)

    if stale:
        print(f"\n[FAIL] STALE EF REFS DETECTED ({len(stale)} EF(s)):", file=sys.stderr)
        for ef, files in sorted(stale.items()):
            print(f"  [{ef}]", file=sys.stderr)
            for fp in files:
                rel = os.path.relpath(fp, repo_root)
                print(f"    {rel}", file=sys.stderr)
        print(
            "\nAction required: migrate each invoke() to the appropriate hub action.",
            file=sys.stderr,
        )
        return 1

    print(f"[OK] No stale EF references found in lib/ or scripts/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
