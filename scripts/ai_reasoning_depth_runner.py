#!/usr/bin/env python3
"""AI Reasoning Depth Switcher planner and async queue runner (#2654).

Provides deterministic Standard / Deep Research / Background mode profiles,
USD cost and latency comparison against the Standard baseline, multi-hop
async queue progression, and optional env-gated remote Edge dispatch with
sanitized URL error reporting.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Any


@dataclass(frozen=True)
class ReasoningModeProfile:
    """Configuration, budget limits, and cost/latency baseline per reasoning mode."""

    mode: str
    display_name: str
    execution_kind: str
    max_tool_calls: int
    timeout_seconds: int
    estimated_cost_usd: float
    estimated_latency_ms: int
    stages: tuple[str, ...]

    @property
    def is_async_queue(self) -> bool:
        return self.execution_kind == "async_queue"


REASONING_PROFILES: dict[str, ReasoningModeProfile] = {
    "standard": ReasoningModeProfile(
        mode="standard",
        display_name="Standard",
        execution_kind="sync",
        max_tool_calls=3,
        timeout_seconds=15,
        estimated_cost_usd=0.002000,
        estimated_latency_ms=1500,
        stages=("クエリ解析・軽量検索 (1/1)",),
    ),
    "deep_research": ReasoningModeProfile(
        mode="deep_research",
        display_name="Deep Research",
        execution_kind="async_queue",
        max_tool_calls=25,
        timeout_seconds=300,
        estimated_cost_usd=0.032000,
        estimated_latency_ms=45000,
        stages=(
            "調査プラン分解・キュー投入",
            "複数ドキュメント横断検索・証拠抽出",
            "論点突合・矛盾検証",
            "根拠付き構造化レポート統合",
        ),
    ),
    "background": ReasoningModeProfile(
        mode="background",
        display_name="Background",
        execution_kind="async_queue",
        max_tool_calls=50,
        timeout_seconds=600,
        estimated_cost_usd=0.058000,
        estimated_latency_ms=180000,
        stages=(
            "非同期バックグラウンドキュー登録",
            "広域コーパス深掘り・並列探索",
            "長文コンテキスト相互検証",
            "最終サマリー生成・完了通知準備",
        ),
    ),
}

_EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
_BEARER_RE = re.compile(r"(?i)\bbearer\s+[A-Za-z0-9._\-]{8,}")
_KEY_LIKE_RE = re.compile(r"\b(?:sk|sb|ghp|gho|AIza)[A-Za-z0-9_\-]{8,}\b")


def sanitize_url_for_log(raw_url: str) -> str:
    """Strip credentials, query parameters, and fragments before logging/raising."""
    parsed = urllib.parse.urlsplit(raw_url.strip())
    if not parsed.scheme or not parsed.netloc:
        return "<invalid-url>"
    hostname = parsed.hostname or ""
    if parsed.port is not None:
        netloc = f"{hostname}:{parsed.port}"
    else:
        netloc = hostname
    path = parsed.path or "/"
    return f"{parsed.scheme}://{netloc}{path}"


def scrub_sensitive_text(raw: str, max_length: int = 500) -> str:
    """Remove email addresses, bearer headers, and token prefixes cleanly."""
    cleaned = _BEARER_RE.sub("Bearer [redacted]", raw.strip())
    cleaned = _KEY_LIKE_RE.sub("[redacted]", cleaned)
    cleaned = _EMAIL_RE.sub("[email-redacted]", cleaned)
    if len(cleaned) > max_length:
        return cleaned[:max_length].rstrip()
    return cleaned


def get_profile(mode: str) -> ReasoningModeProfile:
    """Return validated ReasoningModeProfile or raise ValueError."""
    normalized = mode.strip().lower()
    if normalized not in REASONING_PROFILES:
        valid = ", ".join(sorted(REASONING_PROFILES))
        raise ValueError(f"Unsupported reasoning_mode '{mode}'. Expected one of: {valid}")
    return REASONING_PROFILES[normalized]


def compare_mode_estimates(prompt_summary: str) -> dict[str, Any]:
    """Compare USD cost and latency across Standard, Deep Research, and Background."""
    sanitized_prompt = scrub_sensitive_text(prompt_summary)
    if not sanitized_prompt:
        raise ValueError("prompt_summary must not be empty")

    baseline = REASONING_PROFILES["standard"]
    complexity_factor = 1.0 + min(len(sanitized_prompt) / 500.0, 0.25)

    comparisons: list[dict[str, Any]] = []
    for key in ("standard", "deep_research", "background"):
        profile = REASONING_PROFILES[key]
        est_cost = round(profile.estimated_cost_usd * complexity_factor, 6)
        base_cost = round(baseline.estimated_cost_usd * complexity_factor, 6)
        est_latency = int(round(profile.estimated_latency_ms * complexity_factor))
        base_latency = int(round(baseline.estimated_latency_ms * complexity_factor))
        cost_delta = round(est_cost - base_cost, 6)
        latency_delta = est_latency - base_latency
        cost_ratio = round(est_cost / base_cost, 2) if base_cost > 0 else 1.0
        comparisons.append(
            {
                "mode": profile.mode,
                "display_name": profile.display_name,
                "execution_kind": profile.execution_kind,
                "is_async_queue": profile.is_async_queue,
                "max_tool_calls": profile.max_tool_calls,
                "timeout_seconds": profile.timeout_seconds,
                "estimated_cost_usd": est_cost,
                "estimated_cost_label": f"USD {est_cost:.6f}",
                "cost_delta_vs_standard_usd": cost_delta,
                "cost_multiplier_vs_standard": cost_ratio,
                "estimated_latency_ms": est_latency,
                "latency_delta_vs_standard_ms": latency_delta,
            }
        )

    return {
        "prompt_summary": sanitized_prompt,
        "baseline_mode": baseline.mode,
        "complexity_factor": round(complexity_factor, 4),
        "comparisons": comparisons,
    }


def build_job_plan(mode: str, prompt_summary: str) -> dict[str, Any]:
    """Build initial persisted row payload for public.ai_reasoning_depth_jobs."""
    profile = get_profile(mode)
    sanitized_prompt = scrub_sensitive_text(prompt_summary)
    if not sanitized_prompt:
        raise ValueError("prompt_summary must not be empty")

    comparison_data = compare_mode_estimates(sanitized_prompt)
    matched = next(
        item for item in comparison_data["comparisons"] if item["mode"] == profile.mode
    )

    if profile.is_async_queue:
        initial_status = "queued"
        initial_tools = 0
        progress_note = (
            f"{profile.display_name} 非同期キュー待機中: {profile.stages[0]}"
        )
        result_summary = ""
    else:
        initial_status = "completed"
        initial_tools = min(2, profile.max_tool_calls)
        progress_note = f"{profile.display_name} 同期推論完了 ({initial_tools}/{profile.max_tool_calls} ツール)"
        result_summary = f"[{profile.display_name}] '{sanitized_prompt}' の標準推論を同期完了しました。"

    return {
        "reasoning_mode": profile.mode,
        "prompt_summary": sanitized_prompt,
        "max_tool_calls": profile.max_tool_calls,
        "timeout_seconds": profile.timeout_seconds,
        "estimated_cost_usd": matched["estimated_cost_usd"],
        "estimated_latency_ms": matched["estimated_latency_ms"],
        "tool_calls_completed": initial_tools,
        "job_status": initial_status,
        "progress_note": progress_note,
        "result_summary": result_summary,
        "stages": list(profile.stages),
        "comparison": comparison_data,
    }


def advance_job_state(job: dict[str, Any]) -> dict[str, Any]:
    """Advance an async queued/running reasoning job one polling step forward."""
    mode = str(job.get("reasoning_mode", "standard"))
    profile = get_profile(mode)
    current_status = str(job.get("job_status", "queued"))
    updated = dict(job)

    if current_status in {"completed", "failed", "cancelled"}:
        return updated

    max_calls = int(updated.get("max_tool_calls", profile.max_tool_calls))
    completed_calls = int(updated.get("tool_calls_completed", 0))
    prompt = str(updated.get("prompt_summary", ""))

    if current_status == "queued":
        next_calls = min(max(1, max_calls // 4), max_calls)
        stage_text = profile.stages[min(1, len(profile.stages) - 1)]
        updated["job_status"] = "running"
        updated["tool_calls_completed"] = next_calls
        updated["progress_note"] = (
            f"{profile.display_name} 実行中: {stage_text} ({next_calls}/{max_calls} ツール)"
        )
        return updated

    step_increment = max(1, (max_calls + 1) // 3)
    next_calls = min(max_calls, completed_calls + step_increment)
    updated["tool_calls_completed"] = next_calls

    if next_calls >= max_calls:
        updated["job_status"] = "completed"
        updated["progress_note"] = (
            f"{profile.display_name} 完了: 全 {len(profile.stages)} 工程 "
            f"({next_calls}/{max_calls} ツール) 完了"
        )
        updated["result_summary"] = (
            f"[{profile.display_name}] '{prompt}' を最大ツール上限 "
            f"{max_calls} 回・タイムアウト {profile.timeout_seconds} 秒枠内で統合完了しました。"
        )
    else:
        ratio = next_calls / float(max_calls)
        stage_index = min(
            len(profile.stages) - 1,
            max(1, int(ratio * (len(profile.stages) - 1))),
        )
        updated["job_status"] = "running"
        updated["progress_note"] = (
            f"{profile.display_name} 実行中: {profile.stages[stage_index]} "
            f"({next_calls}/{max_calls} ツール)"
        )

    return updated


def dispatch_remote_reasoning_job(
    *,
    endpoint_url: str,
    auth_header_value: str,
    payload: dict[str, Any],
    timeout_seconds: int = 15,
) -> dict[str, Any]:
    """Send job payload to an env-gated Supabase Edge endpoint cleanly."""
    clean_url = sanitize_url_for_log(endpoint_url)
    if not endpoint_url.strip().startswith(("https://", "http://")):
        raise ValueError(f"Unsupported endpoint scheme: {clean_url}")

    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        endpoint_url.strip(),
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Authorization": auth_header_value,
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
            status_code = getattr(response, "status", 200)
            raw_text = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        raise RuntimeError(
            f"Remote reasoning dispatch failed HTTP {exc.code} at {clean_url}"
        ) from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(
            f"Remote reasoning dispatch network error at {clean_url}: {exc.reason}"
        ) from exc

    if status_code < 200 or status_code >= 300:
        raise RuntimeError(
            f"Remote reasoning dispatch returned HTTP {status_code} at {clean_url}"
        )

    try:
        decoded = json.loads(raw_text)
    except json.JSONDecodeError as exc:
        raise RuntimeError(
            f"Remote reasoning dispatch returned invalid JSON from {clean_url}"
        ) from exc

    if not isinstance(decoded, dict):
        raise RuntimeError(
            f"Remote reasoning dispatch returned unexpected JSON type from {clean_url}"
        )
    return decoded


def main(argv: list[str] | None = None) -> int:
    """CLI entrypoint defaulting to offline --dry-run planning."""
    parser = argparse.ArgumentParser(
        description="AI reasoning depth planner & async queue helper (#2654)."
    )
    parser.add_argument(
        "--mode",
        default="deep_research",
        choices=("standard", "deep_research", "background"),
        help="Target reasoning mode.",
    )
    parser.add_argument(
        "--prompt",
        default="複数ドキュメントを跨ぐプロジェクト進捗とコストリスク分析",
        help="User task summary for reasoning plan & USD comparison.",
    )
    parser.add_argument(
        "--advance-steps",
        type=int,
        default=0,
        help="Optional local dry-run steps to advance queued/running status.",
    )
    parser.add_argument(
        "--dry-run",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Keep offline and avoid remote Edge Function calls (default: true).",
    )
    args = parser.parse_args(argv)

    plan = build_job_plan(args.mode, args.prompt)
    for _ in range(max(0, args.advance_steps)):
        plan = advance_job_state(plan)

    output: dict[str, Any] = {
        "dry_run": bool(args.dry_run),
        "plan": {
            key: value
            for key, value in plan.items()
            if key not in {"stages", "comparison"}
        },
        "profile": asdict(get_profile(args.mode)),
        "comparison": plan["comparison"],
    }

    if not args.dry_run:
        endpoint = os.environ.get("AI_REASONING_EDGE_URL", "").strip()
        bearer = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        if not endpoint or not bearer:
            raise RuntimeError(
                "Live dispatch requires AI_REASONING_EDGE_URL and SUPABASE_SERVICE_ROLE_KEY."
            )
        output["remote_response"] = dispatch_remote_reasoning_job(
            endpoint_url=endpoint,
            auth_header_value=f"Bearer {bearer}",
            payload=output["plan"],
            timeout_seconds=min(60, get_profile(args.mode).timeout_seconds),
        )

    print(json.dumps(output, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
