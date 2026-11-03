from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github" / "workflows" / "blog-draft.yml"


class BlogDraftWorkflowTest(unittest.TestCase):
    def test_commits_drafts_through_a_protected_branch_pr(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")

        self.assertIn("pull-requests: write", workflow)
        self.assertIn('BRANCH="blog-draft/${GITHUB_RUN_ID}-${TARGET_DATE}"', workflow)
        self.assertIn('git push origin "HEAD:refs/heads/$BRANCH"', workflow)
        self.assertIn("gh pr create", workflow)
        self.assertNotIn("git push origin HEAD:main", workflow)


if __name__ == "__main__":
    unittest.main()
