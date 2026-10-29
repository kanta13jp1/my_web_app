#!/usr/bin/env python3
"""Narrow PR5925 release handoff; no other scope is accepted."""
from __future__ import annotations

import argparse
import json
import os
import secrets
import subprocess
import sys
import urllib.request
from pathlib import Path

REPO = "kanta13jp1/my_web_app"
API = "repos/" + REPO
BRANCH = "codex/approved-5925-calendar-opid-release"
HEAD = "25b07d270cf1874149561630cebea3d9a8c0efed"
TREE = "510d0ead0b6830975cf2d3e3bf86c58ea0060626"
PARENT = "9bdb9933a16cb9b8dce517c2bf7c61fafc5969e6"
BASE = "237d9290183c3bb3df73388ec9cf4563bb0186ef"
MERGE = "fa105154b7a09c291fd739d3ae1245cebb90069d"
WORKFLOW = "cloud-development.yml"
CHANGED = {
    ".github/workflows/cloud-development.yml": "b275af0aadb803296064528a16f65a29dbc668aa",
    "lib/models/asset_calendar_reflection.dart": "431d6730e832695e536690a8e1d4499c1da86f32",
    "test/models/asset_calendar_reflection_test.dart": "f0dafa73fb05e8ea79baa30a0f42212b5e1144ed",
    "test/e2e/asset_calendar_projection_test.dart": "9ef6ce7f2f83697d4583d6b40aaa03901b3d3c19",
}
SLOT = r"C:\Users\kanta\GitHub\company\scripts\heavy-work-slot.ps1"
TASK = "codex-5925-release-handoff"
URL = "https://my-web-app-b67f4.web.app/version.json"


class Blocked(RuntimeError):
    pass


def command(args, *, data=None):
    try:
        proc = subprocess.run(args, input=None if data is None else json.dumps(data),
            text=True, encoding="utf-8", errors="replace", stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, timeout=30, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise Blocked("command outcome unknown: " + type(exc).__name__) from exc
    return proc.returncode, proc.stdout, proc.stderr


def gh_json(path):
    code, out, _ = command(["gh", "api", path])
    if code:
        raise Blocked("GitHub read failed; status unknown")
    try:
        return json.loads(out)
    except (ValueError, TypeError) as exc:
        raise Blocked("GitHub returned invalid JSON") from exc


def check_group():
    code, out, _ = command(["gh", "api", "-i", API + "/actions/concurrency_groups/deploy-prod"])
    first = out.splitlines()[0] if out else ""
    if first.startswith("HTTP/") and " 404 " in first:
        return
    if code or not first.startswith("HTTP/") or " 200 " not in first:
        raise Blocked("deploy-prod group state unknown")
    try:
        body = json.loads(out[out.index("{"):])
        if body["total_count"] != 0 or body["group_members"] != []:
            raise Blocked("deploy-prod group is active or queued")
    except (ValueError, KeyError, TypeError) as exc:
        raise Blocked("deploy-prod group response invalid") from exc


def check_remote():
    wf = gh_json(API + "/actions/workflows/" + WORKFLOW)
    if wf.get("state") != "active" or wf.get("path") != ".github/workflows/" + WORKFLOW:
        raise Blocked("workflow unavailable or unexpected")
    branch = gh_json(API + "/branches/" + BRANCH)
    if branch.get("protected") is not False or branch.get("commit", {}).get("sha") != HEAD:
        raise Blocked("branch protected, unknown, or moved")
    if gh_json(API + "/rules/branches/" + BRANCH) != []:
        raise Blocked("branch rules present or unknown")
    obj = gh_json(API + "/git/commits/" + HEAD)
    if obj.get("tree", {}).get("sha") != TREE or [p.get("sha") for p in obj.get("parents", [])] != [PARENT]:
        raise Blocked("candidate commit/tree/parent mismatch")
    cmp = gh_json(API + "/compare/" + BASE + "..." + HEAD)
    files = cmp.get("files")
    if not isinstance(files, list) or {f.get("filename"): f.get("sha") for f in files} != CHANGED:
        raise Blocked("candidate release file set or blob mismatch")
    pr = gh_json(API + "/pulls/5925")
    if pr.get("merged") is not True or pr.get("merge_commit_sha") != MERGE:
        raise Blocked("PR5925 merge evidence mismatch")
    code, out, _ = command(["gh", "variable", "get", "PRODUCTION_DEPLOY_HOLD", "--repo", REPO])
    if code or out.strip() != "false":
        raise Blocked("production hold active or unknown")
    try:
        req = urllib.request.Request(URL, headers={"Cache-Control": "no-cache"})
        with urllib.request.urlopen(req, timeout=15) as response:
            if response.status != 200 or json.load(response).get("commit") != BASE:
                raise Blocked("live production base changed")
    except (OSError, ValueError, TypeError) as exc:
        raise Blocked("live production base unknown") from exc
    runs = gh_json(API + "/actions/workflows/" + WORKFLOW + "/runs?branch=" + BRANCH + "&event=workflow_dispatch&per_page=100")
    items = runs.get("workflow_runs")
    if not isinstance(items, list) or runs.get("total_count") != len(items):
        raise Blocked("same-branch run inventory incomplete")
    if any(r.get("status") != "completed" for r in items):
        raise Blocked("same-branch run active, queued, or unknown")
    check_group()


def slot(action, token=None):
    args = ["powershell", "-NoProfile", "-File", SLOT, "-Action", action, "-TaskId", TASK]
    if action == "request":
        args += ["-Stage", "PR5925 release dispatch"]
    if token is not None:
        args += ["-Token", token]
        if action == "release":
            args += ["-WorkStopped"]
    code, out, _ = command(args)
    if code:
        raise Blocked("shared FIFO operation failed or unknown: " + action)
    try:
        parsed = json.loads(out)
        if not isinstance(parsed, dict):
            raise ValueError("not object")
        return parsed
    except ValueError as exc:
        raise Blocked("shared FIFO response invalid") from exc


def journal_create(path, operation_id):
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {"operation_id": operation_id, "head": HEAD, "status": "pending_or_unknown"}
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(payload, f, sort_keys=True)
        f.flush()
        os.fsync(f.fileno())


def identify_run(run_id, operation_id):
    run = gh_json(API + "/actions/runs/" + str(run_id))
    if (run.get("id") != run_id or run.get("head_sha") != HEAD
            or run.get("head_branch") != BRANCH or run.get("event") != "workflow_dispatch"
            or run.get("display_title") != "PR5925 release operation " + operation_id):
        raise Blocked("returned run identity does not match; do not retry")
    return run


def do_execute(journal):
    if journal.exists():
        raise Blocked("existing release journal; reconcile it before any new operation")
    queued = slot("request")
    if queued.get("result") != "queued":
        raise Blocked("FIFO request outcome unknown")
    acquired = slot("acquire")
    if acquired.get("result") != "acquired":
        raise Blocked("FIFO not acquired; request remains in queue")
    owner = acquired.get("state", {}).get("owner") or {}
    token = owner.get("token")
    if owner.get("task") != TASK or not isinstance(token, str) or not token:
        raise Blocked("FIFO ownership/token unknown; do not release or dispatch")
    try:
        check_remote()
        renewed = slot("renew", token)
        renewed_owner = renewed.get("state", {}).get("owner") or {}
        if renewed.get("result") != "renewed" or renewed_owner.get("task") != TASK or renewed_owner.get("token") != token:
            raise Blocked("FIFO renewal/ownership unconfirmed")
        operation_id = secrets.token_hex(16)
        journal_create(journal, operation_id)
        data = {"ref": BRANCH, "return_run_details": True, "inputs": {
            "operation_id": operation_id, "approved_release": True,
            "deploy_scope": "web_only", "expected_head_sha": HEAD, "profile": "full"}}
        code, out, _ = command(["gh", "api", "--method", "POST",
            API + "/actions/workflows/" + WORKFLOW + "/dispatches", "--input", "-"], data=data)
        if code:
            raise Blocked("dispatch outcome unknown; journal retained; do not retry")
        try:
            payload = json.loads(out)
            run_id = payload["workflow_run_id"]
            if isinstance(run_id, bool) or not isinstance(run_id, int) or run_id <= 0:
                raise ValueError("run ID")
        except (ValueError, KeyError, TypeError) as exc:
            raise Blocked("dispatch response unknown; journal retained; do not retry") from exc
        run = identify_run(run_id, operation_id)
        print(json.dumps({"status": "dispatched", "run_id": run_id,
                          "url": run.get("html_url"), "operation_id": operation_id}))
        return 0
    finally:
        released = slot("release", token)
        if released.get("result") != "released":
            raise Blocked("shared FIFO release unconfirmed")


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args(argv)
    try:
        if not args.execute:
            check_remote()
            print("Remote preflight passed; no FIFO acquired and no dispatch sent.")
            return 0
        local = os.environ.get("LOCALAPPDATA")
        if not local:
            raise Blocked("LOCALAPPDATA unavailable; cannot persist journal")
        return do_execute(Path(local) / "Codex" / "release-5925" / "pending.json")
    except (Blocked, OSError) as exc:
        print("PR5925 release blocked: " + str(exc), file=sys.stderr)
        return 2
