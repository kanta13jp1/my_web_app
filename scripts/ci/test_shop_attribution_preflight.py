import unittest

from shop_attribution_preflight import RUNTIME_SETTINGS, validate_context


class PreflightTest(unittest.TestCase):
    def setUp(self):
        self.sha = "a" * 40
        self.env = {
            "GITHUB_ACTIONS": "true", "GITHUB_SHA": self.sha,
            "GITHUB_EVENT_NAME": "push",
            "GITHUB_REF": "refs/heads/codex/hexciv-post-attribution-fixture",
        }

    def test_exact_push_source_is_reported_without_production_claim(self):
        report = validate_context(self.env, self.sha)
        self.assertEqual(report["checked_sha"], self.sha)
        self.assertEqual(report["production_validation"], "not-performed")

    def test_local_execution_is_rejected(self):
        with self.assertRaises(ValueError):
            validate_context({**self.env, "GITHUB_ACTIONS": "false"}, self.sha)

    def test_mismatched_or_malformed_sha_is_rejected(self):
        for actual in ("b" * 40, "a" * 7, "A" * 40, self.sha + "\n"):
            with self.subTest(actual=actual), self.assertRaises(ValueError):
                validate_context(self.env, actual)

    def test_manual_execution_requires_exact_nonempty_expected_sha(self):
        env = {**self.env, "GITHUB_EVENT_NAME": "workflow_dispatch"}
        for expected in ("", "b" * 40, "a" * 7, "$(echo arbitrary)"):
            with self.subTest(expected=expected), self.assertRaises(ValueError):
                validate_context({**env, "EXPECTED_HEAD_SHA": expected}, self.sha)
        self.assertEqual(validate_context(
            {**env, "EXPECTED_HEAD_SHA": self.sha}, self.sha
        )["event"], "workflow_dispatch")

    def test_protected_and_unscoped_pushes_are_rejected(self):
        for ref in ("refs/heads/main", "refs/heads/develop", "refs/tags/v1",
                    "refs/heads/codex/other", "refs/heads/codex/hexciv-post-attribution-"):
            with self.subTest(ref=ref), self.assertRaises(ValueError):
                validate_context({**self.env, "GITHUB_REF": ref}, self.sha)

    def test_pr_merge_source_is_accepted(self):
        report = validate_context({**self.env, "GITHUB_EVENT_NAME": "pull_request",
                                   "GITHUB_REF": "refs/pull/5397/merge"}, self.sha)
        self.assertEqual(report["event"], "pull_request")

    def test_pr_head_fallback_and_privileged_events_are_rejected(self):
        for event, ref in (("pull_request", "refs/pull/5397/head"),
                           ("pull_request_target", "refs/heads/main"),
                           ("schedule", self.env["GITHUB_REF"])):
            with self.subTest(event=event), self.assertRaises(ValueError):
                validate_context({**self.env, "GITHUB_EVENT_NAME": event,
                                  "GITHUB_REF": ref}, self.sha)

    def test_runtime_configuration_is_rejected_without_echoing_values(self):
        for key in RUNTIME_SETTINGS:
            with self.subTest(key=key):
                with self.assertRaises(ValueError) as caught:
                    validate_context({**self.env, key: "private-fixture-sentinel"}, self.sha)
                self.assertNotIn("private-fixture-sentinel", str(caught.exception))

    def database_env(self):
        return {**self.env, "PGHOST": "127.0.0.1", "PGPORT": "5432",
                "PGUSER": "postgres", "PGDATABASE": "hexciv_attribution_ci",
                "PGPASSWORD": "ephemeral-attribution-only"}

    def test_fixed_disposable_database_is_accepted(self):
        self.assertEqual(validate_context(self.database_env(), self.sha,
                                          database=True)["scope"], "disposable-sql-fixture")

    def test_remote_or_missing_db_settings_are_rejected(self):
        for key in ("PGHOST", "PGPORT", "PGUSER", "PGDATABASE", "PGPASSWORD"):
            for value in ("", "remote-or-wrong"):
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    validate_context({**self.database_env(), key: value}, self.sha,
                                     database=True)

    def test_service_file_and_options_cannot_override_db_target(self):
        for key in ("PGSERVICE", "PGSERVICEFILE", "PGOPTIONS"):
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate_context({**self.database_env(), key: "override"}, self.sha,
                                 database=True)


if __name__ == "__main__":
    unittest.main()
