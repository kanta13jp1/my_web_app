import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
MIGRATION = ROOT / "supabase" / "migrations" / "20260903030000_self_touch_disclosure_consent.sql"


class SelfTouchConsentMigrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.sql = MIGRATION.read_text(encoding="utf-8").lower()

    def test_consent_is_private_and_owner_scoped(self) -> None:
        self.assertIn("self_touch_tracking_consents", self.sql)
        self.assertIn("enable row level security", self.sql)
        self.assertIn("auth.uid()) = user_id", self.sql)
        self.assertNotIn("user_profiles", self.sql.split("create table if not exists public.self_touch_tracking_consents", 1)[1])

    def test_disclosure_is_versioned_and_uses_official_https_support(self) -> None:
        self.assertIn("version text primary key", self.sql)
        self.assertIn("https://www.mhlw.go.jp/mamorouyokokoro/soudan/", self.sql)
        self.assertIn("where is_active", self.sql)


if __name__ == "__main__":
    unittest.main()
