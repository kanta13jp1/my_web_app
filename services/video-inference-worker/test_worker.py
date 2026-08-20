from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from worker import (
    LeaseLost,
    Settings,
    WorkerApi,
    build_wan_command,
    validate_job,
    validate_output,
)


class WorkerContractTest(unittest.TestCase):
    def test_valid_job_contract_and_landscape_command(self) -> None:
        job = {
            "job_id": "11111111-1111-4111-8111-111111111111",
            "lease_token": "ab" * 32,
            "model_key": "studio-video-v1",
            "prompt": "A paper city wakes at sunrise",
            "duration_seconds": 5,
            "aspect_ratio": "16:9",
            "resolution": "720p",
        }
        job_id, lease_token, prompt = validate_job(job)
        self.assertEqual(job_id, job["job_id"])
        self.assertEqual(lease_token, job["lease_token"])
        self.assertEqual(prompt, job["prompt"])

        with tempfile.TemporaryDirectory() as root:
            settings = self._settings(Path(root))
            with patch("worker.secrets.randbelow", return_value=123):
                command = build_wan_command(
                    settings, job, settings.output_dir / "job.mp4"
                )
        self.assertIn("1280*704", command)
        self.assertIn("121", command)
        self.assertNotIn(job["prompt"], command)

    def test_portrait_uses_official_ti2v_dimensions(self) -> None:
        job = {"aspect_ratio": "9:16"}
        with tempfile.TemporaryDirectory() as root:
            settings = self._settings(Path(root))
            command = build_wan_command(
                settings, job, settings.output_dir / "job.mp4"
            )
        self.assertIn("704*1280", command)
        self.assertIn("ti2v-5B", command)

    def test_rejects_an_unsupported_runtime_contract(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "unsupported_model"):
            validate_job(
                {
                    "job_id": "11111111-1111-4111-8111-111111111111",
                    "lease_token": "ab" * 32,
                    "model_key": "external-provider-model",
                    "prompt": "A paper city wakes at sunrise",
                    "duration_seconds": 5,
                    "aspect_ratio": "16:9",
                    "resolution": "720p",
                }
            )

    def test_output_contract_checks_codec_dimensions_rate_and_duration(self) -> None:
        probe = Mock(
            returncode=0,
            stdout=(
                b'{"streams":[{"codec_name":"h264","codec_type":"video",'
                b'"width":1280,"height":704,"r_frame_rate":"24/1",'
                b'"nb_frames":"121","duration":"5.041667"}],'
                b'"format":{"duration":"5.041667"}}'
            ),
        )
        with tempfile.TemporaryDirectory() as root:
            output = Path(root) / "job.mp4"
            output.write_bytes(b"bounded-video")
            with patch("worker.subprocess.run", return_value=probe):
                validate_output(output, {"aspect_ratio": "16:9"})

            invalid_dimensions = Mock(
                returncode=0,
                stdout=probe.stdout.replace(b'"width":1280', b'"width":704'),
            )
            with patch("worker.subprocess.run", return_value=invalid_dimensions):
                with self.assertRaisesRegex(RuntimeError, "dimensions"):
                    validate_output(output, {"aspect_ratio": "16:9"})

    def test_worker_api_maps_expired_lease_without_retrying_the_job(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            api = WorkerApi(self._settings(Path(root)))
            api.session.post = Mock(
                return_value=Mock(
                    status_code=409,
                    json=Mock(return_value={"error": "lease_lost"}),
                )
            )
            with self.assertRaises(LeaseLost):
                api.call(
                    "complete",
                    job_id="11111111-1111-4111-8111-111111111111",
                    lease_token="ab" * 32,
                )

    def test_ambiguous_upload_is_completed_when_storage_has_the_object(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            api = WorkerApi(self._settings(Path(root)))
            api.call = Mock(
                side_effect=[
                    {"upload_url": "https://storage.test/upload", "max_bytes": 100},
                    {"success": True},
                ]
            )
            output = Path(root) / "output" / "job.mp4"
            output.write_bytes(b"video")
            with patch(
                "worker.requests.put",
                return_value=Mock(status_code=409),
            ):
                api.upload_and_complete(
                    "11111111-1111-4111-8111-111111111111",
                    "ab" * 32,
                    output,
                )
            self.assertEqual(api.call.call_count, 2)

    @staticmethod
    def _settings(root: Path) -> Settings:
        source = root / "source"
        model = root / "model"
        output = root / "output"
        source.mkdir()
        model.mkdir()
        output.mkdir()
        (source / "generate.py").write_text("", encoding="utf-8")
        return Settings(
            worker_url="https://example.test/functions/v1/video-worker-hub",
            worker_token="x" * 32,
            worker_id="gpu-worker-01",
            wan_source_dir=source,
            wan_model_dir=model,
            output_dir=output,
            poll_seconds=5,
            heartbeat_seconds=60,
            generation_timeout_seconds=1800,
            idle_exit_seconds=600,
        )


if __name__ == "__main__":
    unittest.main()
