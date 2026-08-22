#!/usr/bin/env python3
"""Build the bundled Japanese art-museum catalog from the official CSV."""

from __future__ import annotations

import argparse
import csv
import io
import json
import re
import urllib.request
from pathlib import Path


DEFAULT_SOURCE_URL = (
    "https://museum.bunka.go.jp/wp-content/uploads/2026/08/"
    "MuseumList_20260820.csv"
)
DEFAULT_GUIDE_URL = "https://museum.bunka.go.jp/guide/"
DEFAULT_AS_OF = "2026-08-20"
DEFAULT_OUTPUT = Path("assets/data/art_museums_japan.json")

PREFECTURES = (
    "北海道",
    "青森県",
    "岩手県",
    "宮城県",
    "秋田県",
    "山形県",
    "福島県",
    "茨城県",
    "栃木県",
    "群馬県",
    "埼玉県",
    "千葉県",
    "東京都",
    "神奈川県",
    "新潟県",
    "富山県",
    "石川県",
    "福井県",
    "山梨県",
    "長野県",
    "岐阜県",
    "静岡県",
    "愛知県",
    "三重県",
    "滋賀県",
    "京都府",
    "大阪府",
    "兵庫県",
    "奈良県",
    "和歌山県",
    "鳥取県",
    "島根県",
    "岡山県",
    "広島県",
    "山口県",
    "徳島県",
    "香川県",
    "愛媛県",
    "高知県",
    "福岡県",
    "佐賀県",
    "長崎県",
    "熊本県",
    "大分県",
    "宮崎県",
    "鹿児島県",
    "沖縄県",
)


def _clean_name(value: str) -> str:
    return re.sub(r"^[◎○〇]+", "", value.strip()).strip()


def _normalize_url(value: str) -> str:
    url = value.strip()
    if not url:
        return ""
    if url.startswith(("https://", "http://")):
        return url
    if url.startswith("www."):
        return f"https://{url}"
    return ""


def _parse_rows(raw_csv: bytes) -> list[dict[str, str]]:
    text = raw_csv.decode("utf-8-sig")
    lines = text.splitlines()
    if len(lines) < 2:
        raise ValueError("The museum CSV does not contain a header row")

    prefecture_order = {name: index for index, name in enumerate(PREFECTURES)}
    museums: list[dict[str, str]] = []
    seen: set[tuple[str, str, str]] = set()
    for row in csv.DictReader(io.StringIO("\n".join(lines[1:]))):
        if (row.get("館種") or "").strip() != "美術":
            continue
        museum = {
            "name": _clean_name(row.get("名称") or ""),
            "prefecture": (row.get("都道府県") or "").strip(),
            "municipality": (row.get("市区町村") or "").strip(),
            "registrationStatus": (row.get("登録状況") or "").strip(),
            "operator": (row.get("設置者") or "").strip(),
            "officialUrl": _normalize_url(row.get("公式HP") or ""),
        }
        if not museum["name"] or museum["prefecture"] not in prefecture_order:
            continue
        key = (museum["prefecture"], museum["municipality"], museum["name"])
        if key in seen:
            continue
        seen.add(key)
        museums.append(museum)

    museums.sort(
        key=lambda museum: (
            prefecture_order[museum["prefecture"]],
            museum["municipality"],
            museum["name"],
        )
    )
    return museums


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-url", default=DEFAULT_SOURCE_URL)
    parser.add_argument("--guide-url", default=DEFAULT_GUIDE_URL)
    parser.add_argument("--as-of", default=DEFAULT_AS_OF)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    with urllib.request.urlopen(args.source_url, timeout=60) as response:
        museums = _parse_rows(response.read())

    covered_prefectures = {museum["prefecture"] for museum in museums}
    missing = [name for name in PREFECTURES if name not in covered_prefectures]
    if missing:
        raise ValueError(f"Catalog does not cover every prefecture: {missing}")

    payload = {
        "schemaVersion": 1,
        "source": {
            "label": "文化庁 博物館総合サイト",
            "url": args.guide_url,
            "downloadUrl": args.source_url,
            "asOf": args.as_of,
        },
        "museums": museums,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        f"Wrote {len(museums)} art museums across "
        f"{len(covered_prefectures)} prefectures to {args.output}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
