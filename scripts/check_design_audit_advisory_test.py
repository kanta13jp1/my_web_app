"""Regression guard: only the optional Design audit may be non-blocking."""
from pathlib import Path
import re
import unittest


class AdvisoryPolicyTest(unittest.TestCase):
    def test_only_design_contract_is_nonblocking(self):
        workflow = (Path(__file__).resolve().parents[1] /
                    '.github/workflows/minimal-e2e-gate.yml').read_text(encoding='utf-8')
        blocks = re.split(r'(?m)^      - name: ', workflow)[1:]
        softened = [block.splitlines()[0] for block in blocks
                    if re.search(r'(?m)^        continue-on-error: true$', block)]
        self.assertEqual(softened, ['Check Design accessibility audit contract'])
        self.assertNotRegex(workflow, r'(?m)^    continue-on-error:')
        self.assertIn('python scripts/check_minimal_e2e_gate.py', workflow)
        self.assertIn('python scripts/check_no_verify_bypass.py', workflow)
        self.assertIn('python scripts/check_design_accessibility_audit.py', workflow)
        self.assertIn("always() && steps.design_audit.outcome == 'failure'", workflow)
        self.assertIn('This is not an accessibility pass.', workflow)


if __name__ == '__main__':
    unittest.main()
