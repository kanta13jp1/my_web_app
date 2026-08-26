import tempfile
import unittest
from pathlib import Path

from check_ai_code_antipatterns import scan_file


class AiCodeAntipatternsTest(unittest.TestCase):
    def test_typed_source_has_no_findings(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "service.ts"
            path.write_text("const value: unknown = input;\n", encoding="utf-8")
            self.assertEqual(scan_file(path), [])

    def test_explicit_any_and_placeholder_are_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "service.ts"
            path.write_text(
                "const value = input as any;\nthrow new NotImplementedError();\n",
                encoding="utf-8",
            )
            codes = {finding.code for finding in scan_file(path)}
            self.assertIn("explicit-any", codes)
            self.assertIn("unimplemented-stub", codes)

    def test_dynamic_threshold_ignores_generated_dart(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "payload.dart"
            source.write_text("\n".join(f"dynamic value{i};" for i in range(4)), encoding="utf-8")
            self.assertIn("dynamic-overuse", {item.code for item in scan_file(source)})

            generated = root / "payload.g.dart"
            generated.write_text(source.read_text(encoding="utf-8"), encoding="utf-8")
            self.assertEqual(scan_file(generated), [])

    def test_empty_and_duplicate_copy_are_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            empty = root / "empty.dart"
            empty.touch()
            self.assertEqual(scan_file(empty)[0].code, "empty-file")

            canonical = root / "service.dart"
            canonical.write_text("final value = 1;\n", encoding="utf-8")
            duplicate = root / "service_copy.dart"
            duplicate.write_text("final value = 2;\n", encoding="utf-8")
            self.assertIn("possible-ghost-file", {item.code for item in scan_file(duplicate)})


class CiAutoFixHumanGateTest(unittest.TestCase):
    def test_manual_workflow_requires_human_acknowledgement(self):
        workflow = (
            Path(__file__).resolve().parents[1] / ".github" / "workflows" / "ci-auto-fix.yml"
        ).read_text(encoding="utf-8")
        self.assertIn("human_review_acknowledged", workflow)
        self.assertIn("context.actor", workflow)
        self.assertIn("endsWith('[bot]')", workflow)


if __name__ == "__main__":
    unittest.main()
