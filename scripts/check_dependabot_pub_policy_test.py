#!/usr/bin/env python3
from __future__ import annotations

import unittest

from check_dependabot_pub_policy import (
    dependency_changes,
    dependency_constraints,
    policy_violations,
)


class DependabotPubPolicyTest(unittest.TestCase):
    def test_blocks_the_failed_group_update_from_pr_4227(self) -> None:
        base = """
dependencies:
  xml: ^6.6.1
dev_dependencies:
  flutter_native_splash: ">=2.4.7 <2.4.8"
"""
        head = """
dependencies:
  xml: ^7.0.1
dev_dependencies:
  flutter_native_splash: ^2.4.8
"""

        violations = policy_violations(dependency_changes(base, head))

        self.assertEqual(len(violations), 2)
        self.assertTrue(any("xml" in item and "major" in item for item in violations))
        self.assertTrue(
            any("flutter_native_splash" in item and "pinned" in item for item in violations)
        )

    def test_allows_minor_and_patch_updates(self) -> None:
        base = """
dependencies:
  uuid: ^4.5.3
  image_picker: ^1.2.2
"""
        head = """
dependencies:
  uuid: ^4.6.0
  image_picker: ^1.2.3
"""

        self.assertEqual(policy_violations(dependency_changes(base, head)), [])

    def test_ignores_nested_non_dependency_settings(self) -> None:
        pubspec = """
dependencies:
  package_with_git_source:
    git:
      url: https://example.com/package.git
flutter_native_splash:
  color: "#ffffff"
flutter_launcher_icons:
  android: true
"""

        self.assertEqual(dependency_constraints(pubspec), {})

    def test_preserves_hash_inside_a_quoted_constraint(self) -> None:
        base = """
dependencies:
  sample: "1.2.3#old"
"""
        head = """
dependencies:
  sample: "1.3.0#new"
"""

        changes = dependency_changes(base, head)

        self.assertEqual(changes[0].old_constraint, "1.2.3#old")
        self.assertEqual(changes[0].new_constraint, "1.3.0#new")
        self.assertEqual(policy_violations(changes), [])


if __name__ == "__main__":
    unittest.main()
