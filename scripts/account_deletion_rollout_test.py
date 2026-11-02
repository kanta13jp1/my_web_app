import unittest

from account_deletion_rollout import decide


class AccountDeletionRolloutTest(unittest.TestCase):
    def decision(self, **overrides):
        values = {
            "event_name": "workflow_dispatch",
            "stage": "disabled",
            "automation_enabled": False,
            "apply_requested": False,
            "request_id_raw": "",
            "max_requests_raw": "1",
            "confirmation": "",
        }
        values.update(overrides)
        return decide(**values)

    def test_disabled_manual_run_is_preflight_only(self):
        result = self.decision(request_id_raw="2844")
        self.assertEqual(result.mode, "preflight")
        self.assertEqual(result.request_id, 2844)

    def test_disabled_stage_rejects_destructive_manual_run(self):
        with self.assertRaisesRegex(ValueError, "disabled"):
            self.decision(apply_requested=True)

    def test_canary_requires_exact_id_single_item_and_confirmation(self):
        result = self.decision(
            stage="canary",
            apply_requested=True,
            request_id_raw="2844",
            confirmation="DELETE REQUEST 2844",
        )
        self.assertEqual(result.mode, "apply")
        self.assertEqual(result.max_requests, 1)
        with self.assertRaisesRegex(ValueError, "request_id"):
            self.decision(stage="canary", apply_requested=True)

    def test_limited_schedule_requires_separate_kill_switch(self):
        stopped = self.decision(
            event_name="schedule", stage="limited", automation_enabled=False
        )
        self.assertEqual(stopped.mode, "skip")
        running = self.decision(
            event_name="schedule", stage="limited", automation_enabled=True
        )
        self.assertEqual((running.mode, running.max_requests), ("apply", 1))

    def test_full_schedule_is_bounded(self):
        result = self.decision(
            event_name="schedule", stage="full", automation_enabled=True
        )
        self.assertEqual(result.max_requests, 10)

    def test_limited_manual_batch_is_capped(self):
        with self.assertRaisesRegex(ValueError, "at most 5"):
            self.decision(
                stage="limited",
                apply_requested=True,
                max_requests_raw="6",
                confirmation="DELETE UP TO 6",
            )


if __name__ == "__main__":
    unittest.main()
