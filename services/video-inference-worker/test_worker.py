from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from worker import (
    InferenceGpuMemoryExhausted,
    InferenceHostMemoryExhausted,
    InferenceProcessFailed,
    InferenceTimeout,
    LeaseLost,
    Settings,
    UploadFailed,
    WorkerApi,
    WorkerError,
    WorkerShutdown,
    build_wan_command,
    classify_inference_failure,
    inference_failure_summary,
    safe_worker_error_detail,
    sha256_file,
    validate_job,
    validate_output,
)


class WorkerContractTest(unittest.TestCase):
    def test_settings_prefers_mounted_worker_token_and_uses_l4_timeout(self) -> None:
        with tempfile.TemporaryDirectory() as root_value:
            root = Path(root_value)
            source = root / "source"
            model = root / "model"
            output = root / "output"
            source.mkdir()
            model.mkdir()
            (source / "generate.py").write_text("", encoding="utf-8")
            token_file = root / "worker-token"
            token_file.write_text("z" * 48, encoding="utf-8")
            environment = {
                "VIDEO_WORKER_URL": "https://example.test/functions/v1/video-worker-hub",
                "VIDEO_WORKER_TOKEN": "must-not-win" * 4,
                "VIDEO_WORKER_TOKEN_FILE": str(token_file),
                "VIDEO_WORKER_ID": "gpu-worker-01",
                "WAN_SOURCE_DIR": str(source),
                "WAN_MODEL_DIR": str(model),
                "VIDEO_OUTPUT_DIR": str(output),
            }
            with patch.dict(os.environ, environment, clear=True):
                settings = Settings.from_env()

            self.assertEqual(settings.worker_token, "z" * 48)
            self.assertEqual(settings.generation_timeout_seconds, 3600)
            self.assertFalse(InferenceTimeout.retryable)

    def test_control_errors_do_not_consume_all_paid_job_attempts(self) -> None:
        self.assertFalse(WorkerError.retryable)
        self.assertTrue(UploadFailed.retryable)
        self.assertTrue(WorkerShutdown.retryable)

    def test_worker_error_detail_allows_codes_and_redacts_other_text(self) -> None:
        coded = WorkerError("worker_hub_http_500")
        unsafe = WorkerError("customer prompt or upstream response: private")

        self.assertEqual(safe_worker_error_detail(coded), "worker_hub_http_500")
        self.assertEqual(safe_worker_error_detail(unsafe), "inference_failed")

    def test_gcp_startup_mounts_secret_file_instead_of_token_environment(self) -> None:
        startup = (Path(__file__).parent / "gcp" / "startup.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("VIDEO_WORKER_TOKEN_FILE=/run/secrets/video-worker-token", startup)
        self.assertIn("dst=/run/secrets/video-worker-token,readonly", startup)
        self.assertNotIn('--env "VIDEO_WORKER_TOKEN=${token}"', startup)

    def test_gcp_startup_keeps_worker_stopped_until_gpu_is_ready(self) -> None:
        startup = (Path(__file__).parent / "gcp" / "startup.sh").read_text(
            encoding="utf-8"
        )

        early_stop = startup.index("systemctl disable --now video-worker.service")
        docker_restart = startup.index("systemctl restart docker")
        gpu_retry = startup.index('for gpu_attempt in $(seq 1 "${GPU_READY_ATTEMPTS}")')
        gpu_check = startup.index("assert torch.cuda.is_available()")
        worker_start = startup.rindex("systemctl start video-worker.service")

        self.assertLess(early_stop, docker_restart)
        self.assertLess(docker_restart, gpu_retry)
        self.assertLess(gpu_retry, gpu_check)
        self.assertLess(gpu_check, worker_start)
        self.assertIn('sleep "${GPU_READY_RETRY_SECONDS}"', startup)
        self.assertIn('if [[ "${gpu_ready}" != "true" ]]', startup)
        self.assertNotIn("systemctl enable --now video-worker.service", startup)

    def test_wan_patch_enables_cpu_blended_tiled_vae_decode(self) -> None:
        root = Path(__file__).parent
        dockerfile = (root / "Dockerfile").read_text(encoding="utf-8")
        vae_patch = (root / "patches" / "wan22-tiled-vae-decode.patch").read_text(
            encoding="utf-8"
        )

        self.assertIn("wan22-tiled-vae-decode.patch", dockerfile)
        self.assertIn("def decode_tiled", vae_patch)
        self.assertIn('device="cpu", dtype=torch.float32', vae_patch)
        self.assertIn("tile_size=32, tile_overlap=8", vae_patch)

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

    def test_inference_failure_is_classified_without_exposing_diagnostics(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            diagnostic = Path(root) / "diagnostic.log"
            diagnostic.write_text(
                "Namespace(prompt='private customer prompt') CUDA out of memory",
                encoding="utf-8",
            )
            memory_error = classify_inference_failure(1, diagnostic)
            process_error = classify_inference_failure(2, Path(root) / "missing.log")

        self.assertIsInstance(memory_error, InferenceGpuMemoryExhausted)
        self.assertFalse(memory_error.retryable)
        self.assertNotIn("private customer prompt", str(memory_error))
        self.assertIsInstance(process_error, InferenceProcessFailed)
        self.assertFalse(process_error.retryable)

    def test_diagnostic_preserves_structure_without_private_content(self) -> None:
        import json

        with tempfile.TemporaryDirectory() as root:
            diagnostic = Path(root) / "diagnostic.log"
            diagnostic.write_text(
                'Namespace(prompt="private customer prompt")\n'
                '  File "/opt/Wan2.2/generate.py", line 321, in generate\n'
                '    secret = "Bearer private-token"\n'
                '  File "/opt/customer-private-name.py", line 9, in run\n'
                'RuntimeError: https://example.test/?token=private-token\n',
                encoding="utf-8",
            )
            summary = inference_failure_summary(1, diagnostic)
        self.assertEqual(summary["exception_type"], "RuntimeError")
        self.assertEqual(summary["frames"], [{"file": "generate.py", "line": 321}])
        self.assertEqual(summary["return_code"], 1)
        self.assertNotIn("private", json.dumps(summary))
        self.assertNotIn("token", json.dumps(summary))

    def test_diagnostic_is_bounded_and_missing_evidence_is_explicit(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            diagnostic = Path(root) / "diagnostic.log"
            missing = inference_failure_summary(-9, diagnostic)
            diagnostic.write_text(
                'RuntimeError: old failure\n' + 'x' * 70000 + '\n' +
                '  File "/opt/Wan2.2/t5.py", line 12, in run\n' * 20 +
                'PrivateCustomerError: not an allowed class\n',
                encoding="utf-8",
            )
            summary = inference_failure_summary(2, diagnostic)
        self.assertFalse(missing["diagnostic_available"])
        self.assertTrue(summary["diagnostic_available"])
        self.assertEqual(summary["exception_type"], "unknown")
        self.assertEqual(len(summary["frames"]), 8)

    def test_sigkill_is_treated_as_memory_pressure(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            diagnostic = Path(root) / "diagnostic.log"
            diagnostic.write_bytes(b"")
            error = classify_inference_failure(-9, diagnostic)

        self.assertIsInstance(error, InferenceHostMemoryExhausted)

    def test_host_allocation_failure_is_classified_separately(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            diagnostic = Path(root) / "diagnostic.log"
            diagnostic.write_bytes(b"std::bad_alloc")
            error = classify_inference_failure(1, diagnostic)

        self.assertIsInstance(error, InferenceHostMemoryExhausted)

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

    def test_sha256_file_records_immutable_output_digest(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            output = Path(root) / "job.mp4"
            output.write_bytes(b"video")
            self.assertEqual(
                sha256_file(output),
                "0cab1c9617404faf2b24e221e189ca5945813e14d3f766345b09ca13bbe28ffc",
            )

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

    def test_worker_api_retries_transient_heartbeat_503(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            api = WorkerApi(self._settings(Path(root)))
            api.session.post = Mock(
                side_effect=[
                    Mock(
                        status_code=503,
                        json=Mock(return_value={"error": "worker_service_unavailable"}),
                    ),
                    Mock(
                        status_code=200,
                        json=Mock(
                            return_value={"success": True, "lease_active": True}
                        ),
                    ),
                ]
            )
            with patch("worker.time.sleep") as sleep:
                active = api.heartbeat(
                    "11111111-1111-4111-8111-111111111111",
                    "ab" * 32,
                )

            self.assertTrue(active)
            self.assertEqual(api.session.post.call_count, 2)
            sleep.assert_called_once_with(1.0)

    def test_worker_api_does_not_retry_non_transient_heartbeat_error(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            api = WorkerApi(self._settings(Path(root)))
            api.session.post = Mock(
                return_value=Mock(
                    status_code=400,
                    json=Mock(return_value={"error": "invalid_lease"}),
                )
            )
            with patch("worker.time.sleep") as sleep:
                with self.assertRaisesRegex(WorkerError, "worker_hub_http_400"):
                    api.heartbeat(
                        "11111111-1111-4111-8111-111111111111",
                        "ab" * 32,
                    )

            self.assertEqual(api.session.post.call_count, 1)
            sleep.assert_not_called()

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
            _, complete_kwargs = api.call.call_args_list[1]
            self.assertEqual(complete_kwargs["output_size_bytes"], 5)
            self.assertEqual(
                complete_kwargs["output_sha256"],
                "0cab1c9617404faf2b24e221e189ca5945813e14d3f766345b09ca13bbe28ffc",
            )

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
