from copy import deepcopy
import unittest

from member_contract import DATASET, HUB_SOURCE, content_hash, plan_member_transition, validate_proposed_observation


def observation():
    return {"dataset": DATASET, "hubSource": HUB_SOURCE, "schemaVersion": 1,
            "observedAt": "2026-11-05T00:00:00Z", "persistenceEnabled": False,
            "coverage": {"members": "observed_complete", "candidates": "not_observed", "schedules": "not_observed"},
            "quality": {"complete": True, "issues": [], "failedPrefectures": [],
                        "minimumExpectedMemberCount": 170, "linkedPrefectureCount": 46},
            "officialCurrentLocalMembers": 170,
            "members": [{"detailUrl": f"https://new-kokumin.jp/member/test-{i}",
                         "name": f"合成テスト議員{i}", "prefecture": "東京都",
                         "assemblyLabel": "合成テスト市議会議員"} for i in range(170)]}


class MemberObservationContractTest(unittest.TestCase):
    def test_first_observation_is_its_own_baseline_with_no_candidate_delta(self):
        result = plan_member_transition(None, observation())
        self.assertEqual(result["kind"], "independent_baseline")
        self.assertIsNone(result["memberListingChanges"])
        self.assertEqual(result["candidateObservation"], "not_observed")
        self.assertFalse(result["mayInferWithdrawal"])

    def test_legacy_combined_dataset_cannot_be_the_previous_observation(self):
        for field, value in [("dataset", "kokumin_local_election_intelligence"),
                             ("hubSource", "local_election_dataset_snapshot")]:
            before = observation()
            before[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                plan_member_transition(before, observation())

    def test_absent_candidate_or_schedule_arrays_are_not_synthesized(self):
        result = validate_proposed_observation(observation())
        self.assertNotIn("upcomingSchedules", result)
        self.assertNotIn("candidates", result)
        self.assertEqual(result["coverage"]["candidates"], "not_observed")

    def test_cross_stream_arrays_and_partial_legacy_snapshots_are_rejected(self):
        for field in ["candidates", "upcomingSchedules", "electionIntelligence", "snapshot"]:
            raw = observation()
            raw[field] = []
            with self.subTest(field=field), self.assertRaises(ValueError):
                validate_proposed_observation(raw)

    def test_missing_or_empty_coverage_does_not_mean_complete_observation(self):
        for coverage in [{}, {"members": "observed_complete"},
                         {"members": "observed_complete", "candidates": [], "schedules": []}]:
            raw = observation()
            raw["coverage"] = coverage
            with self.subTest(coverage=coverage), self.assertRaises(ValueError):
                validate_proposed_observation(raw)

    def test_member_change_does_not_imply_candidate_withdrawal_or_publication(self):
        after = observation()
        after["members"][0]["detailUrl"] = "https://new-kokumin.jp/member/new-profile"
        result = plan_member_transition(observation(), after)
        self.assertEqual(len(result["memberListingChanges"]["newlyListed"]), 1)
        self.assertEqual(len(result["memberListingChanges"]["notInCurrentListing"]), 1)
        self.assertEqual(result["candidateObservation"], "not_observed")
        self.assertFalse(result["mayPublish"])
        self.assertFalse(result["mayInferWithdrawal"])

    def test_existing_member_threshold_and_link_gate_cannot_be_reduced(self):
        for field, value in [("minimumExpectedMemberCount", 1), ("linkedPrefectureCount", 9),
                             ("failedPrefectures", ["東京都"]), ("issues", ["parse_failed"]),
                             ("complete", False)]:
            raw = observation()
            raw["quality"][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                validate_proposed_observation(raw)

    def test_empty_partial_or_inconsistent_roster_cannot_replace_complete_data(self):
        samples = []
        empty = observation(); empty["members"] = []; empty["officialCurrentLocalMembers"] = 0; samples.append(empty)
        partial = observation(); partial["members"].pop(); partial["officialCurrentLocalMembers"] = 169; samples.append(partial)
        mismatch = observation(); mismatch["officialCurrentLocalMembers"] = 416; samples.append(mismatch)
        for raw in samples:
            with self.subTest(count=raw["officialCurrentLocalMembers"]), self.assertRaises(ValueError):
                validate_proposed_observation(raw)

    def test_duplicate_or_candidate_fields_in_member_identity_are_rejected(self):
        duplicate = observation(); duplicate["members"][1] = deepcopy(duplicate["members"][0])
        cross_stream = observation(); cross_stream["members"][0]["voteDate"] = "2027-04-11"
        for raw in [duplicate, cross_stream]:
            with self.assertRaises(ValueError):
                validate_proposed_observation(raw)

    def test_content_hash_is_stable_across_order_and_observation_time(self):
        changed = observation()
        changed["members"].reverse()
        changed["observedAt"] = "2026-11-06T00:00:00Z"
        self.assertEqual(content_hash(observation()), content_hash(changed))

    def test_neither_validation_nor_diff_mutates_prior_observations(self):
        before = observation(); after = observation(); original = deepcopy(before)
        plan_member_transition(before, after)
        self.assertEqual(before, original)

    def test_the_model_never_authorizes_persistence(self):
        raw = observation(); raw["persistenceEnabled"] = True
        with self.assertRaises(ValueError):
            validate_proposed_observation(raw)
        self.assertFalse(plan_member_transition(observation(), observation())["mayPersist"])


if __name__ == "__main__":
    unittest.main()
