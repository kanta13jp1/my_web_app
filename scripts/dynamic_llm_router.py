#!/usr/bin/env python3
"""Complexity-driven dynamic LLM routing and per-model cost telemetry gate.

Synchronizes declarative rules in ``config/llm_routing_rules.json`` with the
Edge ``effort_router.ts`` contract, selects cost-optimal models based on task
category/complexity, budget reserve, and circuit-breaker health, and separates
per-model API call counts and costs via ``ai_model_telemetry_report``.
"""

from __future__ import annotations

import argparse
import dataclasses
import json
import re
import sys
import tempfile
from pathlib import Path
from typing import Any, Iterable, Sequence

try:
    import ai_model_telemetry_report as telemetry_report
    from security_review_input import redact_secrets_with_count
except ModuleNotFoundError:
    try:
        from scripts import ai_model_telemetry_report as telemetry_report
        from scripts.security_review_input import redact_secrets_with_count
    except ModuleNotFoundError:
        _SCRIPTS_DIR = Path(__file__).resolve().parent
        if str(_SCRIPTS_DIR) not in sys.path:
            sys.path.insert(0, str(_SCRIPTS_DIR))
        import ai_model_telemetry_report as telemetry_report
        from security_review_input import redact_secrets_with_count


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG_PATH = REPO_ROOT / "config" / "llm_routing_rules.json"
DEFAULT_EFFORT_ROUTER_PATH = (
    REPO_ROOT / "supabase" / "functions" / "_shared" / "effort_router.ts"
)
VALID_TIERS = ("trivial", "standard", "complex", "critical")
EFFORT_TO_TIER = {
    "low": "trivial",
    "medium": "standard",
    "high": "complex",
    "xhigh": "critical",
}

PROVIDER_PREFIX_RE = re.compile(
    r"\b(?:github_pat_[A-Za-z0-9_]+|gh[pousr]_[A-Za-z0-9_]+|glpat-[A-Za-z0-9_-]+|"
    r"sb_secret_[A-Za-z0-9._-]+|sbp_[A-Za-z0-9._-]+|xox[baprs]-[A-Za-z0-9-]+|"
    r"sk-(?:proj-)?[A-Za-z0-9._-]+|AIza[A-Za-z0-9_-]+|eaw_[A-Za-z0-9]+)\b"
)

TS_ACTION_EFFORT_RE = re.compile(
    r'action:\s*"(?P<action>[^"]+)"\s*,\s*default_effort:\s*"(?P<effort>low|medium|high|xhigh)"',
    re.DOTALL,
)

CRITICAL_KEYWORDS = (
    "deep_reasoning",
    "security_audit",
    "vulnerability",
    "irreversible",
    "migration",
    "distill",
    "root_cause",
)
COMPLEX_KEYWORDS = (
    "architecture",
    "design",
    "code_review",
    "judgment",
    "trade-off",
    "refactor",
)
TRIVIAL_KEYWORDS = (
    "classify",
    "classification",
    "quiz",
    "triage",
    "lookup",
    "search",
    "rank",
    "ping",
)


@dataclasses.dataclass(frozen=True)
class ModelCandidate:
    provider: str
    model: str


@dataclasses.dataclass(frozen=True)
class RoutingDecision:
    tier: str
    effort: str
    provider: str
    model: str
    fallbacks: tuple[ModelCandidate, ...]
    is_frontier: bool
    downgraded_by_budget: bool
    budget_exhausted: bool
    all_candidates_unhealthy: bool
    rationale: str
    category: str
    redaction_count: int


def redact_untrusted_text(value: str) -> tuple[str, int]:
    """Redact credential assignments and standalone provider token prefixes."""
    cleaned, count = redact_secrets_with_count(value)
    cleaned, standalone_hits = PROVIDER_PREFIX_RE.subn("[REDACTED_TOKEN]", cleaned)
    return cleaned, count + standalone_hits


def load_routing_config(config_path: Path = DEFAULT_CONFIG_PATH) -> dict[str, Any]:
    if not config_path.is_file():
        raise FileNotFoundError(f"Routing config not found: {config_path}")
    loaded = json.loads(config_path.read_text(encoding="utf-8-sig"))
    if not isinstance(loaded, dict):
        raise ValueError("Routing config must decode to a JSON object")
    validate_routing_config(loaded)
    return loaded


def validate_routing_config(config: dict[str, Any]) -> list[str]:
    """Validate declarative LLM routing config schema and invariants."""
    errors: list[str] = []
    tiers = config.get("tiers")
    if not isinstance(tiers, dict):
        raise ValueError("Config missing 'tiers' mapping")

    for tier_name in VALID_TIERS:
        tier_cfg = tiers.get(tier_name)
        if not isinstance(tier_cfg, dict):
            errors.append(f"Missing tier definition: {tier_name}")
            continue
        effort = str(tier_cfg.get("effort") or "")
        if EFFORT_TO_TIER.get(effort) != tier_name:
            errors.append(f"Tier {tier_name} has mismatched effort {effort!r}")
        primary = tier_cfg.get("primary")
        if not isinstance(primary, dict) or not primary.get("provider") or not primary.get("model"):
            errors.append(f"Tier {tier_name} missing valid primary provider/model")
        fallbacks = tier_cfg.get("fallbacks")
        if not isinstance(fallbacks, list) or not fallbacks:
            errors.append(f"Tier {tier_name} must define at least one fallback model")
        max_cost = tier_cfg.get("max_cost_per_call_usd")
        if not isinstance(max_cost, (int, float)) or isinstance(max_cost, bool) or max_cost <= 0:
            errors.append(f"Tier {tier_name} requires positive max_cost_per_call_usd")

    categories = config.get("categories")
    if not isinstance(categories, dict) or not categories:
        errors.append("Config missing non-empty 'categories' mapping")
    else:
        for cat_name, cat_cfg in categories.items():
            if not isinstance(cat_cfg, dict) or cat_cfg.get("tier") not in VALID_TIERS:
                errors.append(f"Category {cat_name!r} maps to invalid tier")

    budget_guard = config.get("budget_guard")
    if not isinstance(budget_guard, dict):
        errors.append("Config missing 'budget_guard'")
    else:
        low_thr = budget_guard.get("low_budget_threshold_usd")
        hard_stop = budget_guard.get("hard_stop_threshold_usd")
        if not isinstance(low_thr, (int, float)) or isinstance(low_thr, bool) or low_thr < 0:
            errors.append("budget_guard.low_budget_threshold_usd must be >= 0")
        if not isinstance(hard_stop, (int, float)) or isinstance(hard_stop, bool) or hard_stop < 0:
            errors.append("budget_guard.hard_stop_threshold_usd must be >= 0")

    if errors:
        raise ValueError("; ".join(errors))
    return []


def check_effort_router_sync(
    config: dict[str, Any],
    effort_router_path: Path = DEFAULT_EFFORT_ROUTER_PATH,
) -> list[str]:
    """Ensure Edge effort_router.ts action matrix matches declarative routing config."""
    if not effort_router_path.is_file():
        return [f"Missing Edge router file: {effort_router_path}"]
    source = effort_router_path.read_text(encoding="utf-8")
    categories = config.get("categories", {})
    mismatches: list[str] = []
    found_actions = 0
    for match in TS_ACTION_EFFORT_RE.finditer(source):
        found_actions += 1
        action = match.group("action")
        effort = match.group("effort")
        expected_tier = EFFORT_TO_TIER[effort]
        entry = categories.get(action)
        if not isinstance(entry, dict):
            mismatches.append(f"Missing action {action!r} from routing config categories")
        elif entry.get("tier") != expected_tier:
            mismatches.append(
                f"Action {action!r} tier mismatch: config={entry.get('tier')} vs ts={expected_tier}"
            )
    if found_actions == 0:
        mismatches.append("Could not parse LOCAL_EFFORT_MATRIX entries from effort_router.ts")
    return mismatches


def infer_base_tier(
    *,
    category: str,
    complexity: str | None,
    description: str,
    request_meta: dict[str, Any],
    config: dict[str, Any],
) -> tuple[str, str]:
    """Resolve initial complexity tier and rationale before budget/health adjustments."""
    if complexity and complexity in VALID_TIERS:
        return complexity, f"Explicit complexity tier {complexity!r} requested."

    if request_meta.get("requires_deep_reasoning") is True:
        return "critical", "Deep reasoning flag escalated task to critical tier."
    if request_meta.get("requires_architecture_decision") is True:
        return "complex", "Architecture decision flag selected complex tier."

    categories = config["categories"]
    clean_cat = category.strip()
    if clean_cat in categories:
        entry = categories[clean_cat]
        tier = str(entry["tier"])
        rationale = str(entry.get("rationale") or f"Matched category {clean_cat!r}.")
    else:
        prefix_matches = [
            (key, entry)
            for key, entry in categories.items()
            if clean_cat and clean_cat.startswith(key)
        ]
        if prefix_matches:
            prefix_matches.sort(key=lambda item: -len(item[0]))
            _, entry = prefix_matches[0]
            tier = str(entry["tier"])
            rationale = str(entry.get("rationale") or f"Matched prefix for {clean_cat!r}.")
        else:
            combined = f"{clean_cat} {description}".lower()
            if any(word in combined for word in CRITICAL_KEYWORDS):
                tier = "critical"
                rationale = "Task signals critical reasoning or security/migration risk."
            elif any(word in combined for word in COMPLEX_KEYWORDS):
                tier = "complex"
                rationale = "Task signals architecture design or complex review."
            elif any(word in combined for word in TRIVIAL_KEYWORDS):
                tier = "trivial"
                rationale = "Task signals routine classification or retrieval."
            else:
                tier = "standard"
                rationale = "Default standard tier for general tasks."

    if request_meta.get("latency_sensitive") is True and tier == "standard":
        tier = "trivial"
        rationale = f"{rationale} Latency-sensitive override selected trivial tier."
    return tier, rationale


def route_task(
    config: dict[str, Any],
    *,
    category: str = "",
    complexity: str | None = None,
    description: str = "",
    request_meta: dict[str, Any] | None = None,
    remaining_budget_usd: float | None = None,
    unhealthy_models: Sequence[str] = (),
) -> RoutingDecision:
    """Select target provider, model, and fallback chain dynamically."""
    meta = dict(request_meta or {})
    clean_desc, desc_redacts = redact_untrusted_text(description)
    clean_cat, cat_redacts = redact_untrusted_text(category)
    total_redacts = desc_redacts + cat_redacts

    tier, rationale = infer_base_tier(
        category=clean_cat,
        complexity=complexity.strip().lower() if complexity else None,
        description=clean_desc,
        request_meta=meta,
        config=config,
    )

    budget_guard = config["budget_guard"]
    low_threshold = float(budget_guard.get("low_budget_threshold_usd", 5.0))
    hard_stop = float(budget_guard.get("hard_stop_threshold_usd", 0.0))
    downgrade_map = budget_guard.get("downgrade_map", {})

    downgraded_by_budget = False
    budget_exhausted = False
    if remaining_budget_usd is not None:
        if remaining_budget_usd <= hard_stop:
            tier = "trivial"
            downgraded_by_budget = True
            budget_exhausted = True
            rationale = f"{rationale} Budget exhausted; fail-closed minimum tier selected."
        elif remaining_budget_usd < low_threshold and tier != "trivial":
            tier = str(downgrade_map.get(tier, "standard"))
            downgraded_by_budget = True
            rationale = f"{rationale} Downgraded due to low budget reserve (${remaining_budget_usd:.2f})."

    tier_cfg = config["tiers"][tier]
    raw_pool = [tier_cfg["primary"], *tier_cfg.get("fallbacks", [])]
    candidates = [
        ModelCandidate(provider=str(item["provider"]), model=str(item["model"]))
        for item in raw_pool
    ]

    unhealthy_set = {m.strip().lower() for m in unhealthy_models if str(m).strip()}
    healthy_candidates = [
        cand for cand in candidates if cand.model.lower() not in unhealthy_set
    ]
    all_unhealthy = len(healthy_candidates) == 0
    ordered = healthy_candidates if healthy_candidates else candidates
    chosen = ordered[0]

    return RoutingDecision(
        tier=tier,
        effort=str(tier_cfg["effort"]),
        provider=chosen.provider,
        model=chosen.model,
        fallbacks=tuple(ordered[1:]),
        is_frontier=bool(tier_cfg.get("is_frontier", False)),
        downgraded_by_budget=downgraded_by_budget,
        budget_exhausted=budget_exhausted,
        all_candidates_unhealthy=all_unhealthy,
        rationale=rationale,
        category=clean_cat or "unspecified",
        redaction_count=total_redacts,
    )


def analyze_routing_telemetry(
    raw_events: Iterable[dict[str, Any]],
    config: dict[str, Any],
) -> dict[str, Any]:
    """Aggregate per-model call counts, costs, and frontier cost-share alerts."""
    thresholds = config.get("telemetry_thresholds", {})
    cost_alert_usd = float(thresholds.get("cost_alert_usd", 10.0))
    failure_rate_alert = float(thresholds.get("failure_rate_alert", 0.2))
    min_events = int(thresholds.get("min_events_for_failure_alert", 3))
    latency_alert_ms = float(thresholds.get("latency_alert_ms", 30000.0))
    frontier_share_alert = float(thresholds.get("frontier_cost_share_alert", 0.7))

    base = telemetry_report.build_report(
        raw_events,
        cost_alert_usd=cost_alert_usd,
        failure_rate_alert=failure_rate_alert,
        min_events_for_failure_alert=min_events,
        latency_alert_ms=latency_alert_ms,
    )

    tiers = config["tiers"]
    frontier_models: set[str] = set()
    for tier_cfg in tiers.values():
        if tier_cfg.get("is_frontier"):
            frontier_models.add(str(tier_cfg["primary"]["model"]).lower())
            for fb in tier_cfg.get("fallbacks", []):
                frontier_models.add(str(fb["model"]).lower())

    frontier_calls = 0
    frontier_cost = 0.0
    non_frontier_calls = 0
    non_frontier_cost = 0.0
    for model_row in base.get("by_model", []):
        model_name = str(model_row["model"]).lower()
        calls = int(model_row["call_count"])
        cost = float(model_row["estimated_cost_usd"])
        if model_name in frontier_models:
            frontier_calls += calls
            frontier_cost += cost
        else:
            non_frontier_calls += calls
            non_frontier_cost += cost

    total_cost = float(base["total_estimated_cost_usd"])
    frontier_cost_share = round(frontier_cost / total_cost, 4) if total_cost > 0 else 0.0
    alerts = list(base["alerts"])
    if (
        base["event_count"] >= min_events
        and total_cost > 0
        and frontier_cost_share > frontier_share_alert
    ):
        alerts.append(
            {
                "severity": "warning",
                "label": "frontier_cost_share",
                "reason": "frontier_cost_share_threshold",
                "message": (
                    f"Frontier model cost share {frontier_cost_share:.1%} "
                    f"> {frontier_share_alert:.0%} threshold; review routine task offloading."
                ),
            }
        )

    return {
        "schema_version": 1,
        "issue": "#2684",
        "event_count": base["event_count"],
        "total_estimated_cost_usd": total_cost,
        "by_model": base.get("by_model", []),
        "cost_separation": {
            "frontier_calls": frontier_calls,
            "frontier_cost_usd": round(frontier_cost, 6),
            "frontier_cost_share": frontier_cost_share,
            "non_frontier_calls": non_frontier_calls,
            "non_frontier_cost_usd": round(non_frontier_cost, 6),
        },
        "alerts": alerts,
    }


def render_markdown_report(
    *,
    config_valid: bool,
    ts_sync_errors: Sequence[str],
    decision: RoutingDecision | None,
    telemetry_summary: dict[str, Any] | None,
) -> str:
    lines = [
        "## Dynamic LLM Routing & Cost Telemetry Report",
        "",
        f"- Config Valid: `{str(config_valid).lower()}`",
        f"- Edge `effort_router.ts` Sync Errors: `{len(ts_sync_errors)}`",
    ]
    if decision is not None:
        lines.extend(
            [
                "",
                "### Routing Decision",
                f"- Category: `{decision.category}`",
                f"- Tier / Effort: `{decision.tier}` (`{decision.effort}`)",
                f"- Selected Model: `{decision.provider}/{decision.model}` (frontier=`{str(decision.is_frontier).lower()}`)",
                f"- Budget Downgraded: `{str(decision.downgraded_by_budget).lower()}` (exhausted=`{str(decision.budget_exhausted).lower()}`)",
                f"- Rationale: {decision.rationale}",
            ]
        )
    if telemetry_summary is not None:
        sep = telemetry_summary["cost_separation"]
        lines.extend(
            [
                "",
                "### Per-Model Cost Separation",
                f"- Total Events: `{telemetry_summary['event_count']}`, Total Cost: `${telemetry_summary['total_estimated_cost_usd']:.4f}`",
                f"- Frontier Tier: `{sep['frontier_calls']}` calls, `${sep['frontier_cost_usd']:.4f}` ({sep['frontier_cost_share']:.1%})",
                f"- Lightweight/Standard Tier: `{sep['non_frontier_calls']}` calls, `${sep['non_frontier_cost_usd']:.4f}`",
            ]
        )
    rendered = "\n".join(lines).rstrip() + "\n"
    cleaned, _ = redact_untrusted_text(rendered)
    return cleaned


def run_self_test() -> int:
    config = load_routing_config(DEFAULT_CONFIG_PATH)
    sync_errors = check_effort_router_sync(config, DEFAULT_EFFORT_ROUTER_PATH)
    assert not sync_errors, f"TS sync mismatch: {sync_errors}"

    trivial = route_task(config, category="ai.assistant.chat")
    assert trivial.tier == "trivial" and not trivial.is_frontier

    critical = route_task(config, category="architecture_design", request_meta={"requires_deep_reasoning": True})
    assert critical.tier == "critical" and critical.model == "claude-opus-4-7"

    downgraded = route_task(
        config,
        category="deep_reasoning",
        remaining_budget_usd=2.0,
        unhealthy_models=("claude-sonnet-4-6",),
    )
    assert downgraded.tier == "complex" and downgraded.model == "gpt-5.4"

    sample_events = [
        {"event_id": "1", "provider": "anthropic", "model": "claude-haiku-4-5", "task_type": "chat", "status": "success", "estimated_cost_usd": 0.002},
        {"event_id": "2", "provider": "anthropic", "model": "claude-opus-4-7", "task_type": "design", "status": "success", "estimated_cost_usd": 0.08},
    ]
    summary = analyze_routing_telemetry(sample_events, config)
    assert len(summary["by_model"]) == 2
    assert summary["cost_separation"]["frontier_calls"] == 1
    assert summary["cost_separation"]["non_frontier_calls"] == 1

    with tempfile.TemporaryDirectory() as tmp_dir:
        out_path = Path(tmp_dir) / "route.json"
        out_path.write_text(json.dumps(dataclasses.asdict(trivial)), encoding="utf-8")
        assert out_path.is_file()

    print("OK: dynamic_llm_router self-test passed")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG_PATH)
    parser.add_argument("--effort-router", type=Path, default=DEFAULT_EFFORT_ROUTER_PATH)
    parser.add_argument("--validate-config", action="store_true")
    parser.add_argument("--check-ts-sync", action="store_true")
    parser.add_argument("--route-json", type=Path)
    parser.add_argument("--category", default="")
    parser.add_argument("--complexity")
    parser.add_argument("--description", default="")
    parser.add_argument("--remaining-budget-usd", type=float)
    parser.add_argument("--unhealthy-models", default="")
    parser.add_argument("--telemetry-input", type=Path)
    parser.add_argument("--dry-run", action="store_true", help="Run offline routing evaluation without external calls")
    parser.add_argument("--json-out", type=Path)
    parser.add_argument("--markdown-out", type=Path)
    parser.add_argument("--github-output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.self_test:
        return run_self_test()

    config = load_routing_config(args.config)
    sync_errors: list[str] = []
    if args.check_ts_sync or args.validate_config:
        sync_errors = check_effort_router_sync(config, args.effort_router)
        if sync_errors:
            print("Routing sync errors:", file=sys.stderr)
            for err in sync_errors:
                print(f"- {err}", file=sys.stderr)
            return 1

    decision: RoutingDecision | None = None
    unhealthy = [item.strip() for item in args.unhealthy_models.split(",") if item.strip()]
    if args.route_json is not None:
        raw_req = json.loads(args.route_json.read_text(encoding="utf-8-sig"))
        if not isinstance(raw_req, dict):
            raise ValueError("--route-json must decode to a JSON object")
        decision = route_task(
            config,
            category=str(raw_req.get("category") or raw_req.get("action") or ""),
            complexity=raw_req.get("complexity"),
            description=str(raw_req.get("description") or ""),
            request_meta=raw_req.get("request_meta") if isinstance(raw_req.get("request_meta"), dict) else {},
            remaining_budget_usd=raw_req.get("remaining_budget_usd", args.remaining_budget_usd),
            unhealthy_models=raw_req.get("unhealthy_models") or unhealthy,
        )
    elif args.category or args.complexity or args.description:
        decision = route_task(
            config,
            category=args.category,
            complexity=args.complexity,
            description=args.description,
            remaining_budget_usd=args.remaining_budget_usd,
            unhealthy_models=unhealthy,
        )

    telemetry_summary: dict[str, Any] | None = None
    if args.telemetry_input is not None:
        events = telemetry_report.load_events(args.telemetry_input)
        telemetry_summary = analyze_routing_telemetry(events, config)

    payload: dict[str, Any] = {
        "schema_version": 1,
        "mode": "dry_run",
        "config_valid": True,
        "ts_sync_errors": sync_errors,
        "decision": dataclasses.asdict(decision) if decision is not None else None,
        "telemetry": telemetry_summary,
    }
    json_text = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    redacted_json, _ = redact_untrusted_text(json_text)
    md_text = render_markdown_report(
        config_valid=True,
        ts_sync_errors=sync_errors,
        decision=decision,
        telemetry_summary=telemetry_summary,
    )

    if args.json_out is not None:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(redacted_json, encoding="utf-8", newline="\n")
    if args.markdown_out is not None:
        args.markdown_out.parent.mkdir(parents=True, exist_ok=True)
        args.markdown_out.write_text(md_text, encoding="utf-8", newline="\n")
    if args.github_output is not None:
        args.github_output.parent.mkdir(parents=True, exist_ok=True)
        with args.github_output.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write("config_valid=true\n")
            if decision is not None:
                handle.write(f"selected_tier={decision.tier}\n")
                handle.write(f"selected_model={decision.model}\n")
            if telemetry_summary is not None:
                handle.write(f"telemetry_events={telemetry_summary['event_count']}\n")
    if args.json_out is None and args.markdown_out is None:
        print(md_text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
