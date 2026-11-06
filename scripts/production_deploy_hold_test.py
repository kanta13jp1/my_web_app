import ast
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
GUARD = "vars.PRODUCTION_DEPLOY_HOLD == 'false'"


def job_condition(text, job):
    section = re.split(r"\n  (?=\S)", text.split("\n  " + job + ":\n", 1)[1], maxsplit=1)[0]
    return next(line.strip()[4:] for line in section.splitlines() if line.startswith("    if: "))


def model_deploy_condition(condition, *, event, result, hold, cancelled):
    # Only this candidate's bounded ASCII/string subset is modeled. Actions
    # compares strings case-insensitively; this is not an Actions interpreter.
    assert condition.startswith("${{ ") and condition.endswith(" }}")
    expr = condition[4:-3]
    expr = expr.replace("!cancelled()", repr(not cancelled))
    expr = expr.replace("vars.PRODUCTION_DEPLOY_HOLD", repr(hold.casefold()))
    expr = expr.replace("github.event_name", repr(event.casefold()))
    expr = expr.replace("needs.ci.result", repr(result.casefold()))
    expr = expr.replace("&&", " and ").replace("||", " or ")
    tree = ast.parse(expr, mode="eval")
    allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Or,
               ast.Compare, ast.Eq, ast.Constant, ast.Load)
    if not all(isinstance(node, allowed) for node in ast.walk(tree)):
        raise ValueError("unsupported expression")
    return eval(compile(tree, "<workflow-condition>", "eval"), {"__builtins__": {}}, {})


class ProductionHoldTests(unittest.TestCase):
    def test_all_production_jobs_require_explicit_release(self):
        for file, jobs in [("deploy-prod.yml", ("ci", "deploy", "notify")), ("deploy-core-hub.yml", ("deploy",))]:
            text = (ROOT / ".github/workflows" / file).read_text(encoding="utf-8")
            for job in jobs:
                condition = job_condition(text, job)
                expected = {
                    ("deploy-prod.yml", "ci"): "github.event_name == 'workflow_dispatch' && " + GUARD,
                    ("deploy-prod.yml", "deploy"): "${{ !cancelled() && " + GUARD + " && ((github.event_name == 'push' && needs.ci.result == 'skipped') || (github.event_name == 'workflow_dispatch' && needs.ci.result == 'success')) }}",
                    ("deploy-prod.yml", "notify"): "always() && " + GUARD,
                    ("deploy-core-hub.yml", "deploy"): GUARD + " && github.event_name == 'push' && github.ref == 'refs/heads/main'",
                }
                self.assertEqual(condition, expected[(file, job)])

    def test_deploy_condition_event_ci_hold_and_cancel_matrix(self):
        text = (ROOT / ".github/workflows/deploy-prod.yml").read_text(encoding="utf-8")
        expression = job_condition(text, "deploy")
        for event in ("push", "workflow_dispatch", "pull_request"):
            for result in ("success", "skipped", "failure", "cancelled", "unknown"):
                for hold in ("false", "False", "FALSE", "true", "", "garbage"):
                    for cancelled in (False, True):
                        actual = model_deploy_condition(expression, event=event, result=result, hold=hold, cancelled=cancelled)
                        expected = not cancelled and hold.casefold() == "false" and (
                            (event == "push" and result == "skipped") or
                            (event == "workflow_dispatch" and result == "success"))
                        self.assertEqual(actual, expected, (event, result, hold, cancelled))

    def test_hold_value_comparison_is_case_insensitive(self):
        # GitHub expressions ignore case. This documents existing behavior,
        # including the fact that 'False' releases the hold; it is not strict.
        for value in ("", "true", "TRUE", "0", "garbage"):
            self.assertNotEqual(value.casefold(), "false")
        for value in ("false", "False", "FALSE"):
            self.assertEqual(value.casefold(), "false")

    def test_deployment_status_has_no_environment_or_external_actions(self):
        text = (ROOT / ".github/workflows/deploy-prod.yml").read_text(encoding="utf-8")
        section = text.split("\n  deployment-status:\n", 1)[1].split("\n  # -----------------------------------------------------------------", 1)[0]
        self.assertIn("needs: [ci, deploy]", section)
        self.assertIn("if: always() && (needs.deploy.result == 'skipped' || needs.deploy.result == 'cancelled')", section)
        self.assertIn("permissions: {}", section)
        for forbidden in ("environment:", "secrets.", "uses:", "curl ", "wget ", "gh api"):
            self.assertNotIn(forbidden, section)

    def test_status_summary_script_synthetic_states(self):
        import os
        import shutil
        import subprocess
        import tempfile

        text = (ROOT / ".github/workflows/deploy-prod.yml").read_text(encoding="utf-8")
        section = text.split("\n  deployment-status:\n", 1)[1].split("\n  # -----------------------------------------------------------------", 1)[0]
        body = section.split("        run: |\n", 1)[1]
        lines = body.splitlines()
        self.assertTrue(lines and all(not line or line.startswith("          ") for line in lines))
        script = "\n".join(line[10:] for line in lines) + "\n"
        git_bash = pathlib.Path("C:/Program Files/Git/bin/bash.exe")
        bash = str(git_bash) if git_bash.is_file() else shutil.which("bash")
        self.assertIsNotNone(bash, "bash is required for the synthetic summary test")
        cases = [
            ("skipped", "skipped", "push", "true", "配信保留が解除されていません。"),
            ("skipped", "failure", "workflow_dispatch", "false", "手動配信に必要な CI が成功していません。"),
            ("skipped", "skipped", "workflow_dispatch", "False", "手動配信に必要な CI が成功していません。"),
            ("skipped", "skipped", "push", "false", "配信条件または実行状態を確認してください。"),
            ("cancelled", "success", "workflow_dispatch", "false", "一部が反映された可能性"),
            ("cancelled", "skipped", "push", "true", "配信先の状態は未確定"),
            ("success", "success", "workflow_dispatch", "false", ""),
            ("failure", "failure", "workflow_dispatch", "false", ""),
        ]
        for deploy, ci, event, hold, expected in cases:
            with self.subTest(deploy=deploy, ci=ci, event=event, hold=hold):
                with tempfile.TemporaryDirectory() as temp:
                    summary = pathlib.Path(temp) / "summary.txt"
                    env = {"DEPLOY_RESULT": deploy, "CI_RESULT": ci, "EVENT_NAME": event,
                           "HOLD_VALUE": hold, "GITHUB_STEP_SUMMARY": summary.as_posix()}
                    if os.name == "nt":
                        env["SYSTEMROOT"] = os.environ.get("SYSTEMROOT", "C:/Windows")
                    subprocess.run([bash, "--noprofile", "--norc", "-c", script], env=env,
                                   check=True, capture_output=True, timeout=10)
                    result = summary.read_text(encoding="utf-8")
                    self.assertIn(expected, result)
                    if deploy in ("success", "failure"):
                        self.assertEqual(result, "")
                    if deploy == "cancelled":
                        self.assertNotIn("未実行", result)

    def test_no_dispatch_override_and_visible_hold(self):
        text = (ROOT / ".github/workflows/deploy-prod.yml").read_text(encoding="utf-8")
        self.assertIn("if: vars.PRODUCTION_DEPLOY_HOLD != 'false'", text)
        inputs = text.split("  workflow_dispatch:", 1)[1].split("\nconcurrency:", 1)[0]
        self.assertNotIn("PRODUCTION_DEPLOY_HOLD", inputs)
        status = text.split("\n  hold-status:", 1)[1]
        self.assertNotIn("secrets.", status)
        self.assertNotIn("environment:", status)


if __name__ == "__main__":
    unittest.main()
