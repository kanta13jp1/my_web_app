import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github" / "workflows" / "ai-university-update.yml"


class AiUniversityUpdateWorkflowTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.workflow = WORKFLOW.read_text(encoding="utf-8")

    def test_catalog_projection_satisfies_course_review_export_contract(self) -> None:
        projection = (
            "select=id,provider,title,source_url,is_active,target_audience,"
            "observable_learning_outcome,assessment_verification_method,"
            "evidence_source_url,evidence_verified_at"
        )
        self.assertIn(projection, self.workflow)
        self.assertIn("scripts/ai_university_export_contract.py", self.workflow)
        self.assertNotIn("select=id,provider,source_url,is_active&", self.workflow)

    def test_reliability_steps_reuse_audit_runner_and_publish_only_aggregates(self) -> None:
        self.assertNotIn("  reliability-metrics:", self.workflow)
        start = self.workflow.index("  source-audit:")
        end = self.workflow.index("\n  update:", start)
        job = self.workflow[start:end]
        self.assertIn("scripts/ai_university_reliability_metrics.py", job)
        self.assertIn("select=event_name,surface,occurred_at", job)
        self.assertIn("--window-start \"$SINCE\"", job)
        self.assertIn("--window-end \"$UNTIL\"", job)
        self.assertIn("path: .artifacts/ai-university-reliability/metrics.*", job)
        self.assertNotIn("-X POST", job)
        self.assertNotIn("events.json\n          if-no-files-found", job)


if __name__ == "__main__":
    unittest.main()
