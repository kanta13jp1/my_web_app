import re
import unittest
from pathlib import Path


MIGRATION = (
    Path(__file__).parents[2]
    / "supabase"
    / "migrations"
    / "20260810090000_create_musubi_social_platform.sql"
)
CONSENT_MIGRATION = (
    Path(__file__).parents[2]
    / "supabase"
    / "migrations"
    / "20260813090000_enforce_musubi_research_consent.sql"
)


class MusubiMigrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sql = MIGRATION.read_text(encoding="utf-8")
        cls.normalized = re.sub(r"\s+", " ", cls.sql.lower())

    def test_all_sensitive_tables_enable_rls(self):
        tables = (
            "musubi_profiles",
            "musubi_posts",
            "musubi_threads",
            "musubi_thread_members",
            "musubi_messages",
            "musubi_reports",
            "musubi_research_feedback",
            "musubi_research_events",
        )
        for table in tables:
            self.assertIn(
                f"alter table public.{table} enable row level security",
                self.normalized,
            )

    def test_dm_access_is_membership_guarded(self):
        self.assertIn("is_musubi_thread_member", self.normalized)
        self.assertIn("musubi_messages_read_member", self.normalized)
        self.assertIn("sender_id = auth.uid()", self.normalized)
        self.assertNotIn(
            "create policy musubi_messages_read_member on public.musubi_messages "
            "for select to authenticated using (true)",
            self.normalized,
        )

    def test_realtime_and_search_are_provisioned(self):
        self.assertIn(
            "alter publication supabase_realtime add table public.musubi_posts",
            self.normalized,
        )
        self.assertIn(
            "alter publication supabase_realtime add table public.musubi_messages",
            self.normalized,
        )
        self.assertIn("function public.search_musubi", self.normalized)
        self.assertIn("musubi_posts_search_idx", self.normalized)
        self.assertIn("musubi_posts_content_trgm_idx", self.normalized)
        self.assertIn("function public.musubi_refresh_post_search_vector", self.normalized)
        self.assertIn("trigger musubi_posts_refresh_search_vector", self.normalized)
        self.assertNotIn("search_vector tsvector generated always", self.normalized)

    def test_trigram_index_supports_existing_extension_schemas(self):
        self.assertIn("set search_path = public, extensions", self.normalized)
        self.assertIn("content gin_trgm_ops", self.normalized)
        self.assertNotIn("extensions.gin_trgm_ops", self.normalized)
        self.assertIn("reset search_path", self.normalized)

    def test_research_storage_requires_consent_and_supports_deletion(self):
        self.assertIn("consent_to_research boolean not null", self.normalized)
        self.assertIn("and consent_to_research", self.normalized)
        self.assertIn("musubi_feedback_delete_own", self.normalized)

    def test_research_events_require_active_versioned_consent(self):
        sql = re.sub(
            r"\s+", " ", CONSENT_MIGRATION.read_text(encoding="utf-8").lower()
        )
        self.assertIn("consent_version text not null", sql)
        self.assertIn("musubi_events_insert_with_active_consent", sql)
        self.assertIn("exists ( select 1", sql)
        self.assertIn("feedback.consent_to_research", sql)
        self.assertIn("feedback.consent_version = musubi_research_events.consent_version", sql)
        self.assertIn("musubi_events_delete_own", sql)


if __name__ == "__main__":
    unittest.main()
