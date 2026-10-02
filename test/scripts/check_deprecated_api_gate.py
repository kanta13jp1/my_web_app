#!/usr/bin/env python3
"""Cloud-only negative integration proof for the repository analyzer gate."""
import json
from pathlib import Path
import re
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from quality_gate import flutter_analyze_command, run_analyzer_gate  # noqa: E402


def main() -> int:
    evidence_root = Path(".ci-logs/deprecated-api-gate")
    cases = (
        ("supported", "withValues(alpha: 0.5)", False),
        ("deprecated", "withOpacity(0.5)", True),
    )
    with tempfile.TemporaryDirectory(prefix="deprecated-gate-", dir=ROOT / "test") as directory:
        fixture = Path(directory) / "probe.dart"
        for name, expression, should_fail in cases:
            fixture.write_text(
                "import 'dart:ui';\n\n"
                f"Color buildProbe() => const Color(0xff000000).{expression};\n",
                encoding="utf-8",
            )
            artifact_dir = evidence_root / name
            code = run_analyzer_gate(
                flutter_analyze_command([fixture.relative_to(ROOT).as_posix()]),
                ROOT,
                artifact_dir,
            )
            result = json.loads((ROOT / artifact_dir / "result.json").read_text(encoding="utf-8"))
            log = (ROOT / artifact_dir / "flutter-analyze.log").read_text(encoding="utf-8")
            if should_fail:
                if code == 0 or result["status"] != "code_findings":
                    raise AssertionError("Deprecated API must fail as a code finding, not an infrastructure failure.")
                diagnostics = [line for line in log.splitlines() if "deprecated_member_use" in line]
                if not any("error" in line.lower() and re.search(r"probe\.dart:3:\d+", line)
                           for line in diagnostics):
                    raise AssertionError("Missing error diagnostic and exact fixture source location.")
                if result.get("fallback") is not None:
                    raise AssertionError("Code findings must not be masked by an analyzer fallback.")
            elif code != 0 or result["status"] != "success":
                raise AssertionError("Supported API control fixture must pass without degraded fallback.")
            print(f"VERIFIED {name}: status={result['status']} exit={code}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
