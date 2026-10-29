import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

import cloud_release_5925 as release
import cloud_ci_handoff as handoff


class ReleaseTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.journal = Path(self.temp.name) / "pending.json"
        self.calls = []

    def slot(self, action, token=None):
        self.calls.append(("slot", action, token))
        if action == "request":
            return {"result": "queued"}
        if action in ("acquire", "renew"):
            return {"result": "acquired" if action == "acquire" else "renewed", "state": {"owner": {"task": release.TASK, "token": "fake"}}}
        return {"result": "released"}

    def test_success_returns_exact_id_and_nonce(self):
        operation = "a" * 32
        def cmd(args, data=None):
            self.calls.append(("send", data))
            return 0, json.dumps({"workflow_run_id": 123}), ""
        def identify(run_id, nonce):
            self.assertEqual((run_id, nonce), (123, operation))
            return {"html_url": "https://example.invalid/run"}
        with patch.object(release, "slot", self.slot), patch.object(release, "check_remote"), \
             patch.object(release, "command", cmd), patch.object(release, "identify_run", identify), \
             patch.object(release.secrets, "token_hex", return_value=operation), redirect_stdout(io.StringIO()) as output:
            self.assertEqual(release.do_execute(self.journal), 0)
        sent = [x for x in self.calls if x[0] == "send"]
        self.assertEqual(len(sent), 1)
        self.assertTrue(sent[0][1]["return_run_details"])
        self.assertEqual(sent[0][1]["inputs"]["operation_id"], operation)
        self.assertEqual(json.loads(output.getvalue())["run_id"], 123)
        self.assertEqual(json.loads(self.journal.read_text())["status"], "pending_or_unknown")
        self.assertEqual(self.calls[-1], ("slot", "release", "fake"))

    def test_timeout_remains_unknown_and_second_attempt_never_sends(self):
        def timeout(args, data=None):
            self.calls.append(("send", data))
            raise release.Blocked("unknown")
        with patch.object(release, "slot", self.slot), patch.object(release, "check_remote"), \
             patch.object(release, "command", timeout):
            with self.assertRaises(release.Blocked):
                release.do_execute(self.journal)
            with self.assertRaisesRegex(release.Blocked, "journal"):
                release.do_execute(self.journal)
        self.assertEqual(len([x for x in self.calls if x[0] == "send"]), 1)
        self.assertTrue(self.journal.exists())

    def test_waiting_fifo_never_sends(self):
        def waiting(action, token=None):
            return {"result": "queued" if action == "request" else "waiting"}
        with patch.object(release, "slot", waiting), patch.object(release, "command") as send:
            with self.assertRaisesRegex(release.Blocked, "not acquired"):
                release.do_execute(self.journal)
        send.assert_not_called()
        self.assertFalse(self.journal.exists())

    def test_wrong_identity_never_claims_success(self):
        for field, value in (("head_sha", "0" * 40), ("head_branch", "main"),
                             ("display_title", "someone else"), ("event", "push")):
            run = {"id": 123, "head_sha": release.HEAD, "head_branch": release.BRANCH,
                   "event": "workflow_dispatch", "display_title": "PR5925 release operation " + "a" * 32}
            run[field] = value
            with self.subTest(field=field), patch.object(release, "gh_json", return_value=run):
                with self.assertRaises(release.Blocked):
                    release.identify_run(123, "a" * 32)

    def test_unknown_group_fails_and_404_means_empty(self):
        with patch.object(release, "command", return_value=(1, "", "bad")):
            with self.assertRaises(release.Blocked):
                release.check_group()
        with patch.object(release, "command", return_value=(1, "HTTP/2.0 404 Not Found\r\n", "")):
            release.check_group()
        with patch.object(release, "command", return_value=(0, 'HTTP/2.0 200 OK\r\n\r\n{"total_count":1,"group_members":[{}]}', "")):
            with self.assertRaises(release.Blocked):
                release.check_group()


    def test_remote_preflight_and_rejections(self):
        endpoint = release.API
        responses = {
            endpoint + "/actions/workflows/" + release.WORKFLOW: {"state": "active", "path": ".github/workflows/" + release.WORKFLOW},
            endpoint + "/branches/" + release.BRANCH: {"protected": False, "commit": {"sha": release.HEAD}},
            endpoint + "/rules/branches/" + release.BRANCH: [],
            endpoint + "/git/commits/" + release.HEAD: {"tree": {"sha": release.TREE}, "parents": [{"sha": release.PARENT}]},
            endpoint + "/compare/" + release.BASE + "..." + release.HEAD: {"files": [{"filename": p, "sha": h} for p, h in release.CHANGED.items()]},
            endpoint + "/pulls/5925": {"merged": True, "merge_commit_sha": release.MERGE},
            endpoint + "/actions/runs?branch=" + release.BRANCH + "&per_page=100": {"total_count": 0, "workflow_runs": []},
        }
        class FakeResponse(io.BytesIO):
            status = 200
            def __enter__(self): return self
            def __exit__(self, *args): self.close()
        def live(*args, **kwargs):
            return FakeResponse(json.dumps({"commit": release.BASE}).encode())
        def fakegh(path): return responses[path]
        with patch.object(release, "gh_json", fakegh), patch.object(release, "check_group"), \
             patch.object(release.urllib.request, "urlopen", live), \
             patch.object(release, "command", return_value=(0, "false", "")):
            release.check_remote()
            branch_path = endpoint + "/branches/" + release.BRANCH
            for bad in (None, True):
                responses[branch_path]["protected"] = bad
                with self.subTest(protected=bad), self.assertRaises(release.Blocked):
                    release.check_remote()
            responses[branch_path]["protected"] = False
            responses[endpoint + "/rules/branches/" + release.BRANCH] = [{"name": "protected"}]
            with self.assertRaises(release.Blocked):
                release.check_remote()
            responses[endpoint + "/rules/branches/" + release.BRANCH] = []
            responses[endpoint + "/git/commits/" + release.HEAD]["tree"]["sha"] = "0" * 40
            with self.assertRaises(release.Blocked):
                release.check_remote()
            responses[endpoint + "/git/commits/" + release.HEAD]["tree"]["sha"] = release.TREE
            cp = endpoint + "/compare/" + release.BASE + "..." + release.HEAD
            responses[cp]["files"].append({"filename": "extra", "sha": "x"})
            with self.assertRaises(release.Blocked):
                release.check_remote()
            responses[cp]["files"].pop()
            run_path = endpoint + "/actions/runs?branch=" + release.BRANCH + "&per_page=100"
            responses[run_path] = {"total_count": 1, "workflow_runs": [{"status": "queued"}]}
            with self.assertRaises(release.Blocked):
                release.check_remote()
            responses[run_path] = {"total_count": 1, "workflow_runs": []}
            with self.assertRaises(release.Blocked):
                release.check_remote()

    def test_failed_lease_renewal_never_dispatches(self):
        def invalid_renew(action, token=None):
            if action == "renew":
                return {"result": "waiting"}
            return self.slot(action, token)
        with patch.object(release, "slot", invalid_renew), patch.object(release, "check_remote"), \
             patch.object(release, "command") as send:
            with self.assertRaisesRegex(release.Blocked, "renewal"):
                release.do_execute(self.journal)
        send.assert_not_called()
        self.assertFalse(self.journal.exists())

    def test_legacy_cli_routes_only_explicit_release_switch(self):
        with patch.object(release, "main", return_value=7) as m:
            self.assertEqual(handoff.main(["--release-5925"]), 7)
            m.assert_called_once_with([])


if __name__ == "__main__":
    unittest.main()
