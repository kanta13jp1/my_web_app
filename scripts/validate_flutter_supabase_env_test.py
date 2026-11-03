#!/usr/bin/env python3

import base64
import json
import unittest

from validate_flutter_supabase_env import validate_environment, validate_publishable_key


def fake_legacy_jwt(role: str) -> str:
    payload = base64.urlsafe_b64encode(
        json.dumps({"role": role}).encode("utf-8")
    ).decode("ascii").rstrip("=")
    return f"header.{payload}.signature"


class ValidateFlutterSupabaseEnvTest(unittest.TestCase):
    def test_accepts_new_publishable_key(self) -> None:
        validate_environment(
            "https://example.supabase.co",
            "sb_publishable_example",
        )

    def test_accepts_legacy_anon_key_during_migration(self) -> None:
        validate_publishable_key(fake_legacy_jwt("anon"))

    def test_rejects_new_secret_and_legacy_service_role(self) -> None:
        for key in ("sb_secret_example", fake_legacy_jwt("service_role")):
            with self.subTest(key_type=key.split("_", 2)[0]):
                with self.assertRaises(ValueError):
                    validate_publishable_key(key)

    def test_rejects_unknown_key_shape(self) -> None:
        with self.assertRaises(ValueError):
            validate_publishable_key("not-a-supabase-public-key")


if __name__ == "__main__":
    unittest.main()
