import json
import unittest

from scripts.ai_university_provider_catalog import (
    build_catalog,
    normalize_provider_id,
    normalized_provider_ids,
)
from scripts.prerender_seo_routes import materialize_ai_university_route


class AiUniversityProviderCatalogTest(unittest.TestCase):
    def test_normalizes_and_deduplicates_active_provider_rows(self) -> None:
        rows = [
            {"provider": " OpenAI "},
            {"provider": "openai"},
            {"provider": "ANTHROPIC"},
            {"provider": ""},
            {"provider": None},
        ]
        self.assertEqual(normalize_provider_id(" OpenAI "), "openai")
        self.assertEqual(normalized_provider_ids(rows), ["anthropic", "openai"])
        catalog = build_catalog(rows, generated_at="2026-08-31T00:00:00Z")
        self.assertEqual(catalog["provider_count"], 2)
        self.assertEqual(catalog["provider_ids"], ["anthropic", "openai"])
        self.assertEqual(catalog["normalization"], "trim+lowercase+unique")

    def test_one_catalog_count_materializes_all_gemini_route_copy(self) -> None:
        route = {
            "path": "/gemini-university",
            "title": "AI大学 {provider_count}社",
            "description": "{provider_count}社を学ぶ",
            "h1": "{provider_count}社のAI",
            "points": ["{provider_count}社を網羅"],
        }
        resolved = materialize_ai_university_route(route, 352)
        serialized = json.dumps(resolved, ensure_ascii=False)
        self.assertNotIn("{provider_count}", serialized)
        self.assertEqual(resolved["title"], "AI大学 352社")
        self.assertEqual(resolved["description"], "352社を学ぶ")
        self.assertEqual(resolved["h1"], "352社のAI")
        self.assertEqual(resolved["points"], ["352社を網羅"])

    def test_non_ai_route_is_unchanged(self) -> None:
        route = {"path": "/privacy", "title": "privacy"}
        self.assertEqual(materialize_ai_university_route(route, 352), route)


if __name__ == "__main__":
    unittest.main()