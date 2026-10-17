import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

from scripts import validate_agent_skills


class ValidateAgentSkillsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        (self.root / ".agents" / "skills").mkdir(parents=True)
        (self.root / "scripts").mkdir()

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def write_skill(self, name: str, *, body: str = "# Skill\n") -> Path:
        skill_dir = self.root / ".agents" / "skills" / name
        skill_dir.mkdir(parents=True)
        (skill_dir / "SKILL.md").write_text(
            "---\n"
            f"name: {name}\n"
            f"description: Use {name} for a deterministic test.\n"
            "---\n\n"
            f"{body}",
            encoding="utf-8",
        )
        agents_dir = skill_dir / "agents"
        agents_dir.mkdir()
        (agents_dir / "openai.yaml").write_text(
            "interface:\n"
            f'  display_name: "{name.title()} Skill"\n'
            f'  short_description: "Deterministic metadata for the {name} test skill"\n'
            f'  default_prompt: "Use ${name} to run a deterministic test."\n',
            encoding="utf-8",
        )
        return skill_dir

    def write_manifest(self, entries: list[dict[str, object]]) -> Path:
        path = self.root / ".agents" / "skills" / "ci-manifest.json"
        path.write_text(
            json.dumps({"schema_version": 1, "skills": entries}),
            encoding="utf-8",
        )
        return path

    def python_smoke(self, script: str = "scripts/smoke.py") -> dict[str, object]:
        return {"argv": ["{python}", script, "--help"]}

    def test_valid_skill_checks_frontmatter_link_and_smoke(self) -> None:
        skill_dir = self.write_skill("alpha", body="# Alpha\n\n[Guide](references/guide.md)\n")
        references = skill_dir / "references"
        references.mkdir()
        (references / "guide.md").write_text("# Guide\n", encoding="utf-8")
        (self.root / "scripts" / "smoke.py").write_text(
            "print('usage: smoke --help')\n", encoding="utf-8"
        )
        manifest = self.write_manifest(
            [{"name": "alpha", "grade": "A", "cli_smoke": [self.python_smoke()]}]
        )

        report = validate_agent_skills.validate_repository(self.root, manifest)

        self.assertTrue(report.ok, report.errors)
        self.assertEqual(report.skills, 1)
        self.assertEqual(report.ui_metadata_checked, 1)
        self.assertEqual(report.links_checked, 1)
        self.assertEqual(report.smokes_run, 1)

    def test_ui_metadata_requires_utf8(self) -> None:
        skill_dir = self.write_skill("alpha")
        (skill_dir / "agents" / "openai.yaml").write_bytes(
            "interface:\n  display_name: テスト\n".encode("cp932")
        )
        (self.root / "scripts" / "smoke.py").write_text("print('ok')\n", encoding="utf-8")
        manifest = self.write_manifest(
            [{"name": "alpha", "grade": "B", "cli_smoke": [self.python_smoke()]}]
        )

        report = validate_agent_skills.validate_repository(self.root, manifest)

        self.assertFalse(report.ok)
        self.assertTrue(any("must be valid UTF-8" in error for error in report.errors))

    def test_ui_metadata_validates_prompt_and_length(self) -> None:
        skill_dir = self.write_skill("alpha")
        (skill_dir / "agents" / "openai.yaml").write_text(
            "interface:\n"
            '  display_name: "Alpha"\n'
            '  short_description: "too short"\n'
            '  default_prompt: "Run the skill."\n',
            encoding="utf-8",
        )
        (self.root / "scripts" / "smoke.py").write_text("print('ok')\n", encoding="utf-8")
        manifest = self.write_manifest(
            [{"name": "alpha", "grade": "B", "cli_smoke": [self.python_smoke()]}]
        )

        report = validate_agent_skills.validate_repository(self.root, manifest)

        self.assertFalse(report.ok)
        self.assertTrue(any("25..64 characters" in error for error in report.errors))
        self.assertTrue(any("must mention $alpha" in error for error in report.errors))

    def test_frontmatter_rejects_extra_key_and_name_mismatch(self) -> None:
        skill_dir = self.write_skill("alpha")
        (skill_dir / "SKILL.md").write_text(
            "---\nname: beta\ndescription: Wrong name.\nmetadata: forbidden\n---\n# Body\n",
            encoding="utf-8",
        )
        (self.root / "scripts" / "smoke.py").write_text("print('ok')\n", encoding="utf-8")
        manifest = self.write_manifest(
            [{"name": "alpha", "grade": "B", "cli_smoke": [self.python_smoke()]}]
        )

        report = validate_agent_skills.validate_repository(self.root, manifest)

        self.assertFalse(report.ok)
        self.assertTrue(any("unsupported frontmatter keys" in error for error in report.errors))
        self.assertTrue(any("must match the directory" in error for error in report.errors))

    def test_broken_relative_link_fails(self) -> None:
        self.write_skill("alpha", body="# Alpha\n\n[Missing](references/missing.md)\n")
        (self.root / "scripts" / "smoke.py").write_text("print('ok')\n", encoding="utf-8")
        manifest = self.write_manifest(
            [{"name": "alpha", "grade": "A", "cli_smoke": [self.python_smoke()]}]
        )

        report = validate_agent_skills.validate_repository(self.root, manifest)

        self.assertFalse(report.ok)
        self.assertTrue(any("missing link target" in error for error in report.errors))

    def test_frontmatter_accepts_yaml_chomping_indicators(self) -> None:
        skill_file = self.write_skill("alpha") / "SKILL.md"
        for indicator in (">-", ">+", "|-", "|+"):
            with self.subTest(indicator=indicator):
                skill_file.write_text(
                    f"---\nname: alpha\ndescription: {indicator}\n  A multiline\n  description.\n---\n# Body\n",
                    encoding="utf-8",
                )
                self.assertEqual(validate_agent_skills.validate_frontmatter("alpha", skill_file), [])

    def test_nonzero_smoke_fails(self) -> None:
        self.write_skill("alpha")
        (self.root / "scripts" / "smoke.py").write_text(
            "raise SystemExit(7)\n", encoding="utf-8"
        )
        manifest = self.write_manifest(
            [{"name": "alpha", "grade": "A", "cli_smoke": [self.python_smoke()]}]
        )

        report = validate_agent_skills.validate_repository(self.root, manifest)

        self.assertFalse(report.ok)
        self.assertTrue(any("smoke exited 7" in error for error in report.errors))

    def test_manifest_must_classify_every_active_skill(self) -> None:
        self.write_skill("alpha")
        self.write_skill("beta")
        (self.root / "scripts" / "smoke.py").write_text("print('ok')\n", encoding="utf-8")
        manifest = self.write_manifest(
            [{"name": "alpha", "grade": "A", "cli_smoke": [self.python_smoke()]}]
        )

        report = validate_agent_skills.validate_repository(self.root, manifest)

        self.assertFalse(report.ok)
        self.assertTrue(any("missing A/B classification: beta" in error for error in report.errors))


if __name__ == "__main__":
    unittest.main()
