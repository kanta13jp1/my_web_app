#!/usr/bin/env python3
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import echo_pump_dev_checks as checks


class DevChecksTest(unittest.TestCase):
    def test_same_format_analyze_and_test_targets_and_audio_gate_survive_grouping(self):
        baseline = checks.load_commands()
        grouped = checks.grouped_commands(baseline)
        self.assertEqual(len(grouped), 4)
        self.assertEqual(len(baseline), 13)
        for prefix in checks.PREFIXES:
            expected = {p for c in baseline if c[:len(prefix)] == list(prefix)
                        for p in c[len(prefix):]}
            actual = [p for c in grouped if c[:len(prefix)] == list(prefix)
                      for p in c[len(prefix):]]
            self.assertEqual(set(actual), expected)
            self.assertEqual(len(actual), len(set(actual)))
        self.assertEqual(grouped.count(checks.AUDIO), 1)
        self.assertEqual(len(grouped[-1][2:]), 9)

    def test_missing_check_categories_and_unknown_commands_are_rejected(self):
        for commands in ([], [checks.AUDIO], [['echo', 'skipped']],
                         [c for c in checks.load_commands() if c != checks.AUDIO]):
            with self.subTest(commands=commands), self.assertRaises(ValueError):
                checks.grouped_commands(commands)

    def test_failure_stops_remaining_checks_and_preserves_failure_report(self):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / 'result.json'
            with patch.object(checks.subprocess, 'run') as run:
                run.return_value.returncode = 9
                self.assertEqual(checks.run_checks('grouped', Path(directory), report), 9)
                self.assertEqual(run.call_count, 1)
            data = json.loads(report.read_text())
            self.assertEqual(data['result'], 'failure')
            self.assertEqual(data['commands'][0]['returncode'], 9)

    def test_success_runs_every_check_without_a_shell(self):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / 'result.json'
            with patch.object(checks.subprocess, 'run') as run:
                run.return_value.returncode = 0
                self.assertEqual(checks.run_checks('grouped', Path(directory), report), 0)
                self.assertEqual(run.call_count, 4)
                self.assertTrue(all('shell' not in call.kwargs for call in run.call_args_list))
            self.assertEqual(json.loads(report.read_text())['result'], 'success')

    def test_pr_always_keeps_build_and_browser_checks(self):
        workflow = (checks.ROOT / '.github/workflows/echo-pump-prototype.yml').read_text()
        condition = "if: github.event_name != 'workflow_dispatch' || inputs.profile != 'quick'"
        for name in ('Build isolated browser fixture', 'Install browser testing tools',
                     'Play on desktop and mobile'):
            section = workflow.split('      - name: ' + name + '\n', 1)[1].split('      - ', 1)[0]
            self.assertIn(condition, section)
        self.assertIn('Verify exact manual source', workflow)
        self.assertIn('if: github.event_name == \'workflow_dispatch\'', workflow)
        self.assertIn('include-hidden-files: true', workflow)


if __name__ == '__main__':
    unittest.main()
