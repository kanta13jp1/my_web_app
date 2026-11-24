"""Offline YouTube script tests: no OAuth, network, recording, or rendering."""
import argparse
import builtins
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch


SCRIPTS = Path(__file__).resolve().parents[2] / ".agents/skills/youtube-video-pipeline/scripts"


def load(name):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


media = load("media_pipeline")
release = load("youtube_release")
content = load("ai_university_content")


class MediaTests(unittest.TestCase):
    def test_narration_utf8_bom_and_paragraph_alignment(self):
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / "日本語 narration.txt"
            script.write_text("最初の行\n続き\n\n次の段落\n", encoding="utf-8-sig")
            paragraphs = media.read_paragraphs(script)
            self.assertEqual(paragraphs, ["最初の行続き", "次の段落"])
            cues = media.align_cues(paragraphs, 20.0, [10.0])
            self.assertEqual(cues[0]["end"], 10.0)
            self.assertEqual(cues[1]["start"], 10.0)
            self.assertGreater(cues[1]["end"], cues[1]["start"])
            output = Path(directory) / "captions.srt"
            media.write_srt(cues, output)
            self.assertIn("00:00:10,000", output.read_text(encoding="utf-8"))
            script.write_text("  ", encoding="utf-8")
            with self.assertRaises(media.PipelineError):
                media.read_paragraphs(script)

    def test_boundaries_are_ordered_unique_and_fall_back_without_pauses(self):
        self.assertEqual(media.choose_boundaries([3, 7], [2, 3.1, 6.9, 9]), [3.1, 6.9])
        self.assertEqual(media.choose_boundaries([3, 7], [5]), [3, 7])
        self.assertEqual(media.srt_time(59.9996), "00:01:00,000")
        self.assertEqual(media.split_caption("一行目|二行目"), ["一行目", "二行目"])


class ReleaseTests(unittest.TestCase):
    def test_help_works_without_google_packages(self):
        real_import = builtins.__import__
        def import_without_google(name, *args, **kwargs):
            if name.startswith("google"):
                raise ImportError("deliberately unavailable")
            return real_import(name, *args, **kwargs)
        with patch("builtins.__import__", side_effect=import_without_google), patch.object(sys, "argv", ["youtube_release.py", "--help"]), contextlib.redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as exit_result:
            load("youtube_release").main()
        self.assertEqual(exit_result.exception.code, 0)

    def test_confirmations_fail_before_api_access(self):
        with patch.object(release, "youtube_client") as client:
            with self.assertRaises(release.ReleaseError):
                release.cmd_publish(argparse.Namespace(video_id="abcdefghijk", confirm_public="other"))
            with tempfile.TemporaryDirectory() as directory:
                video = Path(directory) / "video.mp4"
                video.touch()
                with self.assertRaises(release.ReleaseError):
                    release.cmd_upload_private(argparse.Namespace(file=str(video), confirm_upload="other.mp4"))
            client.assert_not_called()

    def test_channel_and_ownership_must_match(self):
        youtube = MagicMock()
        youtube.channels.return_value.list.return_value.execute.return_value = {"items": [{"id": "owner", "snippet": {"customUrl": "@Example"}}]}
        self.assertEqual(release.verify_channel(youtube, "example")["id"], "owner")
        with self.assertRaises(release.ReleaseError):
            release.verify_channel(youtube, "different")
        with self.assertRaises(release.ReleaseError):
            release.verify_video_ownership({"snippet": {"channelId": "other"}}, {"id": "owner"})

    def test_private_upload_sets_private_and_checks_ownership(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            video = root / "video.mp4"
            video.touch()
            description = root / "description.txt"
            description.write_text("説明", encoding="utf-8")
            args = argparse.Namespace(file=str(video), confirm_upload=video.name, title="Title", description_file=str(description), token_file=str(root / "unused.json"), expected_handle="@example", tags="a, b", category="27", language="ja", thumbnail=None, timeout=1)
            youtube = MagicMock()
            youtube.videos.return_value.insert.return_value.next_chunk.return_value = (None, {"id": "abcdefghijk"})
            verified = {"snippet": {"channelId": "owner"}, "status": {"privacyStatus": "private", "uploadStatus": "processed"}}
            with patch.object(release, "local_video_probe", return_value={}), patch.object(release, "youtube_client", return_value=youtube), patch.object(release, "verify_channel", return_value={"id": "owner"}), patch.object(release, "MediaFileUpload", create=True), patch.object(release, "wait_for_status", return_value=verified) as wait, patch.object(release, "emit"):
                release.cmd_upload_private(args)
            body = youtube.videos.return_value.insert.call_args.kwargs["body"]
            self.assertEqual(body["status"]["privacyStatus"], "private")
            self.assertEqual(body["snippet"]["tags"], ["a", "b"])
            self.assertEqual(wait.call_args.kwargs["privacy"], "private")

    def test_probe_rejects_incompatible_video(self):
        streams = [{"codec_name": "h264", "width": 1280, "height": 720}, {"codec_name": "aac"}]
        result = subprocess.CompletedProcess([], 0, json.dumps({"streams": streams}), "")
        with patch.object(release.subprocess, "run", return_value=result), self.assertRaises(release.ReleaseError):
            release.local_video_probe(Path("unused.mp4"))

    def test_public_status_omits_readonly_and_scheduling_fields(self):
        result = release.writable_public_status({"uploadStatus": "processed", "publishAt": "future", "containsSyntheticMedia": True, "embeddable": False})
        self.assertEqual(result["privacyStatus"], "public")
        self.assertTrue(result["containsSyntheticMedia"])
        self.assertFalse(result["embeddable"])
        self.assertNotIn("publishAt", result)
        self.assertNotIn("uploadStatus", result)


class ContentTests(unittest.TestCase):
    def test_url_formats_and_untrusted_hosts(self):
        video_id = "-bcdefghijk"
        for url in (f"https://youtu.be/{video_id}", f"https://www.youtube.com/watch?v={video_id}", f"https://youtube-nocookie.com/embed/{video_id}", f"https://youtube.com/shorts/{video_id}"):
            with self.subTest(url=url):
                self.assertEqual(content.youtube_video_id(url), video_id)
        for url in ("http://youtu.be/abcdefghijk", "https://youtube.com.evil.test/watch?v=abcdefghijk", "https://youtu.be/short"):
            with self.subTest(url=url), self.assertRaises(content.ContentError):
                content.youtube_video_id(url)

    def test_identifiers_reject_path_escape_and_sql_literals_remain_data(self):
        with self.assertRaises(content.ContentError):
            content.validate_identifier("category", "../escape")
        self.assertEqual(content.sql_string("user's title"), "'user''s title'")
        self.assertEqual(content.dollar_quote("$content$ example"), "$content1$$content$ example$content1$")


if __name__ == "__main__":
    unittest.main()
