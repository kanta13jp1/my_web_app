#!/usr/bin/env python3
"""Render actual CI step outcomes; never infer one check from another."""
import json
import os

CHECKS = (
    ("Flutter dependencies", "flutter", "flutter_dependencies"),
    ("Flutter dependency verification", "flutter", "flutter_dependencies_verify"),
    ("Flutter analyze", "flutter", "flutter_analyze"),
    ("Dart format", "flutter", "dart_format"),
    ("Flutter VM tests", "flutter", "flutter_test"),
    ("Web import smoke tests", "web", "flutter_web_test"),
    ("Production web build", "web", "web_build"),
    ("Web build output", "web", "web_build_output"),
    ("Edge Function imports", "edge", "edge_imports"),
    ("Deno lint", "edge", "deno_lint"),
    ("Deno test step", "edge", "deno_test"),
    ("Edge Function deploy count", "edge", "edge_deploy_count"),
    ("Caption transcoder tests", "caption", "caption_test"),
    ("SQL migration quoting", "migration", "migration_quoting"),
)
OUTCOMES = {
    "success": "✅ success",
    "failure": "❌ failure",
    "cancelled": "⚠️ cancelled",
    "skipped": "— skipped",
}


def render_summary(steps):
    scopes = steps.get("changes", {}).get("outputs", {})
    lines = [
        "## CI check outcomes",
        "",
        "| Check | Scope selected | Actual step outcome |",
        "| --- | --- | --- |",
    ]
    for label, scope, step_id in CHECKS:
        selected = scopes.get(scope, "")
        if selected not in ("true", "false"):
            selected = "unknown"
        outcome = steps.get(step_id, {}).get("outcome", "")
        result = OUTCOMES.get(outcome, "— not reported")
        lines.append(f"| {label} | {selected} | {result} |")
    lines.extend([
        "",
        "Scope selection is not proof of execution. Skipped, cancelled, and "
        "unreported checks are not passes. Production web builds are intentionally "
        "skipped in workflow_call runs because the caller owns the build.",
        "",
    ])
    return "\n".join(lines)


def main():
    steps = json.loads(os.environ["CI_STEPS_JSON"])
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as output:
        output.write(render_summary(steps))


if __name__ == "__main__":
    main()
