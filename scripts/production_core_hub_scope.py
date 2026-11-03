"""Route the narrow public-blog repair and verify its anonymous HTTP contract."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import urllib.error
import urllib.parse
import urllib.request
import uuid

BLOG_PATHS = frozenset({
    "supabase/functions/core-hub/blog_view.ts",
    "supabase/functions/core-hub/blog_view_test.ts",
    "supabase/functions/core-hub/index_test.ts",
})
BLOG_SOURCE = "supabase/functions/core-hub/blog_view.ts"
PRODUCTION_CORE_URL = "https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/core-hub"


def scope(paths: list[str]) -> str:
    if not paths or any(not path or path != path.strip() for path in paths):
        raise ValueError("Missing or malformed changed-file evidence")
    names = set(paths)
    if names & BLOG_PATHS:
        if not names <= BLOG_PATHS:
            raise ValueError("Public-blog repair is mixed with unrelated changes")
        if BLOG_SOURCE not in names:
            raise ValueError("Public-blog tests without their source are not a release")
        return "core-hub"
    return "general"


def checked_paths(path: Path) -> list[str]:
    # Missing files and empty diffs fail; no permissive API fallback exists.
    return path.read_text(encoding="utf-8").splitlines()


def request(action: str, **params: object) -> tuple[int, dict]:
    url = PRODUCTION_CORE_URL + "?" + urllib.parse.urlencode({"action": action, "format": "json", **params})
    try:
        with urllib.request.urlopen(url, timeout=25) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        with error:
            return error.code, json.load(error)


def probe() -> None:
    status, payload = request("blog.public.list", limit=3)
    if status != 200 or payload.get("success") is not True:
        raise ValueError("Anonymous blog list did not return HTTP 200/success")
    posts = payload.get("posts")
    if not isinstance(posts, list) or not 1 <= len(posts) <= 3:
        raise ValueError("Anonymous blog list did not return 1-3 public posts")
    post_id = str(uuid.UUID(posts[0]["id"]))
    status, article = request("blog.public.view", id=post_id)
    if status != 200 or article.get("success") is not True or article.get("post", {}).get("id") != post_id:
        raise ValueError("Anonymous article did not return HTTP 200/matching post")
    status, missing = request("blog.public.view", id="00000000-0000-0000-0000-000000000000")
    if status != 404 or "error" not in missing:
        raise ValueError("Missing anonymous article did not return HTTP 404")
    status, memo = request("memo.public.list", limit=3)
    if status != 200 or memo.get("success") is not True:
        raise ValueError("Anonymous public memo did not return HTTP 200/success")
    # Do not log titles, bodies, identifiers, or credentials.
    print("Anonymous blog list=200, article=200, missing=404, public memo=200")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("guard", "require-core-hub", "probe"))
    parser.add_argument("--changed-files", type=Path)
    args = parser.parse_args()
    if args.mode == "probe":
        probe()
        return
    if args.changed_files is None:
        parser.error("--changed-files is required")
    selected = scope(checked_paths(args.changed_files))
    if args.mode == "require-core-hub" and selected != "core-hub":
        raise ValueError("This workflow only deploys the exact public-blog repair")
    if args.mode == "guard" and selected == "core-hub":
        raise ValueError("Public-blog repair belongs to the dedicated deployment workflow")
    print("Verified production scope: " + selected)


if __name__ == "__main__":
    main()
