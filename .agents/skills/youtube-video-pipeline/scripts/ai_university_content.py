#!/usr/bin/env python3
"""Generate and validate my_web_app AI大学 YouTube lesson migrations."""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import date, datetime
from pathlib import Path
from urllib.parse import parse_qs, urlparse


VIDEO_ID_RE = re.compile(r"^[A-Za-z0-9_-]{11}$")
IDENTIFIER_RE = re.compile(r"^[a-z0-9][a-z0-9_-]*$")
TIMESTAMP_RE = re.compile(r"^\d{14}$")


class ContentError(RuntimeError):
    pass


def emit(payload: dict[str, object]) -> None:
    print(json.dumps(payload, ensure_ascii=False, indent=2))


def youtube_video_id(raw_url: str) -> str:
    parsed = urlparse(raw_url.strip())
    if parsed.scheme != "https":
        raise ContentError("YouTube URL must use https.")

    host = (parsed.hostname or "").lower()
    if host.startswith("www."):
        host = host[4:]

    segments = [part for part in parsed.path.split("/") if part]
    candidate = ""
    if host == "youtu.be" and segments:
        candidate = segments[0]
    elif host in {
        "youtube.com",
        "m.youtube.com",
        "music.youtube.com",
        "youtube-nocookie.com",
    }:
        if segments and segments[0] == "watch":
            candidate = parse_qs(parsed.query).get("v", [""])[0]
        elif len(segments) >= 2 and segments[0] in {"embed", "shorts", "live"}:
            candidate = segments[1]
        else:
            candidate = parse_qs(parsed.query).get("v", [""])[0]

    if not VIDEO_ID_RE.fullmatch(candidate):
        raise ContentError(f"Could not extract a valid YouTube video ID: {raw_url}")
    return candidate


def sql_string(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def dollar_quote(value: str) -> str:
    index = 0
    while True:
        tag = "$content$" if index == 0 else f"$content{index}$"
        if tag not in value:
            return f"{tag}{value}{tag}"
        index += 1


def validate_identifier(name: str, value: str) -> str:
    normalized = value.strip().lower()
    if not IDENTIFIER_RE.fullmatch(normalized):
        raise ContentError(f"{name} must contain lowercase letters, digits, _ or -.")
    return normalized


def migration_sql(args: argparse.Namespace) -> tuple[str, str]:
    provider = validate_identifier("provider", args.provider)
    category = validate_identifier("category", args.category)
    if not category.startswith("video_"):
        raise ContentError("category must begin with video_.")

    title = args.title.strip()
    if not title:
        raise ContentError("title must not be empty.")

    content_path = Path(args.content_file).resolve()
    if not content_path.is_file():
        raise ContentError(f"Content file not found: {content_path}")
    content = content_path.read_text(encoding="utf-8").strip()
    if not content:
        raise ContentError("Content file must not be empty.")

    try:
        published_at = date.fromisoformat(args.published_at).isoformat()
    except ValueError as exc:
        raise ContentError("published-at must be YYYY-MM-DD.") from exc

    video_id = youtube_video_id(args.video_url)
    canonical_url = f"https://www.youtube.com/watch?v={video_id}"

    sql = f"""-- AI大学: YouTube 公開動画を埋め込み学習コンテンツとして登録する。

INSERT INTO ai_university_content (
  provider,
  category,
  title,
  content,
  source_url,
  published_at,
  sort_order,
  is_active
)
VALUES (
  {sql_string(provider)},
  {sql_string(category)},
  {sql_string(title)},
  {dollar_quote(content)},
  {sql_string(canonical_url)},
  {sql_string(published_at)},
  {args.sort_order},
  true
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  source_url = EXCLUDED.source_url,
  published_at = EXCLUDED.published_at,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active;
"""
    return video_id, sql


def generate(args: argparse.Namespace) -> int:
    repo = Path(args.repo).resolve()
    migrations = repo / "supabase" / "migrations"
    if not migrations.is_dir():
        raise ContentError(f"Supabase migrations directory not found: {migrations}")

    timestamp = args.timestamp or datetime.now().strftime("%Y%m%d%H%M%S")
    if not TIMESTAMP_RE.fullmatch(timestamp):
        raise ContentError("timestamp must contain exactly 14 digits.")

    category = validate_identifier("category", args.category)
    filename_slug = category.replace("_", "-")
    output = migrations / f"{timestamp}_seed_{filename_slug}_ai_university.sql"
    if output.exists() and not args.preview:
        raise ContentError(f"Migration already exists: {output}")

    video_id, sql = migration_sql(args)
    if args.preview:
        emit(
            {
                "status": "preview",
                "video_id": video_id,
                "migration_path": str(output),
                "sql": sql,
            }
        )
        return 0

    output.write_text(sql, encoding="utf-8", newline="\n")
    emit(
        {
            "status": "created",
            "video_id": video_id,
            "migration_path": str(output),
        }
    )
    return 0


def check_ui(args: argparse.Namespace) -> int:
    repo = Path(args.repo).resolve()
    checks = {
        "lib/services/ai_university_video_lesson_service.dart": [
            "youtubeVideoIdFromUrl",
            "youtubeEmbedUrl",
        ],
        "lib/widgets/ai_university_youtube_embed.dart": [
            "AiUniversityYoutubeEmbed",
            "HtmlElementView",
        ],
        "lib/widgets/ai_university_published_video_banner.dart": [
            "AiUniversityPublishedVideoBanner",
            "List<AiUniversityPublishedVideoBannerItem>",
            "公開動画で学ぶ",
            "今すぐ見る",
            "LayoutBuilder",
        ],
        "lib/widgets/ai_university_youtube_viewer_route.dart": [
            "AiUniversityYoutubeViewerRoute",
            "MaterialPageRoute",
            "showAiUniversityYoutubeViewer",
        ],
        "lib/pages/gemini_university_v2_page.dart": [
            "AiUniversityYoutubeEmbed",
            "AiUniversityPublishedVideoBanner",
            "showAiUniversityYoutubeViewer",
            "_buildPublishedVideoBanner",
            "for (final topic in topics)",
            "AI動画レッスンを生成",
        ],
        "lib/pages/ai_university_video_page.dart": [
            "AiUniversityYoutubeEmbed",
        ],
    }
    missing: dict[str, list[str]] = {}
    for relative, needles in checks.items():
        path = repo / relative
        if not path.is_file():
            missing[relative] = ["<file>"]
            continue
        source = path.read_text(encoding="utf-8")
        absent = [needle for needle in needles if needle not in source]
        if absent:
            missing[relative] = absent

    emit(
        {
            "status": "ok" if not missing else "missing",
            "repo": str(repo),
            "missing": missing,
        }
    )
    return 0 if not missing else 1


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(
        description="Generate or validate AI大学 YouTube lesson integration."
    )
    commands = root.add_subparsers(dest="command", required=True)

    check = commands.add_parser("check-ui", help="Check reusable embed UI contract.")
    check.add_argument("--repo", required=True)
    check.set_defaults(handler=check_ui)

    create = commands.add_parser("generate", help="Generate an idempotent lesson migration.")
    create.add_argument("--repo", required=True)
    create.add_argument("--provider", required=True)
    create.add_argument("--category", required=True)
    create.add_argument("--title", required=True)
    create.add_argument("--content-file", required=True)
    create.add_argument("--video-url", required=True)
    create.add_argument("--published-at", required=True)
    create.add_argument("--sort-order", type=int, default=0)
    create.add_argument("--timestamp")
    create.add_argument("--preview", action="store_true")
    create.set_defaults(handler=generate)
    return root


def main() -> int:
    args = parser().parse_args()
    try:
        return int(args.handler(args))
    except ContentError as exc:
        emit({"status": "error", "message": str(exc)})
        return 2


if __name__ == "__main__":
    sys.exit(main())
