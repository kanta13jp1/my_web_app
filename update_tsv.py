import csv
import json
from datetime import date
from pathlib import Path
from urllib.parse import parse_qs, urlparse


RESULTS_PATH = Path('yt_results.json')
TABLE_PATH = Path('updated_table.tsv')
CHANNEL_URL = 'https://www.youtube.com/@DPFP_sub'
HEADER_LABELS = ['コメント数', '高評価数', '視聴回数']
MIN_TARGET_UPLOAD_DATE = date(2026, 3, 12)


def today_label() -> str:
    today = date.today()
    return f'{today.year}/{today.month}/{today.day}'


def load_results() -> dict:
    with RESULTS_PATH.open('r', encoding='utf-8') as f:
        return json.load(f)


def load_rows() -> list[list[str]]:
    if not TABLE_PATH.exists():
        raise FileNotFoundError(
            f'{TABLE_PATH} が見つかりません。更新対象のTSVを先に用意してください。',
        )

    with TABLE_PATH.open('r', encoding='utf-8', newline='') as f:
        return list(csv.reader(f, delimiter='\t'))


def format_subscribers(value: object) -> str:
    if not isinstance(value, int):
        return ''
    if value >= 10000:
        compact = f'{value / 10000:.2f}'.rstrip('0').rstrip('.')
        return f'{compact}万人'
    return f'{value:,}人'


def metric_to_cell(value: object) -> str:
    if isinstance(value, int):
        return str(value)
    if isinstance(value, str):
        return value
    return ''


def extract_video_id(url: str) -> str | None:
    if not url:
        return None

    parsed = urlparse(url)
    if parsed.hostname in {'youtu.be'}:
        return parsed.path.lstrip('/') or None
    if parsed.path == '/watch':
        return parse_qs(parsed.query).get('v', [None])[0]
    if '/shorts/' in parsed.path:
        return parsed.path.rsplit('/shorts/', 1)[-1].split('/', 1)[0]
    return None


def japanese_content_type(value: str) -> str:
    return {
        'short': 'ショート',
        'live': 'ライブ',
        'video': '動画',
    }.get(value, '動画')


def parse_upload_date(upload_date: str) -> date | None:
    if len(upload_date) != 8 or not upload_date.isdigit():
        return None

    return date(
        int(upload_date[:4]),
        int(upload_date[4:6]),
        int(upload_date[6:8]),
    )


def is_target_upload(upload_date: str) -> bool:
    parsed = parse_upload_date(upload_date)
    return parsed is not None and parsed >= MIN_TARGET_UPLOAD_DATE


def ensure_rows(rows: list[list[str]]) -> None:
    if len(rows) < 3:
        raise ValueError('TSV のヘッダー行が不足しています。')


def update_headers(
    rows: list[list[str]],
    snapshot_date: str,
    subscriber_label: str,
) -> bool:
    row0, row1, row2 = rows[0], rows[1], rows[2]
    replacing_existing = row2[-3:] == [snapshot_date, snapshot_date, snapshot_date]

    if replacing_existing:
        row1[-3:] = HEADER_LABELS
        row2[-3:] = [snapshot_date, snapshot_date, snapshot_date]
        if len(row0) >= 2:
            row0[-2:] = ['', subscriber_label]
        else:
            row0.extend(['', subscriber_label])
    else:
        row0.extend(['', subscriber_label])
        row1.extend(HEADER_LABELS)
        row2.extend([snapshot_date, snapshot_date, snapshot_date])

    if len(row1) > 4 and subscriber_label:
        row1[4] = subscriber_label

    return replacing_existing


def build_video_map(payload: dict) -> dict[str, dict]:
    videos = payload.get('videos') or []
    video_map: dict[str, dict] = {}
    for video in videos:
        video_id = str(video.get('video_id') or '')
        if video_id:
            video_map[video_id] = video
    return video_map


def update_data_rows(
    rows: list[list[str]],
    video_map: dict[str, dict],
    replacing_existing: bool,
) -> set[str]:
    existing_ids: set[str] = set()
    for row in rows[3:]:
        if len(row) < 2:
            continue

        url = row[1].strip()
        video_id = extract_video_id(url)
        if not video_id:
            continue

        existing_ids.add(video_id)
        stats = video_map.get(video_id, {})
        if stats.get('published_label'):
            row[3] = str(stats.get('published_label') or row[3])
        values = [
            metric_to_cell(stats.get('comments', '')),
            metric_to_cell(stats.get('likes', '')),
            metric_to_cell(stats.get('views', '')),
        ]

        if replacing_existing and len(row) >= 3:
            row[-3:] = values
        else:
            row.extend(values)

    return existing_ids


def sort_rows_by_upload_date(
    rows: list[list[str]],
    video_map: dict[str, dict],
) -> None:
    indexed_rows = list(enumerate(rows[3:]))

    def sort_key(item: tuple[int, list[str]]) -> tuple:
        original_index, row = item
        video_id = extract_video_id(row[1].strip()) if len(row) > 1 else None
        stats = video_map.get(video_id or '', {})
        upload_date = str(stats.get('upload_date') or '')
        timestamp = stats.get('timestamp')
        numeric_timestamp = timestamp if isinstance(timestamp, (int, float)) else 0
        has_date = 0 if upload_date else 1
        return (has_date, upload_date, numeric_timestamp, original_index)

    sorted_rows = [row for _, row in sorted(indexed_rows, key=sort_key)]
    for index, row in enumerate(sorted_rows, start=1):
        if row:
            row[0] = str(index)
    rows[3:] = sorted_rows


def filter_rows_to_target_range(
    rows: list[list[str]],
    video_map: dict[str, dict],
) -> None:
    filtered_rows = []
    for row in rows[3:]:
        if len(row) < 2:
            continue

        video_id = extract_video_id(row[1].strip())
        if not video_id:
            filtered_rows.append(row)
            continue

        stats = video_map.get(video_id, {})
        if is_target_upload(str(stats.get('upload_date') or '')):
            filtered_rows.append(row)

    rows[3:] = filtered_rows


def append_missing_rows(
    rows: list[list[str]],
    video_map: dict[str, dict],
    existing_ids: set[str],
) -> int:
    header_length = len(rows[2])
    metrics_before_today = max(header_length - 6 - 3, 0)
    missing_videos = [
        video
        for video_id, video in video_map.items()
        if video_id not in existing_ids
        and is_target_upload(str(video.get('upload_date') or ''))
    ]
    missing_videos.sort(
        key=lambda item: (
            str(item.get('upload_date') or ''),
            str(item.get('video_id') or ''),
        ),
    )

    next_index = len(rows) - 2
    for video in missing_videos:
        row = [
            str(next_index),
            str(video.get('url') or ''),
            japanese_content_type(str(video.get('content_type') or 'video')),
            str(video.get('published_label') or ''),
            str(video.get('title') or ''),
            str(video.get('performers') or ''),
        ]
        row.extend([''] * metrics_before_today)
        row.extend(
            [
                metric_to_cell(video.get('comments', '')),
                metric_to_cell(video.get('likes', '')),
                metric_to_cell(video.get('views', '')),
            ],
        )
        rows.append(row)
        next_index += 1

    return len(missing_videos)


def write_rows(rows: list[list[str]]) -> None:
    with TABLE_PATH.open('w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f, delimiter='\t', lineterminator='\n')
        writer.writerows(rows)


def main() -> None:
    payload = load_results()
    rows = load_rows()
    ensure_rows(rows)

    snapshot_date = today_label()
    subscriber_label = format_subscribers(
        (payload.get('channel') or {}).get('subscribers'),
    )
    video_map = build_video_map(payload)

    filter_rows_to_target_range(rows, video_map)
    replacing_existing = update_headers(rows, snapshot_date, subscriber_label)
    existing_ids = update_data_rows(rows, video_map, replacing_existing)
    new_rows = append_missing_rows(rows, video_map, existing_ids)
    sort_rows_by_upload_date(rows, video_map)
    write_rows(rows)

    action = 'updated' if replacing_existing else 'appended'
    print(
        json.dumps(
            {
                'snapshot_date': snapshot_date,
                'subscriber_label': subscriber_label,
                'mode': action,
                'rows_updated': max(len(rows) - 3, 0),
                'new_rows_added': new_rows,
            },
            ensure_ascii=False,
        ),
    )


if __name__ == '__main__':
    main()
