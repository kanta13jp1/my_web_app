import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

from check_feature_architecture import (  # noqa: E402
    check_features_directory,
    find_presentation_files,
    main,
)


class CheckFeatureArchitectureTest(unittest.TestCase):
    def test_clean_presentation_passes_without_violations(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir) / "lib" / "features"
            pres = root / "sample_feature" / "presentation"
            pres.mkdir(parents=True)
            (pres / "sample_view.dart").write_text(
                "import 'package:flutter/material.dart';\n\nclass SampleView {}\n",
                encoding="utf-8",
            )
            self.assertEqual(len(find_presentation_files(root)), 1)
            self.assertEqual(check_features_directory(root), [])

            buf = io.StringIO()
            with redirect_stdout(buf):
                rc = main(["--root", str(root), "--json"])
            self.assertEqual(rc, 0)
            report = json.loads(buf.getvalue())
            self.assertEqual(report["violation_count"], 0)
            self.assertEqual(report["presentation_files_checked"], 1)

    def test_detects_supabase_and_http_imports_in_presentation(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir) / "lib" / "features"
            pres = root / "bad_feature" / "presentation"
            pres.mkdir(parents=True)
            (pres / "bad_view.dart").write_text(
                "\n".join([
                    "// import 'package:http/http.dart'; (commented out)",
                    "import 'package:flutter/material.dart';",
                    "import 'package:supabase_flutter/supabase_flutter.dart';",
                    "import 'package:http/http.dart' as http;",
                ]) + "\n",
                encoding="utf-8",
            )
            violations = check_features_directory(root)
            self.assertEqual(len(violations), 2)
            self.assertEqual(
                [v.import_uri for v in violations],
                [
                    "package:supabase_flutter/supabase_flutter.dart",
                    "package:http/http.dart",
                ],
            )
            self.assertEqual(main(["--root", str(root)]), 1)


if __name__ == "__main__":
    unittest.main()
