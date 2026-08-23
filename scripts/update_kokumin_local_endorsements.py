"""Refresh the official Kokumin local-election endorsement snapshot.

The party publishes the list as a PDF at a stable URL.  This script turns the
PDF into a small deterministic JSON asset used by the Flutter app and the
local-election Edge Function.  It deliberately refuses suspiciously small
outputs so a PDF/parser change cannot erase a previously valid snapshot.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import sys
from collections import OrderedDict
from pathlib import Path
from typing import Iterable
from urllib.request import Request, urlopen


DEFAULT_SOURCE_URL = "https://new-kokumin.jp/local-election-list"
DEFAULT_OUTPUT = Path("assets/data/kokumin_local_endorsements.json")
DEFAULT_DART_OUTPUT = Path("lib/data/dpj_official_endorsements.dart")
USER_AGENT = (
    "my_web_app election-intelligence/1.0 "
    "(+https://my-web-app-b67f4.web.app/)"
)
MIN_OFFICIAL_ENDORSEMENTS = 30
MIN_PREFECTURES = 10
MAX_ALLOWED_DROP_RATIO = 0.25

_AS_OF_RE = re.compile(r"(\d{4})/(\d{2})/(\d{2})\s*現在")
_ROW_RE = re.compile(r"^\s*(\d+)\s*([^\s\d]+)\s+")
_CAREER_RE = re.compile(r"\s[男女]\s+\d+\s+(現|元|新)\s")


def _normalize_line(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def _short_prefecture_name(value: str) -> str:
    if value == "北海道":
        return value
    return re.sub(r"[都府県]$", "", value)


def parse_candidate_rows(page_texts: Iterable[str]) -> list[dict[str, str]]:
    """Parse one-line candidate rows emitted by pypdf's layout extractor."""

    rows: list[dict[str, str]] = []
    for page_text in page_texts:
        for line in page_text.splitlines():
            match = _ROW_RE.match(line)
            if match is None:
                continue
            if "公認" not in line and "推薦" not in line:
                continue
            career = _CAREER_RE.search(line)
            if career is None:
                raise ValueError(
                    "Candidate row did not contain a parseable 現/元/新 value: "
                    f"{_normalize_line(line)}"
                )
            rows.append(
                {
                    "prefecture": _short_prefecture_name(match.group(2)),
                    "decision": "endorsement" if "公認" in line else "recommendation",
                    "career": {
                        "現": "incumbent",
                        "元": "former",
                        "新": "newcomer",
                    }[career.group(1)],
                    "sourceRow": _normalize_line(line),
                }
            )
    return rows


def parse_source_as_of(page_texts: Iterable[str]) -> str:
    for page_text in page_texts:
        match = _AS_OF_RE.search(page_text)
        if match is not None:
            return f"{match.group(1)}-{match.group(2)}-{match.group(3)}"
    raise ValueError("The official PDF did not contain a YYYY/MM/DD現在 date.")


def build_snapshot(pdf_bytes: bytes, page_texts: list[str], source_url: str) -> dict:
    rows = parse_candidate_rows(page_texts)
    endorsements = [row for row in rows if row["decision"] == "endorsement"]
    recommendations = [row for row in rows if row["decision"] == "recommendation"]
    by_prefecture: OrderedDict[str, dict[str, int | str]] = OrderedDict()
    for row in endorsements:
        prefecture = row["prefecture"]
        entry = by_prefecture.setdefault(
            prefecture,
            {
                "prefecture": prefecture,
                "totalCount": 0,
                "incumbentCount": 0,
                "newcomerCount": 0,
                "formerCount": 0,
            },
        )
        entry["totalCount"] = int(entry["totalCount"]) + 1
        count_key = f"{row['career']}Count"
        entry[count_key] = int(entry[count_key]) + 1

    career_counts = {
        career: sum(1 for row in endorsements if row["career"] == career)
        for career in ("incumbent", "newcomer", "former")
    }
    snapshot = {
        "schemaVersion": 1,
        "electionMode": "local",
        "sourceUrl": source_url,
        "sourceAsOf": parse_source_as_of(page_texts),
        "sourceDocumentSha256": hashlib.sha256(pdf_bytes).hexdigest(),
        "candidateRowCount": len(rows),
        "officialEndorsements": {
            "totalCount": len(endorsements),
            "incumbentCount": career_counts["incumbent"],
            "newcomerCount": career_counts["newcomer"],
            "formerCount": career_counts["former"],
            "prefectureCount": len(by_prefecture),
        },
        "recommendations": {"totalCount": len(recommendations)},
        "prefectures": list(by_prefecture.values()),
    }
    validate_snapshot(snapshot)
    return snapshot


def validate_snapshot(snapshot: dict, previous: dict | None = None) -> None:
    summary = snapshot.get("officialEndorsements", {})
    total = int(summary.get("totalCount", 0))
    breakdown_total = sum(
        int(summary.get(key, 0))
        for key in ("incumbentCount", "newcomerCount", "formerCount")
    )
    prefectures = snapshot.get("prefectures", [])
    if total < MIN_OFFICIAL_ENDORSEMENTS:
        raise ValueError(
            f"Official endorsement count {total} is below the safety floor "
            f"{MIN_OFFICIAL_ENDORSEMENTS}."
        )
    if len(prefectures) < MIN_PREFECTURES:
        raise ValueError(
            f"Prefecture count {len(prefectures)} is below the safety floor "
            f"{MIN_PREFECTURES}."
        )
    if breakdown_total != total:
        raise ValueError(
            f"Career breakdown {breakdown_total} does not equal total {total}."
        )
    if int(summary.get("prefectureCount", 0)) != len(prefectures):
        raise ValueError("Prefecture summary does not match prefecture rows.")
    for row in prefectures:
        row_total = sum(
            int(row.get(key, 0))
            for key in ("incumbentCount", "newcomerCount", "formerCount")
        )
        if row_total != int(row.get("totalCount", 0)):
            raise ValueError(
                f"Career breakdown does not match for {row.get('prefecture', '')}."
            )

    if previous is not None:
        previous_total = int(
            previous.get("officialEndorsements", {}).get("totalCount", 0)
        )
        if previous_total > 0 and total < previous_total * (1 - MAX_ALLOWED_DROP_RATIO):
            raise ValueError(
                f"Official endorsement count fell from {previous_total} to {total}; "
                "refusing a drop over 25% without manual review."
            )


def download_pdf(source_url: str) -> bytes:
    request = Request(source_url, headers={"User-Agent": USER_AGENT})
    with urlopen(request, timeout=45) as response:
        pdf_bytes = response.read()
    if not pdf_bytes.startswith(b"%PDF"):
        raise ValueError("The official source did not return a PDF document.")
    return pdf_bytes


def extract_page_texts(pdf_bytes: bytes) -> list[str]:
    try:
        from pypdf import PdfReader
    except ImportError as error:
        raise RuntimeError(
            "pypdf is required; install scripts/requirements-election-intelligence.txt"
        ) from error

    reader = PdfReader(io.BytesIO(pdf_bytes))
    if not reader.pages:
        raise ValueError("The official PDF contained no pages.")
    return [page.extract_text(extraction_mode="layout") or "" for page in reader.pages]


def _read_json(path: Path) -> dict | None:
    if not path.exists():
        return None
    value = json.loads(path.read_text(encoding="utf-8"))
    return value if isinstance(value, dict) else None


def _write_json_if_changed(path: Path, snapshot: dict) -> bool:
    rendered = json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n"
    return _write_text_if_changed(
        path,
        rendered,
        unchanged_message="No change in the official endorsement snapshot.",
    )


def _write_text_if_changed(
    path: Path,
    rendered: str,
    *,
    unchanged_message: str,
) -> bool:
    previous = path.read_text(encoding="utf-8") if path.exists() else ""
    if previous == rendered:
        print(unchanged_message)
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(rendered, encoding="utf-8")
    print(f"Wrote {path}")
    return True


def _dart_string(value: object) -> str:
    escaped = (
        str(value)
        .replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("$", "\\$")
        .replace("\r", "\\r")
        .replace("\n", "\\n")
    )
    return f"'{escaped}'"


def render_dart_fallback(snapshot: dict) -> str:
    """Render the Flutter offline fallback from the canonical JSON snapshot."""

    summary = snapshot["officialEndorsements"]
    recommendations = snapshot["recommendations"]
    lines = [
        "// GENERATED FILE. DO NOT EDIT.",
        "// Generated by scripts/update_kokumin_local_endorsements.py.",
        "library;",
        "",
        "import '../models/election_intelligence.dart';",
        "",
        "const String dpjOfficialEndorsementSourceUrl =",
        f"    {_dart_string(snapshot['sourceUrl'])};",
        f"const String dpjOfficialEndorsementSourceAsOf = {_dart_string(snapshot['sourceAsOf'])};",
        "const String dpjOfficialEndorsementSourceDocumentSha256 =",
        f"    {_dart_string(snapshot['sourceDocumentSha256'])};",
        f"const int dpjOfficialRecommendationEntryCount = {int(recommendations['totalCount'])};",
        "",
        "const List<OfficialEndorsementPrefecture> dpjOfficialEndorsements =",
        "    <OfficialEndorsementPrefecture>[",
    ]
    for row in snapshot["prefectures"]:
        lines.extend(
            [
                "  OfficialEndorsementPrefecture(",
                f"    prefecture: {_dart_string(row['prefecture'])},",
                f"    totalCount: {int(row['totalCount'])},",
                f"    incumbentCount: {int(row['incumbentCount'])},",
                f"    newcomerCount: {int(row['newcomerCount'])},",
                f"    formerCount: {int(row['formerCount'])},",
                "  ),",
            ]
        )
    lines.extend(
        [
            "];",
            "",
            "const int dpjOfficialEndorsementTotal = "
            f"{int(summary['totalCount'])};",
            "const int dpjOfficialEndorsementIncumbentTotal = "
            f"{int(summary['incumbentCount'])};",
            "const int dpjOfficialEndorsementNewcomerTotal = "
            f"{int(summary['newcomerCount'])};",
            "const int dpjOfficialEndorsementFormerTotal = "
            f"{int(summary['formerCount'])};",
            "const int dpjOfficialEndorsementPrefectureCount = "
            f"{int(summary['prefectureCount'])};",
            "",
            "OfficialEndorsementPrefecture? dpjOfficialEndorsementFor(",
            "  String prefecture,",
            ") {",
            "  final normalized = prefecture.replaceFirst(",
            "    RegExp(r'[都府県]$'),",
            "    '',",
            "  );",
            "  for (final item in dpjOfficialEndorsements) {",
            "    if (item.prefecture == normalized) {",
            "      return item;",
            "    }",
            "  }",
            "  return null;",
            "}",
            "",
        ]
    )
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-url", default=DEFAULT_SOURCE_URL)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--dart-output", type=Path, default=DEFAULT_DART_OUTPUT)
    parser.add_argument("--input-pdf", type=Path)
    parser.add_argument(
        "--allow-large-drop",
        action="store_true",
        help="Allow a reviewed cycle reset that lowers the total by more than 25%.",
    )
    args = parser.parse_args(argv)

    pdf_bytes = (
        args.input_pdf.read_bytes()
        if args.input_pdf is not None
        else download_pdf(args.source_url)
    )
    page_texts = extract_page_texts(pdf_bytes)
    snapshot = build_snapshot(pdf_bytes, page_texts, args.source_url)
    previous = _read_json(args.output)
    validate_snapshot(
        snapshot,
        previous=None if args.allow_large_drop else previous,
    )
    _write_json_if_changed(args.output, snapshot)
    _write_text_if_changed(
        args.dart_output,
        render_dart_fallback(snapshot),
        unchanged_message="No change in the Flutter endorsement fallback.",
    )
    summary = snapshot["officialEndorsements"]
    print(
        "Official endorsements: "
        f"{summary['totalCount']} across {summary['prefectureCount']} prefectures; "
        f"recommendations: {snapshot['recommendations']['totalCount']}; "
        f"as of {snapshot['sourceAsOf']}."
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:  # keep workflow logs concise and actionable
        print(f"update_kokumin_local_endorsements failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
