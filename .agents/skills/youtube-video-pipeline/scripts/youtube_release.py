#!/usr/bin/env python3
"""Confirmation-locked YouTube private upload and publication helper.

This script intentionally provides no delete command and no direct public upload.
New videos are uploaded as private. Publication requires a separate command whose
confirmation value exactly matches the target video ID.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

try:
    from google.auth.exceptions import RefreshError
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
    from googleapiclient.http import MediaFileUpload
except ImportError as exc:  # pragma: no cover - exercised by dependency check
    print(
        "Missing Google API packages. Install google-api-python-client, "
        "google-auth-oauthlib, and google-auth-httplib2.",
        file=sys.stderr,
    )
    raise SystemExit(2) from exc


MANAGE_SCOPES = ["https://www.googleapis.com/auth/youtube.force-ssl"]
DEFAULT_CLIENT_SECRET = Path.home() / ".youtube" / "client_secret.json"
DEFAULT_TOKEN = Path.home() / ".youtube" / "youtube-video-pipeline-manage.json"
CATEGORY_EDUCATION = "27"


class ReleaseError(RuntimeError):
    pass


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False, indent=2))


def normalize_handle(value: str | None) -> str:
    if not value:
        return ""
    value = value.strip().lower()
    return value if value.startswith("@") else f"@{value}"


def load_credentials(token_path: Path) -> Credentials:
    if not token_path.exists():
        raise ReleaseError(
            f"Management token not found: {token_path}. Run auth-manage after user approval."
        )
    credentials = Credentials.from_authorized_user_file(str(token_path), MANAGE_SCOPES)
    if credentials.expired and credentials.refresh_token:
        try:
            credentials.refresh(Request())
        except RefreshError as exc:
            raise ReleaseError(
                "The OAuth refresh token was rejected. Leave this token untouched and run "
                "auth-manage with a new --token-file path after user approval."
            ) from exc
    if not credentials.valid:
        raise ReleaseError("The management OAuth credentials are not valid.")
    return credentials


def youtube_client(token_path: Path) -> Any:
    return build(
        "youtube",
        "v3",
        credentials=load_credentials(token_path),
        cache_discovery=False,
    )


def authenticated_channels(youtube: Any) -> list[dict[str, Any]]:
    response = youtube.channels().list(part="id,snippet", mine=True).execute()
    return [
        {
            "id": item.get("id"),
            "title": item.get("snippet", {}).get("title"),
            "customUrl": item.get("snippet", {}).get("customUrl"),
        }
        for item in response.get("items", [])
    ]


def verify_channel(youtube: Any, expected_handle: str) -> dict[str, Any]:
    expected = normalize_handle(expected_handle)
    channels = authenticated_channels(youtube)
    matches = [
        channel
        for channel in channels
        if normalize_handle(channel.get("customUrl")) == expected
    ]
    if len(matches) != 1:
        raise ReleaseError(
            f"Authenticated channel does not uniquely match {expected_handle}. "
            f"Returned channels: {channels}"
        )
    return matches[0]


def video_details(youtube: Any, video_id: str) -> dict[str, Any]:
    response = youtube.videos().list(
        part="snippet,status,processingDetails", id=video_id
    ).execute()
    items = response.get("items", [])
    if len(items) != 1:
        raise ReleaseError(f"Video was not found or was ambiguous: {video_id}")
    return items[0]


def verify_video_ownership(video: dict[str, Any], channel: dict[str, Any]) -> None:
    video_channel = video.get("snippet", {}).get("channelId")
    if video_channel != channel.get("id"):
        raise ReleaseError(
            f"Video belongs to channel {video_channel}, not authenticated channel {channel.get('id')}."
        )


def cmd_auth_manage(args: argparse.Namespace) -> None:
    client_secret = Path(args.client_secret).expanduser().resolve()
    token_path = Path(args.token_file).expanduser().resolve()
    if not client_secret.exists():
        raise ReleaseError(f"OAuth client secret not found: {client_secret}")

    if token_path.exists():
        try:
            credentials = load_credentials(token_path)
            emit(
                {
                    "status": "AUTH_ALREADY_VALID",
                    "token_file": str(token_path),
                    "scopes": credentials.scopes,
                    "refresh_token_present": bool(credentials.refresh_token),
                }
            )
            return
        except ReleaseError as exc:
            raise ReleaseError(
                f"Existing token is not reusable: {token_path}. {exc} "
                "Choose a new --token-file path; this script will not overwrite it."
            ) from exc

    flow = InstalledAppFlow.from_client_secrets_file(str(client_secret), MANAGE_SCOPES)
    credentials = flow.run_local_server(port=0)
    token_path.parent.mkdir(parents=True, exist_ok=True)
    token_path.write_text(credentials.to_json(), encoding="utf-8")
    emit(
        {
            "status": "AUTH_COMPLETE",
            "token_file": str(token_path),
            "scopes": credentials.scopes,
            "refresh_token_present": bool(credentials.refresh_token),
        }
    )


def cmd_channel(args: argparse.Namespace) -> None:
    youtube = youtube_client(Path(args.token_file).expanduser().resolve())
    channel = verify_channel(youtube, args.expected_handle)
    emit(
        {
            "status": "CHANNEL_VERIFIED",
            "expected_handle": normalize_handle(args.expected_handle),
            "channel": channel,
        }
    )


def local_video_probe(path: Path) -> dict[str, Any]:
    try:
        result = subprocess.run(
            [
                "ffprobe",
                "-v",
                "error",
                "-show_entries",
                "format=duration,size:stream=codec_name,width,height",
                "-of",
                "json",
                str(path),
            ],
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except FileNotFoundError as exc:
        raise ReleaseError("ffprobe is required before upload.") from exc
    if result.returncode != 0:
        raise ReleaseError(f"ffprobe rejected the video: {result.stderr.strip()}")
    data = json.loads(result.stdout)
    streams = data.get("streams", [])
    video = next((item for item in streams if item.get("width")), None)
    audio = next((item for item in streams if item.get("codec_name") == "aac"), None)
    if not video or video.get("codec_name") != "h264":
        raise ReleaseError("Upload file must contain an H.264 video stream.")
    if (video.get("width"), video.get("height")) != (1920, 1080):
        raise ReleaseError("Upload file must be 1920x1080 for this workflow.")
    if not audio:
        raise ReleaseError("Upload file must contain an AAC audio stream.")
    return data


def upload_thumbnail(youtube: Any, video_id: str, path: Path) -> dict[str, Any]:
    if not path.exists():
        raise ReleaseError(f"Thumbnail not found: {path}")
    if path.stat().st_size > 2 * 1024 * 1024:
        raise ReleaseError("Thumbnail exceeds YouTube's 2 MB limit.")
    suffix = path.suffix.lower()
    mime = "image/jpeg" if suffix in (".jpg", ".jpeg") else "image/png"
    response = youtube.thumbnails().set(
        videoId=video_id,
        media_body=MediaFileUpload(str(path), mimetype=mime, resumable=False),
    ).execute()
    return {"set": bool(response.get("items")), "path": str(path)}


def wait_for_status(
    youtube: Any,
    video_id: str,
    *,
    privacy: str | None = None,
    timeout: float = 90.0,
) -> dict[str, Any]:
    deadline = time.time() + timeout
    last: dict[str, Any] | None = None
    while time.time() < deadline:
        last = video_details(youtube, video_id)
        current_privacy = last.get("status", {}).get("privacyStatus")
        upload_status = last.get("status", {}).get("uploadStatus")
        if (privacy is None or current_privacy == privacy) and upload_status in (
            "uploaded",
            "processed",
        ):
            return last
        time.sleep(3)
    raise ReleaseError(
        f"Timed out waiting for video {video_id}; last status={last.get('status') if last else None}"
    )


def cmd_upload_private(args: argparse.Namespace) -> None:
    file_path = Path(args.file).expanduser().resolve()
    if not file_path.exists():
        raise ReleaseError(f"Video file not found: {file_path}")
    if args.confirm_upload != file_path.name:
        raise ReleaseError(
            "Upload confirmation mismatch. --confirm-upload must exactly equal the MP4 filename."
        )
    if len(args.title) > 100:
        raise ReleaseError("YouTube titles must be 100 characters or fewer.")
    description_path = Path(args.description_file).expanduser().resolve()
    if not description_path.exists():
        raise ReleaseError(f"Description file not found: {description_path}")
    description = description_path.read_text(encoding="utf-8-sig")
    if len(description) > 5000:
        raise ReleaseError("YouTube descriptions must be 5000 characters or fewer.")
    local_probe = local_video_probe(file_path)

    youtube = youtube_client(Path(args.token_file).expanduser().resolve())
    channel = verify_channel(youtube, args.expected_handle)
    body = {
        "snippet": {
            "title": args.title,
            "description": description,
            "tags": [tag.strip() for tag in args.tags.split(",") if tag.strip()],
            "categoryId": args.category,
            "defaultLanguage": args.language,
            "defaultAudioLanguage": args.language,
        },
        "status": {
            "privacyStatus": "private",
            "selfDeclaredMadeForKids": False,
            "embeddable": True,
        },
    }
    media = MediaFileUpload(
        str(file_path), mimetype="video/mp4", chunksize=-1, resumable=True
    )
    request = youtube.videos().insert(
        part="snippet,status", body=body, media_body=media
    )
    response = None
    while response is None:
        try:
            progress, response = request.next_chunk()
            if progress:
                print(f"upload_progress={int(progress.progress() * 100)}%", flush=True)
        except HttpError as exc:
            if exc.resp.status in (500, 502, 503, 504):
                time.sleep(2)
                continue
            raise
    video_id = response["id"]
    thumbnail_result = None
    if args.thumbnail:
        thumbnail_result = upload_thumbnail(
            youtube, video_id, Path(args.thumbnail).expanduser().resolve()
        )
    verified = wait_for_status(youtube, video_id, privacy="private", timeout=args.timeout)
    verify_video_ownership(verified, channel)
    emit(
        {
            "status": "PRIVATE_UPLOAD_VERIFIED",
            "video_id": video_id,
            "url": f"https://youtu.be/{video_id}",
            "title": verified.get("snippet", {}).get("title"),
            "privacy_status": verified.get("status", {}).get("privacyStatus"),
            "upload_status": verified.get("status", {}).get("uploadStatus"),
            "channel": channel,
            "thumbnail": thumbnail_result,
            "local_probe": local_probe,
        }
    )


def cmd_status(args: argparse.Namespace) -> None:
    youtube = youtube_client(Path(args.token_file).expanduser().resolve())
    channel = verify_channel(youtube, args.expected_handle)
    video = video_details(youtube, args.video_id)
    verify_video_ownership(video, channel)
    emit(
        {
            "status": "VIDEO_VERIFIED",
            "video_id": video.get("id"),
            "url": f"https://youtu.be/{video.get('id')}",
            "title": video.get("snippet", {}).get("title"),
            "privacy_status": video.get("status", {}).get("privacyStatus"),
            "upload_status": video.get("status", {}).get("uploadStatus"),
            "processing_status": video.get("processingDetails", {}).get("processingStatus"),
            "channel": channel,
        }
    )


def writable_public_status(current: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {
        "privacyStatus": "public",
        "license": current.get("license", "youtube"),
        "embeddable": current.get("embeddable", True),
        "publicStatsViewable": current.get("publicStatsViewable", True),
        "selfDeclaredMadeForKids": current.get("selfDeclaredMadeForKids", False),
    }
    if "containsSyntheticMedia" in current:
        result["containsSyntheticMedia"] = current["containsSyntheticMedia"]
    return result


def cmd_publish(args: argparse.Namespace) -> None:
    if args.confirm_public != args.video_id:
        raise ReleaseError(
            "Publication confirmation mismatch. --confirm-public must exactly equal the video ID."
        )
    youtube = youtube_client(Path(args.token_file).expanduser().resolve())
    channel = verify_channel(youtube, args.expected_handle)
    current_video = video_details(youtube, args.video_id)
    verify_video_ownership(current_video, channel)
    current_status = current_video.get("status", {})
    if current_status.get("privacyStatus") != "public":
        youtube.videos().update(
            part="status",
            body={
                "id": args.video_id,
                "status": writable_public_status(current_status),
            },
        ).execute()
    verified = wait_for_status(
        youtube, args.video_id, privacy="public", timeout=args.timeout
    )
    verify_video_ownership(verified, channel)
    emit(
        {
            "status": "PUBLICATION_VERIFIED",
            "video_id": verified.get("id"),
            "url": f"https://youtu.be/{verified.get('id')}",
            "title": verified.get("snippet", {}).get("title"),
            "privacy_status": verified.get("status", {}).get("privacyStatus"),
            "upload_status": verified.get("status", {}).get("uploadStatus"),
            "processing_status": verified.get("processingDetails", {}).get("processingStatus"),
            "channel": channel,
        }
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--token-file", default=str(DEFAULT_TOKEN))
    parser.add_argument("--client-secret", default=str(DEFAULT_CLIENT_SECRET))
    sub = parser.add_subparsers(dest="command", required=True)

    auth = sub.add_parser("auth-manage", help="Run broad YouTube management OAuth")
    auth.set_defaults(func=cmd_auth_manage)

    channel = sub.add_parser("channel", help="Verify authenticated channel handle")
    channel.add_argument("--expected-handle", required=True)
    channel.set_defaults(func=cmd_channel)

    upload = sub.add_parser("upload-private", help="Upload a new private video")
    upload.add_argument("--expected-handle", required=True)
    upload.add_argument("--file", required=True)
    upload.add_argument("--thumbnail")
    upload.add_argument("--title", required=True)
    upload.add_argument("--description-file", required=True)
    upload.add_argument("--tags", default="")
    upload.add_argument("--category", default=CATEGORY_EDUCATION)
    upload.add_argument("--language", default="ja")
    upload.add_argument("--confirm-upload", required=True)
    upload.add_argument("--timeout", type=float, default=120.0)
    upload.set_defaults(func=cmd_upload_private)

    status = sub.add_parser("status", help="Verify video ownership and status")
    status.add_argument("--expected-handle", required=True)
    status.add_argument("--video-id", required=True)
    status.set_defaults(func=cmd_status)

    publish = sub.add_parser("publish", help="Publish an existing private video")
    publish.add_argument("--expected-handle", required=True)
    publish.add_argument("--video-id", required=True)
    publish.add_argument("--confirm-public", required=True)
    publish.add_argument("--timeout", type=float, default=90.0)
    publish.set_defaults(func=cmd_publish)
    return parser


def main() -> None:
    args = build_parser().parse_args()
    try:
        args.func(args)
    except (ReleaseError, HttpError) as exc:
        emit({"status": "ERROR", "error": str(exc)})
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
