import concurrent.futures
import csv
import json
import re
from datetime import datetime
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import yt_dlp


CHANNEL_URL = 'https://www.youtube.com/@DPFP_sub'
CHANNEL_TABS = ['shorts', 'videos', 'streams']
TABLE_PATH = Path('updated_table.tsv')
OUTPUT_PATH = Path('yt_results.json')
DISCOVERY_LIMIT = 60
MAX_WORKERS = 8
GENERIC_TAGS = {
    '国民民主党',
    'live',
    'live配信',
    'shorts',
}


def extract_video_id(url: str) -> str | None:
    if not url:
        return None

    parsed = urlparse(url)
    if parsed.hostname in {'youtu.be'}:
        return parsed.path.lstrip('/') or None
    if parsed.path == '/watch':
        return parse_qs(parsed.query).get('v', [None])[0]
    match = re.search(r'/shorts/([^/?]+)', parsed.path)
    if match:
        return match.group(1)
    return None


def load_existing_urls() -> dict[str, str]:
    if not TABLE_PATH.exists():
        return {}

    tracked: dict[str, str] = {}
    with TABLE_PATH.open('r', encoding='utf-8', newline='') as f:
        rows = list(csv.reader(f, delimiter='\t'))

    for row in rows[3:]:
        if len(row) < 2:
            continue
        url = row[1].strip()
        video_id = extract_video_id(url)
        if video_id and video_id not in tracked:
            tracked[video_id] = url
    return tracked


def discover_channel_urls() -> dict[str, str]:
    discovered: dict[str, str] = {}
    ydl_opts = {
        'quiet': True,
        'extract_flat': True,
        'skip_download': True,
        'ignoreerrors': True,
        'playlistend': DISCOVERY_LIMIT,
    }

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        for tab in CHANNEL_TABS:
            tab_url = f'{CHANNEL_URL}/{tab}'
            info = ydl.extract_info(tab_url, download=False)
            entries = (info or {}).get('entries') or []
            for entry in entries:
                if not entry:
                    continue
                video_id = entry.get('id') or extract_video_id(
                    entry.get('url') or entry.get('webpage_url') or '',
                )
                if not video_id:
                    continue
                if tab == 'shorts':
                    discovered.setdefault(
                        video_id,
                        f'https://www.youtube.com/shorts/{video_id}',
                    )
                else:
                    discovered.setdefault(
                        video_id,
                        f'https://www.youtube.com/watch?v={video_id}',
                    )
    return discovered


def classify_content_type(info: dict, requested_url: str) -> str:
    lower_url = requested_url.lower()
    if '/shorts/' in lower_url:
        return 'short'

    live_status = str(info.get('live_status') or '').lower()
    if info.get('was_live') or live_status in {'is_live', 'was_live', 'post_live'}:
        return 'live'

    return 'video'


def format_published_label(info: dict) -> str:
    upload_date = str(info.get('upload_date') or '')
    if len(upload_date) == 8 and upload_date.isdigit():
        return f'{int(upload_date[4:6])}月{int(upload_date[6:8])}日'

    timestamp = info.get('timestamp')
    if isinstance(timestamp, (int, float)):
        dt = datetime.fromtimestamp(timestamp)
        return f'{dt.month}月{dt.day}日'

    return ''


def extract_performers(title: str) -> str:
    tags = re.findall(r'#([^\s#]+)', title)
    performers = []
    for tag in tags:
        normalized = tag.strip()
        if not normalized:
            continue
        if normalized.lower() in GENERIC_TAGS:
            continue
        if normalized not in performers:
            performers.append(normalized)
    return '\n'.join(performers)


def to_int_or_blank(value: object) -> int | str:
    return value if isinstance(value, int) else ''


def fetch_channel_info() -> dict:
    ydl_opts = {
        'quiet': True,
        'extract_flat': True,
        'skip_download': True,
        'ignoreerrors': True,
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(CHANNEL_URL, download=False)

    return {
        'url': CHANNEL_URL,
        'subscribers': (info or {}).get('channel_follower_count')
        or (info or {}).get('subscriber_count')
        or '',
    }


def fetch_video_info(url: str) -> dict:
    ydl_opts = {
        'quiet': True,
        'skip_download': True,
        'ignoreerrors': True,
    }
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)

        if not info:
            return {'url': url, 'error': 'No info'}

        video_id = info.get('id') or extract_video_id(url)
        if not video_id:
            return {'url': url, 'error': 'Missing video id'}

        content_type = classify_content_type(info, url)
        return {
            'video_id': video_id,
            'url': url,
            'content_type': content_type,
            'published_label': format_published_label(info),
            'title': str(info.get('title') or ''),
            'performers': extract_performers(str(info.get('title') or '')),
            'upload_date': str(info.get('upload_date') or ''),
            'timestamp': info.get('timestamp') or '',
            'views': to_int_or_blank(info.get('view_count')),
            'likes': to_int_or_blank(info.get('like_count')),
            'comments': to_int_or_blank(info.get('comment_count')),
        }
    except Exception as exc:
        return {'url': url, 'error': str(exc)}


def build_fetch_urls() -> list[str]:
    tracked = load_existing_urls()
    discovered = discover_channel_urls()

    for video_id, url in discovered.items():
        tracked.setdefault(video_id, url)

    return list(tracked.values())


def main() -> None:
    channel = fetch_channel_info()
    video_urls = build_fetch_urls()

    videos = []
    errors = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        future_map = {
            executor.submit(fetch_video_info, url): url
            for url in video_urls
        }
        for future in concurrent.futures.as_completed(future_map):
            result = future.result()
            if result.get('error'):
                errors.append(result)
                print(f"Failed {result['url']}: {result['error']}")
                continue
            videos.append(result)
            print(f"Fetched {result['url']}")

    videos.sort(
        key=lambda item: (
            str(item.get('upload_date') or ''),
            str(item.get('video_id') or ''),
        ),
    )

    payload = {
        'generated_at': datetime.utcnow().isoformat(timespec='seconds') + 'Z',
        'channel': channel,
        'videos': videos,
        'errors': errors,
    }

    with OUTPUT_PATH.open('w', encoding='utf-8') as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)

    print(
        json.dumps(
            {
                'videos_fetched': len(videos),
                'errors': len(errors),
                'subscribers': channel.get('subscribers', ''),
            },
            ensure_ascii=False,
        ),
    )


if __name__ == '__main__':
    main()
