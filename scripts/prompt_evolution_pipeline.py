#!/usr/bin/env python3
"""Evolutionary prompt optimization & deterministic validation pipeline (#2723).

Collects Goal-Plan-Action execution traces (live read-only Supabase feed or
canonical baseline fixtures), scores consistency and efficiency, detects when
GPA score variance exceeds a configurable threshold, runs GEPA-style reflective
evolutionary mutation + Pareto fitness ranking, and enforces a fail-closed
deterministic validation gate before a review PR can be proposed.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
import math
import os
from pathlib import Path
import re
import sys
from typing import Any, Protocol


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import ai_review_gate  # noqa: E402
import security_review_input  # noqa: E402
import validate_ai_output_baseline as baseline_val  # noqa: E402


DEFAULT_BASELINE_PATH = (
    REPO_ROOT / "eval" / "fixtures" / "prompt_evolution_baseline.json"
)
DEFAULT_PROPOSAL_PATH = (
    REPO_ROOT / "eval" / "fixtures" / "prompt_evolution_candidate.json"
)


@dataclass(frozen=True)
class TraceScore:
    source_type: str
    source_id: str
    goal_score: float
    plan_score: float
    action_score: float
    consistency_score: float
    efficiency_score: float
    gpa: float
    weak_axes: list[str]


@dataclass(frozen=True)
class EvolvedCandidate:
    candidate_id: str
    strategy: str
    generation: int
    prompt_sections: dict[str, str]
    fitness_score: float
    projected_gpa: float
    projected_variance_drop: float
    reflection_summary: str


class CandidateGeneratorBackend(Protocol):
    """Pluggable prompt evolution mutator (deterministic offline or LLM-backed)."""

    def generate(
        self,
        base_prompt: dict[str, str],
        scored_traces: list[TraceScore],
        score_variance: float,
        variance_threshold: float,
    ) -> list[EvolvedCandidate]:
        ...


def _clamp_score(value: float, decimals: int = 2) -> float:
    return round(min(4.0, max(0.0, value)), decimals)


def score_gpa_trace(raw: dict[str, Any]) -> TraceScore:
    """Compute Goal, Plan, Action, Consistency, and Efficiency scores (0..4)."""
    goal = str(raw.get("goal") or "").strip()
    plan = [str(x).strip() for x in (raw.get("plan") or []) if str(x).strip()]
    actions = [
        str(x).strip() for x in (raw.get("actions") or []) if str(x).strip()
    ]
    success = raw.get("success") is not False
    latency_ms = max(0.0, float(raw.get("latency_ms", 1200) or 0.0))
    retry_count = max(0, int(raw.get("retry_count", 0) or 0))
    output_chars = max(0, int(raw.get("output_chars", 500) or 0))

    goal_score = _clamp_score(
        3.0 + (0.6 if goal else -0.8) + (0.3 if success else -0.9),
        1,
    )
    plan_score = _clamp_score(
        2.6 + (0.9 if len(plan) >= 2 else (0.3 if plan else -0.7))
        - (0.3 if retry_count > 1 else 0.0),
        1,
    )
    action_score = _clamp_score(
        2.7 + (0.7 if actions else -0.6) + (0.4 if success else -1.1),
        1,
    )
    consistency_score = _clamp_score(
        3.4 - (0.5 if not success else 0.0) - min(1.0, retry_count * 0.25),
        1,
    )

    eff = 3.8
    if not success:
        eff -= 1.2
    eff -= min(1.6, retry_count * 0.45)
    if latency_ms > 8000:
        eff -= 1.0
    elif latency_ms > 4000:
        eff -= 0.4
    if len(actions) > 10:
        eff -= min(0.8, (len(actions) - 10) * 0.15)
    if output_chars > 12000:
        eff -= 0.3
    efficiency_score = _clamp_score(eff, 1)

    gpa = _clamp_score(
        (
            goal_score
            + plan_score
            + action_score
            + consistency_score
            + efficiency_score
        )
        / 5.0,
        2,
    )

    weak_axes: list[str] = []
    if goal_score < 3.0:
        weak_axes.append("goal")
    if plan_score < 3.0:
        weak_axes.append("plan")
    if action_score < 3.0:
        weak_axes.append("action")
    if consistency_score < 3.0:
        weak_axes.append("consistency")
    if efficiency_score < 3.0:
        weak_axes.append("efficiency")

    return TraceScore(
        source_type=str(raw.get("source_type") or "secretary_action"),
        source_id=str(raw.get("source_id") or ""),
        goal_score=goal_score,
        plan_score=plan_score,
        action_score=action_score,
        consistency_score=consistency_score,
        efficiency_score=efficiency_score,
        gpa=gpa,
        weak_axes=weak_axes,
    )


def summarize_traces(
    traces: list[dict[str, Any]],
    variance_threshold: float,
    min_samples: int,
) -> dict[str, Any]:
    scored = [score_gpa_trace(item) for item in traces]
    count = len(scored)
    if count == 0:
        return {
            "sample_count": 0,
            "mean_gpa": 0.0,
            "mean_consistency": 0.0,
            "mean_efficiency": 0.0,
            "score_variance": 0.0,
            "score_stddev": 0.0,
            "variance_threshold": variance_threshold,
            "min_samples": min_samples,
            "evolution_triggered": False,
            "scored_traces": [],
        }

    mean_gpa = sum(t.gpa for t in scored) / count
    mean_consistency = sum(t.consistency_score for t in scored) / count
    mean_efficiency = sum(t.efficiency_score for t in scored) / count
    variance = sum((t.gpa - mean_gpa) ** 2 for t in scored) / count
    rounded_var = round(variance, 4)
    triggered = count >= min_samples and rounded_var > variance_threshold

    return {
        "sample_count": count,
        "mean_gpa": round(mean_gpa, 3),
        "mean_consistency": round(mean_consistency, 3),
        "mean_efficiency": round(mean_efficiency, 3),
        "score_variance": rounded_var,
        "score_stddev": round(math.sqrt(variance), 4),
        "variance_threshold": variance_threshold,
        "min_samples": min_samples,
        "evolution_triggered": triggered,
        "scored_traces": scored,
    }


class DeterministicReflectiveBackend:
    """GEPA-inspired deterministic reflective prompt optimizer."""

    def generate(
        self,
        base_prompt: dict[str, str],
        scored_traces: list[TraceScore],
        score_variance: float,
        variance_threshold: float,
    ) -> list[EvolvedCandidate]:
        mean_gpa = (
            sum(t.gpa for t in scored_traces) / len(scored_traces)
            if scored_traces
            else 0.0
        )
        weak_counts: dict[str, int] = {
            "goal": 0,
            "plan": 0,
            "action": 0,
            "consistency": 0,
            "efficiency": 0,
        }
        for trace in scored_traces:
            for axis in trace.weak_axes:
                if axis in weak_counts:
                    weak_counts[axis] += 1

        directives: list[str] = []
        if weak_counts["goal"] > 0:
            directives.append(
                "State one atomic Goal and explicit acceptance check first."
            )
        if weak_counts["plan"] > 0:
            directives.append(
                "Emit a numbered Plan aligned with observed preconditions."
            )
        if weak_counts["action"] > 0:
            directives.append(
                "Validate Action inputs and fail closed before side effects."
            )
        if weak_counts["consistency"] > 0 or score_variance > variance_threshold:
            directives.append(
                "Audit output against constraints before final completion."
            )
        if weak_counts["efficiency"] > 0:
            directives.append(
                "Avoid redundant retries; converge within <= 3 bounded steps."
            )
        if not directives:
            directives.append("Preserve Goal-Plan-Action constraint alignment.")

        reflection = (
            f"Observed GPA variance={score_variance:.4f} (> {variance_threshold:.2f}); "
            f"weak axes={ {k: v for k, v in weak_counts.items() if v > 0} }."
        )

        title = str(base_prompt.get("title") or "Executive Agent Prompt")
        role_setting = str(base_prompt.get("role_setting") or "")
        context_info = str(base_prompt.get("context_info") or "")
        deliverable = str(base_prompt.get("deliverable_definition") or "")
        constraints = str(base_prompt.get("constraints_text") or "")
        thinking = str(base_prompt.get("thinking_process") or "")

        strategies: list[tuple[str, dict[str, str], float, float]] = [
            (
                "reflective_constraint_patch",
                {
                    "title": f"[GEPA Candidate] {title}"[:120],
                    "role_setting": role_setting,
                    "context_info": context_info,
                    "deliverable_definition": (
                        f"{deliverable}\n- Include explicit Goal, Plan, and Action checks."
                    ),
                    "constraints_text": f"{constraints}\n- " + "\n- ".join(directives),
                    "thinking_process": (
                        f"{thinking}\nVerify Goal-Plan-Action consistency and constraints before responding."
                    ),
                },
                0.42,
                min(score_variance * 0.55, 0.4),
            ),
            (
                "stepwise_plan_enforcer",
                {
                    "title": f"[GEPA Plan] {title}"[:120],
                    "role_setting": role_setting,
                    "context_info": f"{context_info}\nInclude verified tool preconditions.",
                    "deliverable_definition": deliverable,
                    "constraints_text": f"{constraints}\n- Do not skip Plan verification or constraints.",
                    "thinking_process": (
                        f"Step 1: Goal check. Step 2: Plan verification. Step 3: Bounded Action.\n{thinking}"
                    ),
                },
                0.36,
                min(score_variance * 0.48, 0.35),
            ),
            (
                "efficiency_compression",
                {
                    "title": f"[GEPA Compact] {title}"[:120],
                    "role_setting": role_setting,
                    "context_info": context_info,
                    "deliverable_definition": (
                        f"{deliverable}\nConverge concisely with Goal, Plan, Action alignment."
                    ),
                    "constraints_text": f"{constraints}\n- Respect constraints; halt repeated failing Action retries.",
                    "thinking_process": thinking,
                },
                0.31,
                min(score_variance * 0.42, 0.3),
            ),
        ]

        candidates: list[EvolvedCandidate] = []
        for idx, (strategy, sections, gpa_boost, var_drop) in enumerate(
            strategies, start=1
        ):
            projected_gpa = _clamp_score(mean_gpa + gpa_boost, 2)
            rounded_drop = round(var_drop, 3)
            fitness = round(
                projected_gpa * 0.65 + (rounded_drop * 2.5) * 0.35, 3
            )
            candidates.append(
                EvolvedCandidate(
                    candidate_id=f"gepa-{idx}-{strategy}",
                    strategy=strategy,
                    generation=1,
                    prompt_sections=sections,
                    fitness_score=fitness,
                    projected_gpa=projected_gpa,
                    projected_variance_drop=rounded_drop,
                    reflection_summary=reflection,
                )
            )
        candidates.sort(key=lambda item: item.fitness_score, reverse=True)
        return candidates


def validate_candidates_deterministically(
    candidates: list[EvolvedCandidate],
    contract: dict[str, Any],
    baseline_mean_gpa: float,
    proposal_rel_path: str = "eval/fixtures/prompt_evolution_candidate.json",
) -> dict[str, Any]:
    """Fail-closed deterministic validation gate required before PR proposal."""
    if not candidates:
        return {
            "passed": False,
            "checks": ["candidates_present: no candidates provided"],
            "redact_hits": 0,
            "scope_valid": False,
        }

    required_markers = [
        str(m).lower() for m in (contract.get("required_markers") or [])
    ]
    banned_terms = tuple(
        str(b) for b in (contract.get("banned_terms") or []) if str(b).strip()
    )
    max_section_chars = int(contract.get("max_section_chars", 4000) or 4000)

    errors: list[str] = []
    redact_total = 0

    for cand in candidates:
        joined = "\n".join(cand.prompt_sections.values())
        baseline_res = baseline_val.validate_output(
            joined,
            format_contract="plain_text",
            banned_terms=banned_terms,
            max_length=max_section_chars * 4,
        )
        if not baseline_res.allowed or baseline_res.violation_count > 0:
            errors.append(
                f"{cand.candidate_id}: baseline validation blocked ({baseline_res.decision})"
            )

        _, redact_cnt = security_review_input.redact_secrets_with_count(joined)
        redact_total += redact_cnt
        if redact_cnt > 0:
            errors.append(
                f"{cand.candidate_id}: secret/credential shape detected ({redact_cnt})"
            )

        lower_joined = joined.lower()
        for marker in required_markers:
            if marker not in lower_joined:
                errors.append(
                    f"{cand.candidate_id}: missing required marker '{marker}'"
                )

        for key, val in cand.prompt_sections.items():
            if not val.strip():
                errors.append(f"{cand.candidate_id}: empty section '{key}'")
            if len(val) > max_section_chars:
                errors.append(
                    f"{cand.candidate_id}: section '{key}' exceeds {max_section_chars} chars"
                )

        if cand.projected_gpa < baseline_mean_gpa:
            errors.append(
                f"{cand.candidate_id}: projected GPA regressed ({cand.projected_gpa} < {baseline_mean_gpa})"
            )

    serialized_winner = json.dumps(
        asdict(candidates[0]), ensure_ascii=False, indent=2
    )
    scope_ok = False
    try:
        fake_diff = "\n".join(
            f"+{ln}" for ln in serialized_winner.splitlines()
        )
        ai_review_gate.validate_scope([proposal_rel_path], fake_diff)
        scope_ok = True
    except Exception as exc:  # pragma: no cover - defensive fail closed
        errors.append(f"ai_review_gate.validate_scope failed: {exc}")

    return {
        "passed": len(errors) == 0 and redact_total == 0 and scope_ok,
        "checks": errors if errors else ["all_deterministic_checks_passed"],
        "redact_hits": redact_total,
        "scope_valid": scope_ok,
        "checked_candidates": len(candidates),
    }


def _fetch_live_gpa_traces(
    supabase_url: str,
    pub_key: str,
    limit: int = 30,
) -> list[dict[str, Any]]:
    """Read-only fetch from agent_gpa_evaluations when configured."""
    import urllib.request

    cleaned = supabase_url.rstrip("/")
    if not cleaned.startswith("https://"):
        raise ValueError("Live Supabase URL must use https://")
    req = urllib.request.Request(
        f"{cleaned}/rest/v1/agent_gpa_evaluations"
        f"?select=source_type,source_id,goal_score,plan_score,action_score,consistency_score,gpa,rationale_short"
        f"&order=evaluated_at.desc&limit={max(1, min(limit, 50))}",
        headers={
            "apikey": pub_key,
            "Accept": "application/json",
        },
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        rows = json.loads(resp.read().decode("utf-8"))
    if not isinstance(rows, list):
        return []
    mapped: list[dict[str, Any]] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        mapped.append(
            {
                "source_type": row.get("source_type") or "secretary_action",
                "source_id": row.get("source_id") or "",
                "goal": "persisted" if float(row.get("goal_score", 0)) >= 3 else "",
                "plan": ["p1", "p2"] if float(row.get("plan_score", 0)) >= 3 else [],
                "actions": ["a1"] if float(row.get("action_score", 0)) >= 3 else [],
                "latency_ms": 1200 if float(row.get("gpa", 0)) >= 3 else 8500,
                "retry_count": 0 if float(row.get("consistency_score", 0)) >= 3 else 2,
                "output_chars": 500,
                "success": float(row.get("gpa", 0)) >= 2.5,
            }
        )
    return mapped


def run_pipeline(
    baseline_path: Path = DEFAULT_BASELINE_PATH,
    variance_threshold: float | None = None,
    min_samples: int | None = None,
    backend: CandidateGeneratorBackend | None = None,
    proposal_out: Path | None = None,
    live_supabase_url: str = "",
    live_anon_key: str = "",
    traces_override: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    data = json.loads(baseline_path.read_text(encoding="utf-8"))
    eff_threshold = (
        variance_threshold
        if variance_threshold is not None
        else float(data.get("variance_threshold", 0.15))
    )
    eff_min_samples = (
        min_samples
        if min_samples is not None
        else int(data.get("min_samples", 3))
    )

    traces: list[dict[str, Any]]
    trace_source = "baseline_fixture"
    if traces_override is not None:
        traces = traces_override
        trace_source = "override"
    elif live_supabase_url and live_anon_key:
        try:
            fetched = _fetch_live_gpa_traces(live_supabase_url, live_anon_key)
            if fetched:
                traces = fetched
                trace_source = "live_supabase_readonly"
            else:
                traces = list(data.get("baseline_traces") or [])
        except Exception:
            traces = list(data.get("baseline_traces") or [])
    else:
        traces = list(data.get("baseline_traces") or [])

    summary = summarize_traces(traces, eff_threshold, eff_min_samples)
    scored: list[TraceScore] = summary["scored_traces"]

    candidates: list[EvolvedCandidate] = []
    validation: dict[str, Any] = {
        "passed": False,
        "checks": ["not_triggered"],
        "redact_hits": 0,
        "scope_valid": False,
    }
    pr_eligible = False

    if summary["evolution_triggered"]:
        active_backend = backend or DeterministicReflectiveBackend()
        candidates = active_backend.generate(
            base_prompt=dict(data.get("base_prompt") or {}),
            scored_traces=scored,
            score_variance=summary["score_variance"],
            variance_threshold=eff_threshold,
        )
        validation = validate_candidates_deterministically(
            candidates=candidates,
            contract=dict(data.get("validation_contract") or {}),
            baseline_mean_gpa=summary["mean_gpa"],
        )
        pr_eligible = bool(validation["passed"] and candidates)
        if pr_eligible and proposal_out is not None:
            proposal_out.parent.mkdir(parents=True, exist_ok=True)
            proposal_payload = {
                "schema_version": 1,
                "source_issue": 2723,
                "trace_source": trace_source,
                "score_variance": summary["score_variance"],
                "mean_gpa": summary["mean_gpa"],
                "winner": asdict(candidates[0]),
                "deterministic_validation": validation,
            }
            proposal_out.write_text(
                json.dumps(proposal_payload, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )

    return {
        "trace_source": trace_source,
        "sample_count": summary["sample_count"],
        "mean_gpa": summary["mean_gpa"],
        "mean_consistency": summary["mean_consistency"],
        "mean_efficiency": summary["mean_efficiency"],
        "score_variance": summary["score_variance"],
        "score_stddev": summary["score_stddev"],
        "variance_threshold": eff_threshold,
        "evolution_triggered": summary["evolution_triggered"],
        "candidates": [asdict(c) for c in candidates],
        "winner": asdict(candidates[0]) if candidates else None,
        "deterministic_validation": validation,
        "pr_eligible": pr_eligible,
        "scored_traces": [asdict(s) for s in scored],
    }


def render_markdown_report(report: dict[str, Any]) -> str:
    lines = [
        "# Evolutionary Prompt Optimization Report",
        "",
        f"- **Trace source**: `{report['trace_source']}`",
        f"- **Samples evaluated**: `{report['sample_count']}`",
        f"- **Mean GPA**: `{report['mean_gpa']}` (Consistency `{report['mean_consistency']}`, Efficiency `{report['mean_efficiency']}`)",
        f"- **Score variance**: `{report['score_variance']}` (threshold `{report['variance_threshold']}`)",
        f"- **Evolution triggered**: `{report['evolution_triggered']}`",
        f"- **Deterministic validation passed**: `{report['deterministic_validation']['passed']}`",
        f"- **PR eligible**: `{report['pr_eligible']}`",
    ]
    winner = report.get("winner")
    if isinstance(winner, dict):
        lines.extend(
            [
                "",
                f"## Top Evolved Candidate (`{winner['candidate_id']}`)",
                f"- **Fitness**: `{winner['fitness_score']}` (Projected GPA `{winner['projected_gpa']}`, Variance Drop `{winner['projected_variance_drop']}`)",
                f"- **Reflection**: {winner['reflection_summary']}",
            ]
        )
    return "\n".join(lines) + "\n"


def _run_self_test() -> int:
    # 1. Low-variance traces must not trigger evolution or PR proposal.
    uniform = [
        {
            "source_type": "secretary_action",
            "source_id": "11111111-1111-4111-8111-111111111111",
            "goal": "G",
            "plan": ["P1", "P2"],
            "actions": ["A1"],
            "latency_ms": 800,
            "retry_count": 0,
            "success": True,
        },
        {
            "source_type": "secretary_action",
            "source_id": "22222222-2222-4222-8222-222222222222",
            "goal": "G",
            "plan": ["P1", "P2"],
            "actions": ["A1"],
            "latency_ms": 900,
            "retry_count": 0,
            "success": True,
        },
        {
            "source_type": "secretary_action",
            "source_id": "33333333-3333-4333-8333-333333333333",
            "goal": "G",
            "plan": ["P1", "P2"],
            "actions": ["A1"],
            "latency_ms": 850,
            "retry_count": 0,
            "success": True,
        },
    ]
    res_low = run_pipeline(traces_override=uniform, variance_threshold=0.15)
    assert not res_low["evolution_triggered"], "Expected low variance skip"
    assert not res_low["pr_eligible"], "Low variance must not propose PR"

    # 2. High-variance baseline fixture triggers evolution & passes deterministic checks.
    res_high = run_pipeline(variance_threshold=0.15)
    assert res_high["evolution_triggered"], "Expected high variance trigger"
    assert res_high["deterministic_validation"]["passed"], "Deterministic checks must pass"
    assert res_high["pr_eligible"], "High variance passing candidate should be PR eligible"
    print(
        f"SELF_TEST_PASS mean_gpa={res_high['mean_gpa']} variance={res_high['score_variance']} winner={res_high['winner']['candidate_id']}"
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-file", type=Path, default=DEFAULT_BASELINE_PATH)
    parser.add_argument("--variance-threshold", type=float, default=None)
    parser.add_argument("--min-samples", type=int, default=None)
    parser.add_argument("--proposal-out", type=Path, default=None)
    parser.add_argument("--json-out", type=Path, default=None)
    parser.add_argument("--markdown-out", type=Path, default=None)
    parser.add_argument("--github-output", type=Path, default=None)
    parser.add_argument("--live-supabase-url", default="")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)

    if args.self_test:
        return _run_self_test()

    anon_env = os.environ.get("SUPABASE_ANON_KEY", "")
    report = run_pipeline(
        baseline_path=args.baseline_file,
        variance_threshold=args.variance_threshold,
        min_samples=args.min_samples,
        proposal_out=args.proposal_out,
        live_supabase_url=args.live_supabase_url,
        live_anon_key=anon_env,
    )

    if args.json_out is not None:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    if args.markdown_out is not None:
        args.markdown_out.parent.mkdir(parents=True, exist_ok=True)
        args.markdown_out.write_text(
            render_markdown_report(report),
            encoding="utf-8",
        )
    if args.github_output is not None:
        with args.github_output.open("a", encoding="utf-8") as fh:
            fh.write(f"evolution_triggered={'true' if report['evolution_triggered'] else 'false'}\n")
            fh.write(f"validation_passed={'true' if report['deterministic_validation']['passed'] else 'false'}\n")
            fh.write(f"pr_eligible={'true' if report['pr_eligible'] else 'false'}\n")
            fh.write(f"score_variance={report['score_variance']}\n")
            fh.write(f"mean_gpa={report['mean_gpa']}\n")

    print(json.dumps({
        "sample_count": report["sample_count"],
        "mean_gpa": report["mean_gpa"],
        "score_variance": report["score_variance"],
        "evolution_triggered": report["evolution_triggered"],
        "validation_passed": report["deterministic_validation"]["passed"],
        "pr_eligible": report["pr_eligible"],
    }))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
