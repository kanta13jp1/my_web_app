import unittest
from pathlib import Path


MIGRATION = Path("supabase/migrations/20260829170000_create_decision_event_chain.sql")


class DecisionEventMigrationContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.sql = MIGRATION.read_text(encoding="utf-8")

    def test_tables_are_rls_enabled_and_rpc_is_service_role_only(self) -> None:
        self.assertIn("ALTER TABLE public.review_evidence ENABLE ROW LEVEL SECURITY", self.sql)
        self.assertIn("ALTER TABLE public.decision_events ENABLE ROW LEVEL SECURITY", self.sql)
        self.assertIn("SECURITY DEFINER\nSET search_path = pg_catalog, extensions", self.sql)
        self.assertIn(
            "GRANT EXECUTE ON FUNCTION public.append_decision_event(uuid, text, text, text, text, jsonb, uuid, jsonb) TO service_role",
            self.sql,
        )

    def test_service_role_cannot_bypass_hashing_with_direct_inserts(self) -> None:
        self.assertNotIn("GRANT SELECT, INSERT ON TABLE", self.sql)
        self.assertNotIn("GRANT INSERT ON TABLE", self.sql)
        self.assertIn("GRANT SELECT ON TABLE public.review_evidence TO service_role", self.sql)
        self.assertIn("GRANT SELECT ON TABLE public.decision_events TO service_role", self.sql)

    def test_idempotent_evidence_compares_metadata(self) -> None:
        self.assertIn("AND metadata = COALESCE(p_review_evidence->'metadata', '{}'::jsonb)", self.sql)

    def test_evidence_shape_rejects_null_required_fields(self) -> None:
        self.assertIn("AND findings_sha256 IS NOT NULL", self.sql)
        self.assertIn("AND exception_reason IS NOT NULL", self.sql)
        self.assertIn("AND length(exception_reason) BETWEEN 12 AND 2000", self.sql)

    def test_trace_order_uses_an_atomic_monotonic_sequence(self) -> None:
        self.assertIn("sequence_no bigint NOT NULL CHECK (sequence_no > 0)", self.sql)
        self.assertIn("UNIQUE (trace_id, sequence_no)", self.sql)
        self.assertIn("ORDER BY sequence_no DESC", self.sql)
        self.assertIn("v_sequence_no := COALESCE(v_previous.sequence_no, 0) + 1", self.sql)
        self.assertIn("'sequence_no', v_sequence_no", self.sql)

    def test_all_foreign_key_handoff_paths_are_indexed(self) -> None:
        self.assertIn("ON public.decision_events (previous_event_id)", self.sql)
        self.assertIn("ON public.decision_events (handoff_parent_event_id)", self.sql)
        self.assertIn("ON public.decision_events (review_evidence_id)", self.sql)


if __name__ == "__main__":
    unittest.main()
