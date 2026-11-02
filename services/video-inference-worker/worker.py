"""First-party pull worker for paid text-to-video generation."""

from __future__ import annotations

import hashlib
import json
import os
import re
import secrets
import signal
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import requests

MAX_VIDEO_BYTES = 50 * 1024 * 1024
EXPECTED_MODEL_KEY = "studio-video-v1"
EXPECTED_FRAME_COUNT = 121
EXPECTED_FRAME_RATE = 24.0
EXPECTED_DURATION_SECONDS = EXPECTED_FRAME_COUNT / EXPECTED_FRAME_RATE
JOB_ID_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
    re.IGNORECASE,
)
WORKER_ID_RE = re.compile(r"^[A-Za-z0-9._-]{3,80}$")
LEASE_TOKEN_RE = re.compile(r"^[a-f0-9]{64}$", re.IGNORECASE)
SAFE_ERROR_DETAIL_RE = re.compile(r"^[a-z0-9_]{1,120}$")
TRANSIENT_HUB_STATUS_CODES = frozenset({408, 429, 500, 502, 503, 504})
HEARTBEAT_RETRY_DELAYS_SECONDS = (1.0, 2.0, 4.0)


class WorkerError(RuntimeError):
    error_code = "inference_failed"
    retryable = False


class LeaseLost(WorkerError):
    error_code = "lease_lost"
    retryable = False


class InferenceTimeout(WorkerError):
    error_code = "inference_timeout"
    retryable = False


class InferenceGpuMemoryExhausted(WorkerError):
    error_code = "inference_gpu_memory_exhausted"
    retryable = False


class InferenceHostMemoryExhausted(WorkerError):
    error_code = "inference_host_memory_exhausted"
    retryable = False


class InferenceProcessFailed(WorkerError):
    error_code = "inference_process_failed"
    retryable = False


class OutputInvalid(WorkerError):
    error_code = "output_invalid"


class UploadFailed(WorkerError):
    error_code = "upload_failed"
    retryable = True


class WorkerShutdown(WorkerError):
    error_code = "worker_shutdown"
    retryable = True


@dataclass(frozen=True)
class Settings:
    worker_url: str
    worker_token: str
    worker_id: str
    wan_source_dir: Path
    wan_model_dir: Path
    output_dir: Path
    poll_seconds: float
    heartbeat_seconds: float
    generation_timeout_seconds: int
    idle_exit_seconds: int

    @classmethod
    def from_env(cls) -> "Settings":
        worker_url = os.environ.get("VIDEO_WORKER_URL", "").strip()
        worker_token_file = os.environ.get("VIDEO_WORKER_TOKEN_FILE", "").strip()
        if worker_token_file:
            try:
                worker_token = Path(worker_token_file).read_text(encoding="utf-8").strip()
            except OSError as error:
                raise ValueError("VIDEO_WORKER_TOKEN_FILE is unreadable") from error
        else:
            worker_token = os.environ.get("VIDEO_WORKER_TOKEN", "").strip()
        worker_id = os.environ.get("VIDEO_WORKER_ID", "gpu-worker-01").strip()
        source_dir = Path(os.environ.get("WAN_SOURCE_DIR", "/opt/Wan2.2"))
        model_dir = Path(os.environ.get("WAN_MODEL_DIR", "/models/Wan2.2-TI2V-5B"))
        output_dir = Path(os.environ.get("VIDEO_OUTPUT_DIR", "/work/output"))
        poll_seconds = float(os.environ.get("VIDEO_POLL_SECONDS", "5"))
        heartbeat_seconds = float(os.environ.get("VIDEO_HEARTBEAT_SECONDS", "60"))
        timeout_seconds = int(os.environ.get("VIDEO_GENERATION_TIMEOUT_SECONDS", "3600"))
        idle_exit_seconds = int(os.environ.get("VIDEO_IDLE_EXIT_SECONDS", "600"))

        parsed = urlparse(worker_url)
        local_http = parsed.scheme == "http" and parsed.hostname in {
            "127.0.0.1",
            "localhost",
            "host.docker.internal",
        }
        if parsed.scheme != "https" and not local_http:
            raise ValueError("VIDEO_WORKER_URL must use HTTPS")
        if len(worker_token) < 32 or len(worker_token) > 256:
            raise ValueError("VIDEO_WORKER_TOKEN must contain 32-256 characters")
        if not WORKER_ID_RE.fullmatch(worker_id):
            raise ValueError("VIDEO_WORKER_ID is invalid")
        if not source_dir.is_dir() or not (source_dir / "generate.py").is_file():
            raise ValueError("WAN_SOURCE_DIR is not a Wan2.2 checkout")
        if not model_dir.is_dir():
            raise ValueError("WAN_MODEL_DIR does not exist")
        if not 2 <= poll_seconds <= 60:
            raise ValueError("VIDEO_POLL_SECONDS must be between 2 and 60")
        if not 30 <= heartbeat_seconds <= 300:
            raise ValueError("VIDEO_HEARTBEAT_SECONDS must be between 30 and 300")
        if not 600 <= timeout_seconds <= 3600:
            raise ValueError(
                "VIDEO_GENERATION_TIMEOUT_SECONDS must be between 600 and 3600"
            )
        if not 300 <= idle_exit_seconds <= 1800:
            raise ValueError("VIDEO_IDLE_EXIT_SECONDS must be between 300 and 1800")
        output_dir.mkdir(parents=True, exist_ok=True)
        return cls(
            worker_url=worker_url,
            worker_token=worker_token,
            worker_id=worker_id,
            wan_source_dir=source_dir.resolve(),
            wan_model_dir=model_dir.resolve(),
            output_dir=output_dir.resolve(),
            poll_seconds=poll_seconds,
            heartbeat_seconds=heartbeat_seconds,
            generation_timeout_seconds=timeout_seconds,
            idle_exit_seconds=idle_exit_seconds,
        )


class WorkerApi:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.session = requests.Session()
        self.session.headers.update(
            {
                "Authorization": f"Bearer {settings.worker_token}",
                "Content-Type": "application/json",
                "User-Agent": "omocha-video-worker/1.0",
            }
        )

    def call(self, action: str, **payload: Any) -> dict[str, Any]:
        body = {"action": action, "worker_id": self.settings.worker_id, **payload}
        response = self.session.post(
            self.settings.worker_url,
            json=body,
            timeout=(10, 45),
        )
        try:
            result = response.json()
        except (requests.JSONDecodeError, ValueError) as error:
            raise WorkerError("worker_hub_invalid_response") from error
        if response.status_code >= 400:
            error_code = result.get("error") if isinstance(result, dict) else None
            if response.status_code == 409 and error_code == "lease_lost":
                raise LeaseLost("lease_lost")
            raise WorkerError(f"worker_hub_http_{response.status_code}")
        if not isinstance(result, dict) or result.get("error"):
            raise WorkerError("worker_hub_invalid_response")
        return result

    def claim(self) -> dict[str, Any] | None:
        value = self.call("claim").get("job")
        return value if isinstance(value, dict) else None

    def heartbeat(self, job_id: str, lease_token: str) -> bool:
        for attempt in range(len(HEARTBEAT_RETRY_DELAYS_SECONDS) + 1):
            try:
                return self.call(
                    "heartbeat", job_id=job_id, lease_token=lease_token
                ).get("lease_active") is True
            except (requests.RequestException, WorkerError) as error:
                status_errors = {
                    f"worker_hub_http_{status}"
                    for status in TRANSIENT_HUB_STATUS_CODES
                }
                is_transient = isinstance(error, requests.RequestException) or (
                    isinstance(error, WorkerError) and str(error) in status_errors
                )
                if not is_transient or attempt >= len(HEARTBEAT_RETRY_DELAYS_SECONDS):
                    raise
                delay = HEARTBEAT_RETRY_DELAYS_SECONDS[attempt]
                print(
                    f"worker hub heartbeat unavailable; retrying in {delay:g}s",
                    flush=True,
                )
                time.sleep(delay)

        raise RuntimeError("unreachable heartbeat retry state")

    def fail(
        self,
        job_id: str,
        lease_token: str,
        error_code: str,
        retryable: bool,
    ) -> None:
        self.call(
            "fail",
            job_id=job_id,
            lease_token=lease_token,
            error_code=error_code,
            retryable=retryable,
        )

    def upload_and_complete(
        self,
        job_id: str,
        lease_token: str,
        output_path: Path,
    ) -> None:
        prepared = self.call(
            "prepare_upload", job_id=job_id, lease_token=lease_token
        )
        upload_url = str(prepared.get("upload_url", ""))
        maximum = int(prepared.get("max_bytes", 0))
        size = output_path.stat().st_size
        digest = sha256_file(output_path)
        if not upload_url.startswith("https://") or not 0 < size <= maximum:
            raise UploadFailed("invalid_signed_upload")
        with output_path.open("rb") as video:
            response = requests.put(
                upload_url,
                data=video,
                headers={
                    "Content-Type": "video/mp4",
                    "Content-Length": str(size),
                    "Cache-Control": "max-age=3600",
                    "x-upsert": "false",
                },
                timeout=(10, 300),
            )
        if response.status_code >= 300:
            # A signed upload can finish at Storage while its response is lost,
            # or a retry can observe that the immutable object already exists.
            # Let the hub verify the exact object before scheduling a retry.
            try:
                self.call(
                    "complete",
                    job_id=job_id,
                    lease_token=lease_token,
                    output_size_bytes=size,
                    output_sha256=digest,
                )
                return
            except LeaseLost:
                raise
            except WorkerError as error:
                raise UploadFailed(
                    f"signed_upload_http_{response.status_code}"
                ) from error
        self.call(
            "complete",
            job_id=job_id,
            lease_token=lease_token,
            output_size_bytes=size,
            output_sha256=digest,
        )


def validate_job(job: dict[str, Any]) -> tuple[str, str, str]:
    job_id = str(job.get("job_id", ""))
    lease_token = str(job.get("lease_token", ""))
    prompt = str(job.get("prompt", "")).strip()
    if not JOB_ID_RE.fullmatch(job_id) or not LEASE_TOKEN_RE.fullmatch(lease_token):
        raise WorkerError("invalid_job_contract")
    if job.get("model_key") != EXPECTED_MODEL_KEY:
        raise WorkerError("unsupported_model")
    if job.get("duration_seconds") != 5 or job.get("resolution") != "720p":
        raise WorkerError("unsupported_video_options")
    if job.get("aspect_ratio") not in {"16:9", "9:16"}:
        raise WorkerError("unsupported_video_options")
    if not 3 <= len(prompt) <= 1000:
        raise WorkerError("invalid_prompt")
    return job_id, lease_token, prompt


def build_wan_command(
    settings: Settings,
    job: dict[str, Any],
    output_path: Path,
) -> list[str]:
    size = "1280*704" if job["aspect_ratio"] == "16:9" else "704*1280"
    return [
        sys.executable,
        "/app/run_wan.py",
        "--task",
        "ti2v-5B",
        "--size",
        size,
        "--frame_num",
        "121",
        "--ckpt_dir",
        str(settings.wan_model_dir),
        "--offload_model",
        "True",
        "--convert_model_dtype",
        "--t5_cpu",
        "--base_seed",
        str(secrets.randbelow(2**31 - 1)),
        "--save_file",
        str(output_path),
    ]


def classify_inference_failure(
    return_code: int,
    diagnostic_path: Path,
) -> WorkerError:
    """Classify a failed process without exposing its prompt-bearing output."""
    diagnostic_tail = b""
    try:
        with diagnostic_path.open("rb") as diagnostic:
            diagnostic.seek(0, os.SEEK_END)
            diagnostic.seek(max(0, diagnostic.tell() - (2 * 1024 * 1024)))
            diagnostic_tail = diagnostic.read().lower()
    except OSError:
        pass

    gpu_memory_markers = (
        b"cuda out of memory",
        b"torch.outofmemoryerror",
        b"cublas_status_alloc_failed",
    )
    host_memory_markers = (
        b"memoryerror",
        b"std::bad_alloc",
        b"cannot allocate memory",
    )
    sigkill = int(getattr(signal, "SIGKILL", 9))
    if any(marker in diagnostic_tail for marker in gpu_memory_markers):
        return InferenceGpuMemoryExhausted("inference_gpu_memory_exhausted")
    if return_code in {-sigkill, 128 + sigkill} or any(
        marker in diagnostic_tail for marker in host_memory_markers
    ):
        return InferenceHostMemoryExhausted("inference_host_memory_exhausted")
    return InferenceProcessFailed("inference_process_failed")


def safe_worker_error_detail(error: WorkerError) -> str:
    """Return only an allowlisted diagnostic code, never raw exception text."""
    detail = str(error).strip().lower()
    return detail if SAFE_ERROR_DETAIL_RE.fullmatch(detail) else error.error_code


def inference_failure_summary(return_code: int, diagnostic_path: Path) -> dict[str, Any]:
    """Keep bounded structural evidence; never retain exception messages or code."""
    summary: dict[str, Any] = {
        "event": "video_inference_diagnostic",
        "return_code": return_code,
        "exception_type": "unknown",
        "frames": [],
    }
    try:
        with diagnostic_path.open("rb") as diagnostic:
            diagnostic.seek(0, os.SEEK_END)
            diagnostic.seek(max(0, diagnostic.tell() - 65536))
            tail = diagnostic.read(65536).decode("utf-8", errors="replace")
    except OSError:
        summary["diagnostic_available"] = False
        return summary
    summary["diagnostic_available"] = True
    exception_types = {
        "RuntimeError", "ValueError", "TypeError", "AssertionError",
        "ImportError", "ModuleNotFoundError", "FileNotFoundError",
        "PermissionError", "OSError", "KeyError", "AttributeError",
        "NotImplementedError", "MemoryError", "OutOfMemoryError",
    }
    # Only fixed, shipped source names are emitted, never arbitrary paths.
    source_names = {
        "run_wan.py", "generate.py", "textimage2video.py", "text2video.py",
        "t5.py", "attention.py", "vae2_2.py", "model.py", "module.py",
        "serialization.py",
    }
    for line in tail.splitlines():
        exception = re.match(r"^(?:[a-zA-Z_][\w]*\.)*([A-Za-z]+Error):", line)
        if exception and exception[1] in exception_types:
            summary["exception_type"] = exception[1]
        frame = re.match(r'^  File "(/(?:app|opt)/[^"\r\n]+)", line ([0-9]{1,7}),', line)
        if frame:
            name = frame[1].rsplit("/", 1)[-1]
            if name in source_names:
                summary["frames"].append({"file": name, "line": int(frame[2])})
                summary["frames"] = summary["frames"][-8:]
    return summary


def generate_video(
    settings: Settings,
    api: WorkerApi,
    job: dict[str, Any],
    job_id: str,
    lease_token: str,
    prompt: str,
    shutdown_requested: "ShutdownFlag",
) -> Path:
    output_path = settings.output_dir / f"{job_id}.mp4"
    output_path.unlink(missing_ok=True)
    prompt_file: Path | None = None
    diagnostic_file: Any | None = None
    diagnostic_path: Path | None = None
    process: subprocess.Popen[bytes] | None = None
    try:
        print(f"preparing video inference {job_id}", flush=True)
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            prefix="video-prompt-",
            suffix=".txt",
            dir=settings.output_dir,
            delete=False,
        ) as temporary:
            temporary.write(prompt)
            prompt_file = Path(temporary.name)
        prompt_file.chmod(0o600)
        diagnostic_file = tempfile.NamedTemporaryFile(
            mode="w+b",
            prefix="video-diagnostic-",
            suffix=".log",
            dir=settings.output_dir,
            delete=False,
        )
        diagnostic_path = Path(diagnostic_file.name)
        diagnostic_path.chmod(0o600)
        environment = os.environ.copy()
        environment.update(
            {
                "WAN_SOURCE_DIR": str(settings.wan_source_dir),
                "VIDEO_PROMPT_FILE": str(prompt_file),
                "HF_HUB_OFFLINE": "1",
                "TRANSFORMERS_OFFLINE": "1",
            }
        )
        print(f"launching video inference {job_id}", flush=True)
        process = subprocess.Popen(
            build_wan_command(settings, job, output_path),
            cwd=settings.wan_source_dir,
            env=environment,
            stdin=subprocess.DEVNULL,
            stdout=diagnostic_file,
            stderr=subprocess.STDOUT,
            shell=False,
        )
        print(f"started video inference {job_id}", flush=True)
        started = time.monotonic()
        next_heartbeat = started + settings.heartbeat_seconds
        while process.poll() is None:
            if shutdown_requested.value:
                terminate(process)
                raise WorkerShutdown("worker_shutdown")
            now = time.monotonic()
            if now - started > settings.generation_timeout_seconds:
                terminate(process)
                raise InferenceTimeout("inference_timeout")
            if now >= next_heartbeat:
                if not api.heartbeat(job_id, lease_token):
                    terminate(process)
                    raise LeaseLost("lease_lost")
                elapsed_minutes = max(1, int((now - started) // 60))
                print(
                    f"video inference active {job_id}: {elapsed_minutes}m",
                    flush=True,
                )
                next_heartbeat = now + settings.heartbeat_seconds
            time.sleep(2)
        if process.returncode != 0:
            diagnostic_file.flush()
            summary = inference_failure_summary(process.returncode, diagnostic_path)
            summary["job_id"] = job_id
            # stdout is captured by the GCP worker service before raw diagnostics
            # are removed. No prompt, exception message, source line or token.
            print(json.dumps(summary, separators=(",", ":")), flush=True)
            failure = classify_inference_failure(
                process.returncode,
                diagnostic_path,
            )
            print(
                f"video inference exited {job_id}: {failure.error_code}",
                flush=True,
            )
            raise failure
        validate_output(output_path, job)
        return output_path
    finally:
        if process is not None and process.poll() is None:
            terminate(process)
        if prompt_file is not None:
            prompt_file.unlink(missing_ok=True)
        if diagnostic_file is not None:
            diagnostic_file.close()
        if diagnostic_path is not None:
            diagnostic_path.unlink(missing_ok=True)


def validate_output(output_path: Path, job: dict[str, Any]) -> None:
    if not output_path.is_file():
        raise OutputInvalid("output_missing")
    size = output_path.stat().st_size
    if not 0 < size <= MAX_VIDEO_BYTES:
        raise OutputInvalid("output_size_invalid")
    probe = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=codec_name,codec_type,width,height,r_frame_rate,nb_frames,duration:format=duration,size",
            "-of",
            "json",
            str(output_path),
        ],
        check=False,
        capture_output=True,
        timeout=30,
    )
    if probe.returncode != 0:
        raise OutputInvalid("ffprobe_failed")
    try:
        metadata = json.loads(probe.stdout)
        streams = metadata.get("streams", [])
    except (json.JSONDecodeError, AttributeError) as error:
        raise OutputInvalid("ffprobe_invalid_json") from error
    if not streams or streams[0].get("codec_type") != "video":
        raise OutputInvalid("video_stream_missing")
    stream = streams[0]
    expected_dimensions = {
        "16:9": (1280, 704),
        "9:16": (704, 1280),
    }.get(str(job.get("aspect_ratio", "")))
    if expected_dimensions is None or (
        int(stream.get("width", 0)), int(stream.get("height", 0))
    ) != expected_dimensions:
        raise OutputInvalid("output_dimensions_invalid")
    if stream.get("codec_name") != "h264":
        raise OutputInvalid("output_codec_invalid")
    if abs(_frame_rate(stream.get("r_frame_rate")) - EXPECTED_FRAME_RATE) > 0.01:
        raise OutputInvalid("output_frame_rate_invalid")
    frame_count = stream.get("nb_frames")
    if frame_count not in (None, "N/A", "") and int(frame_count) != EXPECTED_FRAME_COUNT:
        raise OutputInvalid("output_frame_count_invalid")
    file_format = metadata.get("format", {})
    raw_duration = stream.get("duration") or (
        file_format.get("duration") if isinstance(file_format, dict) else None
    )
    try:
        duration = float(raw_duration)
    except (TypeError, ValueError) as error:
        raise OutputInvalid("output_duration_invalid") from error
    if abs(duration - EXPECTED_DURATION_SECONDS) > 0.35:
        raise OutputInvalid("output_duration_invalid")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _frame_rate(value: Any) -> float:
    if not isinstance(value, str):
        return 0.0
    numerator, separator, denominator = value.partition("/")
    try:
        return float(numerator) / float(denominator) if separator else float(value)
    except (TypeError, ValueError, ZeroDivisionError):
        return 0.0


def terminate(process: subprocess.Popen[bytes]) -> None:
    process.terminate()
    try:
        process.wait(timeout=15)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=10)


class ShutdownFlag:
    value = False


def run() -> None:
    settings = Settings.from_env()
    api = WorkerApi(settings)
    shutdown = ShutdownFlag()

    def request_shutdown(_signum: int, _frame: Any) -> None:
        shutdown.value = True

    signal.signal(signal.SIGTERM, request_shutdown)
    signal.signal(signal.SIGINT, request_shutdown)
    print(f"video worker ready: {settings.worker_id}", flush=True)
    last_activity = time.monotonic()

    while not shutdown.value:
        output_path: Path | None = None
        job_id = ""
        lease_token = ""
        try:
            job = api.claim()
            if job is None:
                if time.monotonic() - last_activity >= settings.idle_exit_seconds:
                    print("video queue idle; requesting host shutdown", flush=True)
                    return
                time.sleep(settings.poll_seconds)
                continue
            last_activity = time.monotonic()
            job_id, lease_token, prompt = validate_job(job)
            print(f"claimed video job {job_id}", flush=True)
            output_path = generate_video(
                settings, api, job, job_id, lease_token, prompt, shutdown
            )
            api.upload_and_complete(job_id, lease_token, output_path)
            last_activity = time.monotonic()
            print(f"completed video job {job_id}", flush=True)
        except LeaseLost:
            print(f"discarded expired video lease {job_id}", flush=True)
        except WorkerError as error:
            print(
                "video job failed: "
                f"{error.error_code} ({safe_worker_error_detail(error)})",
                flush=True,
            )
            if job_id and lease_token:
                try:
                    api.fail(job_id, lease_token, error.error_code, error.retryable)
                except WorkerError:
                    print("could not release video lease", flush=True)
        except (requests.RequestException, OSError, ValueError) as error:
            print(f"worker control error: {type(error).__name__}", flush=True)
            if job_id and lease_token:
                try:
                    api.fail(job_id, lease_token, "upload_failed", True)
                except WorkerError:
                    pass
            time.sleep(settings.poll_seconds)
        finally:
            if output_path is not None:
                output_path.unlink(missing_ok=True)


if __name__ == "__main__":
    run()
