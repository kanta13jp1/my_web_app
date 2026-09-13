"""Validated provider accounting and idempotent, run-keyed reports (no network)."""
import argparse
import json
import os
from pathlib import Path
import re


def manifest_rows(path):
    rows = json.loads(Path(path).read_text(encoding="utf-8"))
    ids = [r["provider"] for r in rows]
    if not ids or len(ids) != len(set(ids)):
        raise ValueError("empty/duplicate provider manifest")
    for r in rows:
        if not re.fullmatch(r"[a-z0-9_]+", r["provider"]):
            raise ValueError("invalid provider id")
        if not r["url"].startswith("https://") or any(
            c in r[k] for k in ("provider", "url", "name") for c in "\t\r\n"
        ):
            raise ValueError("invalid manifest field")
    return rows


def accounting(rows, journal):
    outcomes = {}
    for line in journal.splitlines():
        provider, status = line.split("\t")
        if provider in outcomes or status not in ("succeeded", "failed", "skipped"):
            raise ValueError("duplicate or invalid outcome")
        outcomes[provider] = status
    if set(outcomes) != {r["provider"] for r in rows}:
        raise ValueError("outcomes do not match manifest")
    counts = {s: list(outcomes.values()).count(s) for s in ("succeeded", "failed", "skipped")}
    if sum(counts.values()) != len(rows):
        raise ValueError("contradictory counts")
    return {"total": len(rows), **counts, "outcomes": outcomes}


def upsert(text, key, section):
    if not re.fullmatch(r"[0-9]+", key):
        raise ValueError("invalid run key")
    start = f"<!-- ai-university-run:{key}:start -->"
    end = f"<!-- ai-university-run:{key}:end -->"
    # Fail closed on duplicate or malformed keys, including other runs.
    starts = re.findall(r"<!-- ai-university-run:(\d+):start -->", text)
    ends = re.findall(r"<!-- ai-university-run:(\d+):end -->", text)
    if len(starts) != len(set(starts)) or sorted(starts) != sorted(ends):
        raise ValueError("duplicate/malformed report run keys")
    block = f"{start}\n{section.rstrip()}\n{end}"
    if key in starts:
        a, b = text.index(start), text.index(end)
        if b < a:
            raise ValueError("reversed report markers")
        return text[:a] + block + text[b + len(end):]
    return text.rstrip() + "\n\n" + block + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("list", "validate", "report"))
    parser.add_argument("--manifest", default="scripts/ai_university_providers.json")
    parser.add_argument("--journal")
    parser.add_argument("--evidence")
    parser.add_argument("--report")
    args = parser.parse_args()
    rows = manifest_rows(args.manifest)
    if args.command == "list":
        for r in rows:
            print("\t".join(r[k] for k in ("provider", "url", "name")))
        return
    evidence = accounting(rows, Path(args.journal).read_text(encoding="utf-8"))
    key = os.environ["GITHUB_RUN_ID"]
    evidence.update(run_id=key, attempt=os.environ.get("GITHUB_RUN_ATTEMPT", "1"))
    summary = (f"ai-university-update: {evidence['succeeded']}/{evidence['total']} succeeded; "
               f"failed={evidence['failed']}; skipped={evidence['skipped']}")
    section = "## AI大学コンテンツ更新\n\n" + summary + "\n\n"
    section += "\n".join(f"- {r['provider']}: {evidence['outcomes'][r['provider']]}" for r in rows)
    if args.command == "validate":
        Path(args.evidence).write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as out:
            out.write(f"summary={summary}\nstatus={'success' if evidence['succeeded'] == evidence['total'] else 'partial'}\n")
        Path(args.evidence + ".md").write_text(section + "\n", encoding="utf-8")
    else:
        path = Path(args.report)
        old = path.read_text(encoding="utf-8") if path.exists() else "# 日次レポート\n"
        updated = upsert(old, key, section)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(updated, encoding="utf-8")


if __name__ == "__main__":
    main()
