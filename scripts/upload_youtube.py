#!/usr/bin/env python3
"""
YouTube 動画アップロード自動化 (Win版#126・自分株式会社)

使い方:
  # 初回 OAuth 認証 (ブラウザで Google ログイン → 1回だけ)
  python scripts/upload_youtube.py --auth

  # 動画 1 本アップロード
  python scripts/upload_youtube.py upload \\
    --file videos/master_brain/output/variant_A.mp4 \\
    --title "【自分株式会社】カオスから教義へ：高速開発の教訓 (字幕付き完全版)" \\
    --description "..." \\
    --privacy unlisted

  # 5 本一括アップロード (前回 Win#125 パターン)
  python scripts/upload_youtube.py batch \\
    --manifest videos/master_brain/upload_manifest.json

OAuth セットアップ手順:
  1. https://console.cloud.google.com/ で project 作成
  2. APIs & Services → Library → "YouTube Data API v3" を Enable
  3. APIs & Services → Credentials → Create Credentials → OAuth client ID
     → Application type: Desktop app → Create
  4. JSON ダウンロード → ~/.youtube/client_secret.json として保存
  5. python scripts/upload_youtube.py --auth (ブラウザで承認)
  6. ~/.youtube/token.json が生成される (refresh token 永続化)

API クォータ (重要):
  デフォルト 10,000 units/day / 1 upload = 1600 units / 最大 6 upload/day
  → 5 動画/セッション (8000 units) は 1日 1 セッション可
  増額申請: https://support.google.com/youtube/contact/yt_api_form

依存パッケージ:
  pip install google-api-python-client google-auth-oauthlib google-auth-httplib2

Philosophy alignment: 5 (商品=ユーザー価値) + 6 (資本=時間: 5本×3min手動→0min自動)
AI Dev alignment: 1 (Auth) + 2 (Deny: privacyStatus=unlisted) + 6 (Checkpoint: resumable upload)
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

# Optional dependencies — graceful failure if not installed
try:
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
    from googleapiclient.http import MediaFileUpload
except ImportError:
    print("ERROR: Missing dependencies. Install:", file=sys.stderr)
    print("  pip install google-api-python-client google-auth-oauthlib google-auth-httplib2",
          file=sys.stderr)
    sys.exit(1)

# OAuth 2.0 scopes
SCOPES = ["https://www.googleapis.com/auth/youtube.upload"]

# Default paths (override with --client-secret / --token-file)
HOME = Path.home()
DEFAULT_CLIENT_SECRET = HOME / ".youtube" / "client_secret.json"
DEFAULT_TOKEN_FILE = HOME / ".youtube" / "token.json"

# YouTube category IDs (https://developers.google.com/youtube/v3/docs/videoCategories/list)
CATEGORY_EDUCATION = "27"
CATEGORY_SCIENCE_TECH = "28"
CATEGORY_HOWTO = "26"


def get_credentials(client_secret_path: Path, token_path: Path) -> Credentials:
    """Load existing token or run OAuth flow."""
    creds: Credentials | None = None

    if token_path.exists():
        creds = Credentials.from_authorized_user_file(str(token_path), SCOPES)

    # Refresh if expired, else run flow
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            print("[INFO] Refreshing access token...")
            creds.refresh(Request())
        else:
            if not client_secret_path.exists():
                print(f"ERROR: client_secret.json not found at {client_secret_path}",
                      file=sys.stderr)
                print("       See OAuth setup steps in this script's docstring.",
                      file=sys.stderr)
                sys.exit(1)
            print(f"[INFO] Running OAuth flow with {client_secret_path}...")
            flow = InstalledAppFlow.from_client_secrets_file(
                str(client_secret_path), SCOPES
            )
            creds = flow.run_local_server(port=0)

        # Persist token
        token_path.parent.mkdir(parents=True, exist_ok=True)
        token_path.write_text(creds.to_json(), encoding="utf-8")
        print(f"[INFO] Saved token to {token_path}")

    return creds


def upload_video(
    youtube,
    file_path: Path,
    title: str,
    description: str,
    tags: list[str] | None = None,
    category_id: str = CATEGORY_EDUCATION,
    privacy_status: str = "unlisted",
    language: str = "ja",
) -> dict[str, Any]:
    """Upload a single video. Returns response dict including video_id."""
    body = {
        "snippet": {
            "title": title[:100],  # YouTube title 100 char limit
            "description": description[:5000],  # description 5000 char limit
            "tags": tags or [],
            "categoryId": category_id,
            "defaultLanguage": language,
            "defaultAudioLanguage": language,
        },
        "status": {
            "privacyStatus": privacy_status,
            "selfDeclaredMadeForKids": False,
            "embeddable": True,
        },
    }

    media = MediaFileUpload(
        str(file_path), chunksize=-1, resumable=True, mimetype="video/mp4"
    )

    print(f"[UPLOAD] {file_path.name} ({file_path.stat().st_size / 1024 / 1024:.1f} MB)")
    request = youtube.videos().insert(part="snippet,status", body=body, media_body=media)

    response = None
    while response is None:
        try:
            status, response = request.next_chunk()
            if status:
                print(f"  progress: {int(status.progress() * 100)}%")
        except HttpError as e:
            if e.resp.status in (500, 502, 503, 504):
                print(f"  retriable error {e.resp.status}, retrying...")
                continue
            raise

    print(f"[OK] uploaded: https://youtu.be/{response['id']}")
    return response


def cmd_auth(args) -> None:
    """Run OAuth flow only (no upload)."""
    client_secret = Path(args.client_secret)
    token_file = Path(args.token_file)
    creds = get_credentials(client_secret, token_file)
    print(f"[OK] auth complete. Token: {token_file}")
    print(f"     Scopes: {creds.scopes}")
    print(f"     Refresh token: {'present' if creds.refresh_token else 'MISSING'}")


def cmd_upload(args) -> None:
    """Upload a single video."""
    creds = get_credentials(Path(args.client_secret), Path(args.token_file))
    youtube = build("youtube", "v3", credentials=creds)

    file_path = Path(args.file)
    if not file_path.exists():
        print(f"ERROR: file not found: {file_path}", file=sys.stderr)
        sys.exit(1)

    response = upload_video(
        youtube,
        file_path=file_path,
        title=args.title,
        description=args.description or "",
        tags=args.tags.split(",") if args.tags else None,
        category_id=args.category or CATEGORY_EDUCATION,
        privacy_status=args.privacy,
    )

    # Print structured output for piping
    output = {
        "video_id": response["id"],
        "url": f"https://youtu.be/{response['id']}",
        "title": response["snippet"]["title"],
        "privacy_status": response["status"]["privacyStatus"],
    }
    print()
    print(json.dumps(output, ensure_ascii=False, indent=2))


def cmd_batch(args) -> None:
    """Upload multiple videos from manifest JSON.

    Manifest format:
      [
        {"file": "videos/...mp4", "title": "...", "description": "...",
         "tags": ["a","b"], "privacy": "unlisted"},
        ...
      ]
    """
    creds = get_credentials(Path(args.client_secret), Path(args.token_file))
    youtube = build("youtube", "v3", credentials=creds)

    manifest_path = Path(args.manifest)
    items = json.loads(manifest_path.read_text(encoding="utf-8"))
    print(f"[BATCH] {len(items)} videos to upload")

    results = []
    for i, item in enumerate(items, 1):
        print(f"\n--- {i}/{len(items)}: {item.get('title', '?')[:60]}")
        try:
            response = upload_video(
                youtube,
                file_path=Path(item["file"]),
                title=item["title"],
                description=item.get("description", ""),
                tags=item.get("tags"),
                category_id=item.get("category", CATEGORY_EDUCATION),
                privacy_status=item.get("privacy", "unlisted"),
            )
            results.append({
                "file": item["file"],
                "video_id": response["id"],
                "url": f"https://youtu.be/{response['id']}",
                "title": response["snippet"]["title"],
            })
        except Exception as e:
            print(f"[ERROR] {e}", file=sys.stderr)
            results.append({"file": item["file"], "error": str(e)})

    # Save results
    output_path = manifest_path.with_suffix(".result.json")
    output_path.write_text(
        json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"\n[DONE] {len(results)} results saved to {output_path}")
    success = sum(1 for r in results if "video_id" in r)
    print(f"  success: {success}/{len(results)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--client-secret", default=str(DEFAULT_CLIENT_SECRET),
                        help="Path to OAuth client_secret.json")
    parser.add_argument("--token-file", default=str(DEFAULT_TOKEN_FILE),
                        help="Path to persisted token.json")

    sub = parser.add_subparsers(dest="cmd", required=True)

    p_auth = sub.add_parser("auth", aliases=["--auth"], help="Run OAuth flow only")
    p_auth.set_defaults(func=cmd_auth)

    p_up = sub.add_parser("upload", help="Upload one video")
    p_up.add_argument("--file", required=True)
    p_up.add_argument("--title", required=True)
    p_up.add_argument("--description", default="")
    p_up.add_argument("--tags", help="comma-separated")
    p_up.add_argument("--category", default=CATEGORY_EDUCATION)
    p_up.add_argument("--privacy", default="unlisted",
                      choices=["unlisted", "private", "public"])
    p_up.set_defaults(func=cmd_upload)

    p_batch = sub.add_parser("batch", help="Upload multiple videos from manifest JSON")
    p_batch.add_argument("--manifest", required=True)
    p_batch.set_defaults(func=cmd_batch)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
