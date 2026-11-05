"""Offline design model only; not imported by the app or Edge Function.

No database, network, cache, posting or file-write implementation is provided.
The tests assess proposed isolation invariants, not the production TypeScript.
"""
from __future__ import annotations

from copy import deepcopy
import hashlib
import json

DATASET = "kokumin_local_members_observation_v1"
HUB_SOURCE = "local_election_member_observation"
EXISTING_MEMBER_MINIMUM = 170
EXISTING_LINK_MINIMUM = 10


def validate_proposed_observation(raw: dict) -> dict:
    allowed = {"dataset", "hubSource", "schemaVersion", "observedAt", "coverage",
               "quality", "officialCurrentLocalMembers", "members", "persistenceEnabled"}
    if set(raw) != allowed:
        raise ValueError("Missing fields or cross-stream payload")
    if (raw["dataset"], raw["hubSource"], raw["schemaVersion"]) != (DATASET, HUB_SOURCE, 1):
        raise ValueError("Foreign dataset or schema")
    if raw["persistenceEnabled"] is not False:
        raise ValueError("This design model cannot authorize persistence")
    if raw["coverage"] != {"members": "observed_complete", "candidates": "not_observed", "schedules": "not_observed"}:
        raise ValueError("Unobserved candidates and schedules must remain explicit")
    quality = raw["quality"]
    if (quality.get("complete") is not True or quality.get("issues") != [] or
        quality.get("failedPrefectures") != [] or
        quality.get("minimumExpectedMemberCount") != EXISTING_MEMBER_MINIMUM or
        quality.get("linkedPrefectureCount", 0) < EXISTING_LINK_MINIMUM):
        raise ValueError("Member collection gate failed")
    members = raw["members"]
    if not isinstance(members, list) or len(members) < EXISTING_MEMBER_MINIMUM:
        raise ValueError("Member count below existing threshold")
    if raw["officialCurrentLocalMembers"] != len(members):
        raise ValueError("Roster and total disagree")
    identities = []
    for member in members:
        detail = member.get("detailUrl", "")
        if (set(member) != {"detailUrl", "name", "prefecture", "assemblyLabel"} or
            not detail.startswith("https://new-kokumin.jp/member/") or
            not member["name"] or not member["prefecture"] or not member["assemblyLabel"]):
            raise ValueError("Invalid member identity or cross-stream fields")
        identities.append(detail)
    if len(set(identities)) != len(identities):
        raise ValueError("Duplicate profile identities")
    return deepcopy(raw)


def content_hash(raw: dict) -> str:
    observation = validate_proposed_observation(raw)
    observation.pop("observedAt")
    observation["members"].sort(key=lambda row: row["detailUrl"])
    data = json.dumps(observation, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(data.encode()).hexdigest()


def plan_member_transition(before: dict | None, after: dict) -> dict:
    current = validate_proposed_observation(after)
    if before is None:
        return {"kind": "independent_baseline", "memberListingChanges": None,
                "candidateObservation": "not_observed", "scheduleObservation": "not_observed",
                "mayInferWithdrawal": False, "mayPublish": False, "mayPersist": False}
    previous = validate_proposed_observation(before)
    old = {row["detailUrl"]: row for row in previous["members"]}
    new = {row["detailUrl"]: row for row in current["members"]}
    return {"kind": "member_listing_observation_only",
            "memberListingChanges": {"newlyListed": sorted(set(new) - set(old)),
                                     "notInCurrentListing": sorted(set(old) - set(new))},
            "candidateObservation": "not_observed", "scheduleObservation": "not_observed",
            "mayInferWithdrawal": False, "mayPublish": False, "mayPersist": False}
