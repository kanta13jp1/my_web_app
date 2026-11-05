"""Audit PDF date evidence without assigning candidates to an election.

This is an offline review artifact. A printed date is never promoted to a
confirmed voting date by this script, even when it is outside parentheses.
"""
from __future__ import annotations

import argparse
from datetime import date
import hashlib
import io
import json
from pathlib import Path
import re

from update_kokumin_local_endorsements import parse_candidate_rows, parse_source_as_of

_DATE = re.compile(r"(?P<open>[(（])?\s*(?P<year>[0-9]{4})/(?P<month>[0-9]{1,2})/(?P<day>[0-9]{1,2})\s*(?P<close>[)）])?")


def classify_date_tail(tail: str) -> dict:
    matches = list(_DATE.finditer(tail))
    tokens = []
    for match in matches:
        opening, closing = match.group("open"), match.group("close")
        if bool(opening) != bool(closing) or (
            opening and (opening, closing) not in {("(", ")"), ("（", "）")}
        ):
            raise ValueError("Unbalanced date parentheses")
        parsed = date(*(int(match.group(part)) for part in ("year", "month", "day")))
        tokens.append({"value": parsed.isoformat(), "kind": "term_expiry" if opening else "unclassified_reported_date"})
    if _DATE.sub("", tail).strip():
        raise ValueError("Unrecognized text in PDF date columns")
    if len(tokens) > 2:
        raise ValueError("Ambiguous PDF date columns")
    # With two explicit columns, the left is the announcement and the right
    # the voting/term-expiry column. A lone plain date stays unclassified.
    if len(tokens) == 2:
        if tokens[0]["kind"] == "term_expiry":
            raise ValueError("Term-expiry value appeared in announcement column")
        tokens[0]["kind"] = "reported_announcement_date"
        if tokens[1]["kind"] != "term_expiry":
            tokens[1]["kind"] = "reported_voting_date"
    return {
        "dateEvidence": tokens,
        "verifiedVoteDate": None,
        "eligibleForScheduleJoin": False,
        "reviewStatus": "requires_election_identity_and_commission_verification",
    }


def audit_candidate_dates(pdf_bytes: bytes, page_texts: list[str], source_url: str) -> dict:
    rows = parse_candidate_rows(page_texts)
    evidence = []
    for index, row in enumerate(rows, 1):
        tail = re.split(r"公認|推薦", row["sourceRow"])[-1]
        evidence.append({
            "sourceRowOrdinal": index,
            "prefecture": row["prefecture"],
            "decision": row["decision"],
            "assemblyCategory": row["assemblyCategory"],
            "sourceRow": row["sourceRow"],
            **classify_date_tail(tail),
        })
    return {
        "schemaVersion": 1,
        "sourceUrl": source_url,
        "sourceAsOf": parse_source_as_of(page_texts),
        "sourceDocumentSha256": hashlib.sha256(pdf_bytes).hexdigest(),
        "confirmedCandidateElectionAssociations": 0,
        "rows": evidence,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pdf", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--source-url", required=True)
    args = parser.parse_args()
    from pypdf import PdfReader
    pdf_bytes = args.pdf.read_bytes()
    pages = [page.extract_text(extraction_mode="layout") for page in PdfReader(io.BytesIO(pdf_bytes)).pages]
    result = audit_candidate_dates(pdf_bytes, pages, args.source_url)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Audited {len(result['rows'])} rows; no confirmed election associations created.")


if __name__ == "__main__":
    main()
