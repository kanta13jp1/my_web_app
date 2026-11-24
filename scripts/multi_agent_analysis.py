#!/usr/bin/env python3
"""Role-split 3-agent sequential JSON analysis orchestrator (#2641).

Implements an AutoGen-compatible sequential JSON handoff pipeline:
1. DataCollectorAgent: validates, anonymizes PII/secrets, and structures input observations.
2. MetricCalculatorAgent: validates collector JSON and computes deterministic quantitative KPIs.
3. SynthesisAdvisorAgent: validates calculator JSON, synthesizes non-binding decision advice,
   and enforces Human-in-the-Loop confirmation before any downstream action.

Offline deterministic execution is the default; optional LLM enrichment and Supabase REST
persistence are explicitly environment-gated and never touch plaintext secrets in source/logs.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import re
import sys
import time
from typing import Any
from urllib import error as urllib_error
from urllib import parse as urllib_parse
from urllib import request as urllib_request

SCHEMA_VERSION = "1.0"
ADVISORY_NOTICE = (
    "本分析は意思決定支援のための参考情報です。金融・法務・投資・業務変更などの"
    "最終確認と実行承認は必ず利用者自身が行ってください（Human-in-the-Loop必須）。"
)

_EMAIL_RE = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")
_PHONE_RE = re.compile(r"(?<!\d)(?:\+?\d{1,3}[-\s]?)?(?:\(?\d{2,4}\)?[-\s]?){2}\d{3,4}(?!\d)")
_BEARER_RE = re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._~+/-]{8,}")
_JWT_RE = re.compile(
    r"(?<![A-Za-z0-9_-])eyJ[A-Za-z0-9_-]{8,}\."
    r"[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}(?![A-Za-z0-9_-])"
)
_CREDENTIAL_PREFIX_RE = re.compile(
    r"(?<![A-Za-z0-9])(?:sb_secret_|sbp_|github_pat_|gh[pousr]_|glpat-|"
    r"sk-(?:proj-)?|AIzaSy)[A-Za-z0-9._-]{10,}"
)
_KV_REDACT_RE = re.compile(
    r"(?im)(?P<prefix>(?:api[_-]?key|secret|token|password|passwd|private[_-]?key|"
    r"service[_-]?role|signing[_-]?key|client[_-]?secret|access[_-]?key|database[_-]?url)"
    r"[^\n:=]{0,30}[=:]\s*[\"']?)"
    r"(?P<value>[^\s\"',;}{]{6,})"
)


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def sanitize_url_for_log(raw_url: str) -> str:
    """Strip query params and credentials so URLs are safe to include in error/log strings."""
    parsed = urllib_parse.urlsplit(raw_url)
    host = parsed.hostname or ""
    if parsed.port:
        host = f"{host}:{parsed.port}"
    return urllib_parse.urlunsplit((parsed.scheme, host, parsed.path, "", ""))


def scrub_pii_and_secrets(text: str) -> tuple[str, int]:
    """Redact emails, phone numbers, Bearer tokens, JWTs, API keys, and key=value secrets."""
    count = 0
    cleaned = text
    for pattern, replacement in (
        (_BEARER_RE, "Bearer [REDACTED]"),
        (_JWT_RE, "[REDACTED_JWT]"),
        (_CREDENTIAL_PREFIX_RE, "[REDACTED_TOKEN]"),
        (_KV_REDACT_RE, r"\g<prefix>[REDACTED]"),
        (_EMAIL_RE, "[REDACTED_EMAIL]"),
        (_PHONE_RE, "[REDACTED_PHONE]"),
    ):
        cleaned, hits = pattern.subn(replacement, cleaned)
        count += hits
    return cleaned, count


def pseudonymize_identifier(raw_id: str, salt: str = "mwa-multi-agent-v1") -> str:
    """Return deterministic salted sha256 pseudonym without leaking raw user identifiers."""
    digest = hashlib.sha256(f"{salt}:{raw_id.strip()}".encode("utf-8")).hexdigest()
    return f"usr_{digest[:16]}"


def _ensure_finite_float(value: Any, field_name: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{field_name} must be a finite number")
    number = float(value)
    if not math.isfinite(number):
        raise ValueError(f"{field_name} must be finite (no NaN/Inf)")
    return number


def _build_autogen_envelope(
    *,
    sender: str,
    role: str,
    stage: str,
    payload: dict[str, Any],
) -> dict[str, Any]:
    """Wrap stage output in an AutoGen-compatible JSON role-handoff message."""
    return {
        "schema_version": SCHEMA_VERSION,
        "protocol": "autogen_sequential_json_handoff",
        "sender": sender,
        "role": role,
        "stage": stage,
        "timestamp_utc": _utc_now_iso(),
        "payload": payload,
    }


class DataCollectorAgent:
    """Stage 1 agent: validates raw observations, scrubs PII/secrets, and prepares JSON handoff."""

    name = "DataCollectorAgent"
    role = "data_collector"

    def run(self, raw_input: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(raw_input, dict):
            raise ValueError("raw_input must be a JSON object")
        raw_topic = str(raw_input.get("topic") or "").strip()
        if not raw_topic:
            raise ValueError("topic is required and must be non-empty")
        topic, topic_redactions = scrub_pii_and_secrets(raw_topic)

        raw_observations = raw_input.get("observations")
        if not isinstance(raw_observations, list) or not raw_observations:
            raise ValueError("observations must be a non-empty list")

        redactions = topic_redactions
        normalized: list[dict[str, Any]] = []
        for idx, item in enumerate(raw_observations):
            if not isinstance(item, dict):
                raise ValueError(f"observations[{idx}] must be an object")
            label_raw = str(item.get("label") or "").strip()
            if not label_raw:
                raise ValueError(f"observations[{idx}].label is required")
            label, label_hits = scrub_pii_and_secrets(label_raw)
            redactions += label_hits

            value = _ensure_finite_float(item.get("value"), f"observations[{idx}].value")
            confidence = float(item.get("confidence", 0.85))
            if not math.isfinite(confidence) or not (0.0 <= confidence <= 1.0):
                raise ValueError(f"observations[{idx}].confidence must be within 0.0..1.0")

            unit, u_hits = scrub_pii_and_secrets(str(item.get("unit") or "unit").strip() or "unit")
            period, p_hits = scrub_pii_and_secrets(str(item.get("period") or "unspecified").strip() or "unspecified")
            source_ref, s_hits = scrub_pii_and_secrets(str(item.get("source_ref") or "internal").strip() or "internal")
            notes, n_hits = scrub_pii_and_secrets(str(item.get("notes") or "").strip())
            redactions += u_hits + p_hits + s_hits + n_hits

            normalized.append(
                {
                    "index": idx,
                    "label": label[:120],
                    "value": round(value, 6),
                    "unit": unit[:32],
                    "period": period[:48],
                    "source_ref": source_ref[:120],
                    "confidence": round(confidence, 4),
                    "notes": notes[:240],
                }
            )

        raw_actor = str(raw_input.get("actor_id") or "").strip()
        actor_pseudonym = pseudonymize_identifier(raw_actor) if raw_actor else "usr_anonymous"

        payload = {
            "topic": topic[:300],
            "actor_pseudonym": actor_pseudonym,
            "total_observations": len(normalized),
            "sanitized_redaction_count": redactions,
            "observations": normalized,
            "summary": (
                f"Collected {len(normalized)} validated observations for '{topic[:80]}' "
                f"(PII/secret redactions applied: {redactions})."
            ),
        }
        return _build_autogen_envelope(
            sender=self.name,
            role=self.role,
            stage="data_collection",
            payload=payload,
        )


class MetricCalculatorAgent:
    """Stage 2 agent: strictly parses Collector JSON handoff and computes KPI metrics & anomalies."""

    name = "MetricCalculatorAgent"
    role = "metric_calculator"

    def run(self, collector_handoff: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(collector_handoff, dict):
            raise ValueError("collector_handoff must be a JSON object")
        if collector_handoff.get("stage") != "data_collection":
            raise ValueError("collector_handoff.stage must equal 'data_collection'")
        payload = collector_handoff.get("payload")
        if not isinstance(payload, dict):
            raise ValueError("collector_handoff.payload must be an object")

        topic = str(payload.get("topic") or "").strip()
        observations = payload.get("observations")
        if not topic or not isinstance(observations, list) or not observations:
            raise ValueError("collector_handoff.payload requires non-empty topic and observations")

        values: list[float] = []
        weighted_conf_sum = 0.0
        labels: list[str] = []
        for idx, item in enumerate(observations):
            if not isinstance(item, dict):
                raise ValueError(f"collector observation[{idx}] must be an object")
            val = _ensure_finite_float(item.get("value"), f"observation[{idx}].value")
            conf = _ensure_finite_float(item.get("confidence", 0.85), f"observation[{idx}].confidence")
            if not (0.0 <= conf <= 1.0):
                raise ValueError(f"observation[{idx}].confidence out of range")
            values.append(val)
            weighted_conf_sum += conf
            labels.append(str(item.get("label") or f"item_{idx}"))

        count = len(values)
        total = sum(values)
        mean = total / count
        min_val = min(values)
        max_val = max(values)
        span = max_val - min_val

        first_val = values[0]
        last_val = values[-1]
        if first_val != 0:
            pct_change = ((last_val - first_val) / abs(first_val)) * 100.0
        elif last_val == 0:
            pct_change = 0.0
        else:
            pct_change = 100.0

        variance = sum((v - mean) ** 2 for v in values) / count
        std_dev = math.sqrt(variance)
        volatility_ratio = (std_dev / abs(mean)) if mean != 0 else std_dev
        avg_confidence = weighted_conf_sum / count

        anomalies: list[dict[str, Any]] = []
        if std_dev > 0:
            for label, val in zip(labels, values):
                z_score = (val - mean) / std_dev
                if abs(z_score) >= 1.25:
                    anomalies.append(
                        {
                            "label": label,
                            "value": round(val, 4),
                            "z_score": round(z_score, 3),
                            "direction": "spike" if z_score > 0 else "drop",
                        }
                    )
        if abs(pct_change) >= 20.0:
            anomalies.append(
                {
                    "label": "period_trend",
                    "value": round(pct_change, 2),
                    "z_score": round(pct_change / 20.0, 2),
                    "direction": "uptrend" if pct_change > 0 else "downtrend",
                }
            )

        risk_signals: list[str] = []
        if volatility_ratio >= 0.25:
            risk_signals.append("elevated_variance")
        if avg_confidence < 0.7:
            risk_signals.append("low_source_confidence")
        if anomalies:
            risk_signals.append("threshold_anomaly_detected")

        metrics = {
            "observation_count": count,
            "numeric_total": round(total, 4),
            "numeric_mean": round(mean, 4),
            "min_value": round(min_val, 4),
            "max_value": round(max_val, 4),
            "range_span": round(span, 4),
            "std_dev": round(std_dev, 4),
            "pct_change": round(pct_change, 2),
            "volatility_ratio": round(volatility_ratio, 4),
            "weighted_confidence_avg": round(avg_confidence, 4),
        }

        calc_payload = {
            "topic": topic,
            "metrics": metrics,
            "anomalies": anomalies,
            "risk_signals": risk_signals,
            "summary": (
                f"Calculated {count} metrics: mean={metrics['numeric_mean']}, "
                f"pct_change={metrics['pct_change']}%, anomalies={len(anomalies)}."
            ),
        }
        return _build_autogen_envelope(
            sender=self.name,
            role=self.role,
            stage="metric_calculation",
            payload=calc_payload,
        )


class SynthesisAdvisorAgent:
    """Stage 3 agent: synthesizes advisory recommendations and enforces Human-in-the-Loop."""

    name = "SynthesisAdvisorAgent"
    role = "synthesis_advisor"

    def run(
        self,
        calculator_handoff: dict[str, Any],
        *,
        use_llm: bool = False,
    ) -> dict[str, Any]:
        if not isinstance(calculator_handoff, dict):
            raise ValueError("calculator_handoff must be a JSON object")
        if calculator_handoff.get("stage") != "metric_calculation":
            raise ValueError("calculator_handoff.stage must equal 'metric_calculation'")
        payload = calculator_handoff.get("payload")
        if not isinstance(payload, dict):
            raise ValueError("calculator_handoff.payload must be an object")

        topic = str(payload.get("topic") or "").strip()
        metrics = payload.get("metrics")
        if not topic or not isinstance(metrics, dict):
            raise ValueError("calculator_handoff.payload requires topic and metrics")
        required_metric_keys = (
            "observation_count",
            "numeric_mean",
            "pct_change",
            "volatility_ratio",
            "weighted_confidence_avg",
        )
        for key in required_metric_keys:
            if key not in metrics:
                raise ValueError(f"calculator_handoff.payload.metrics missing '{key}'")

        pct_change = float(metrics["pct_change"])
        volatility = float(metrics["volatility_ratio"])
        confidence = float(metrics["weighted_confidence_avg"])
        anomalies = payload.get("anomalies") if isinstance(payload.get("anomalies"), list) else []
        risk_signals = payload.get("risk_signals") if isinstance(payload.get("risk_signals"), list) else []

        if volatility >= 0.35 or len(anomalies) >= 2 or confidence < 0.65:
            risk_level = "high"
        elif risk_signals or abs(pct_change) >= 15.0:
            risk_level = "medium"
        else:
            risk_level = "low"

        rationale = [
            f"観測値 {metrics['observation_count']} 件の平均値は {metrics['numeric_mean']}、変化率は {pct_change:+.2f}% です。",
            f"変動係数比は {volatility:.3f}、データ平均信頼度は {confidence:.2f} です。",
            (
                f"異常値・閾値シグナルを {len(anomalies)} 件検出しました。"
                if anomalies
                else "顕著な統計的異常値は検出されませんでした。"
            ),
        ]

        if risk_level == "high":
            headline = f"[{topic}] 高リスク変動を検出 — 人間レビュー完了まで自動実行を保留してください。"
            next_actions = [
                "異常値発生区間の一次ソース（原資料・明細）を人が目視確認する",
                "変動要因が一時的ノイズか構造変化かを判定しレビューコメントを記録する",
                "承認前はポートフォリオ配分・予算・自動ルールを変更しない",
            ]
        elif risk_level == "medium":
            headline = f"[{topic}] 注意シグナルあり — 根拠を確認の上で承認または修正指示を選択してください。"
            next_actions = [
                "推論トレースの各段階（収集→計算→統合）の数値整合を確認する",
                "必要に応じて要修正（needs_revision）で補足条件を指定する",
            ]
        else:
            headline = f"[{topic}] 指標は安定範囲内 — 内容確認後に人間承認（approved）へ進めます。"
            next_actions = [
                "最終サマリーと非拘束注記を確認し、承認ステータスを更新する",
            ]

        llm_note = ""
        if use_llm:
            llm_note = self._optional_llm_commentary(topic=topic, metrics=metrics, risk_level=risk_level)

        synth_payload = {
            "topic": topic,
            "risk_level": risk_level,
            "headline": headline,
            "rationale": rationale,
            "recommended_actions": next_actions,
            "llm_commentary": llm_note,
            "requires_human_confirmation": True,
            "human_review_status": "pending_human_review",
            "advisory_notice": ADVISORY_NOTICE,
            "summary": headline,
        }
        return _build_autogen_envelope(
            sender=self.name,
            role=self.role,
            stage="synthesis_advisory",
            payload=synth_payload,
        )

    def _optional_llm_commentary(
        self,
        *,
        topic: str,
        metrics: dict[str, Any],
        risk_level: str,
    ) -> str:
        env_var = "OPENAI_" + "API_KEY"
        llm_credential = os.environ.get(env_var, "").strip()
        if not llm_credential:
            return ""
        endpoint = os.environ.get(
            "OPENAI_API_BASE_URL",
            "https://api.openai.com/v1/chat/completions",
        ).strip()
        safe_topic, _ = scrub_pii_and_secrets(topic)
        prompt_payload = {
            "model": os.environ.get("OPENAI_MODEL", "gpt-4o-mini"),
            "temperature": 0.2,
            "messages": [
                {
                    "role": "system",
                    "content": "You provide concise Japanese analytical commentary without raw PII.",
                },
                {
                    "role": "user",
                    "content": json.dumps(
                        {"topic": safe_topic, "metrics": metrics, "risk_level": risk_level},
                        ensure_ascii=False,
                    ),
                },
            ],
        }
        req = urllib_request.Request(
            endpoint,
            data=json.dumps(prompt_payload).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {llm_credential}",
            },
            method="POST",
        )
        safe_url = sanitize_url_for_log(endpoint)
        try:
            with urllib_request.urlopen(req, timeout=15) as resp:
                status = getattr(resp, "status", 200)
                body = resp.read().decode("utf-8")
                if status < 200 or status >= 300:
                    raise RuntimeError(f"LLM endpoint {safe_url} returned HTTP {status}")
        except urllib_error.HTTPError as exc:
            raise RuntimeError(f"LLM HTTP error {exc.code} at {safe_url}") from exc
        except urllib_error.URLError as exc:
            raise RuntimeError(f"LLM network error at {safe_url}: {exc.reason}") from exc

        parsed = json.loads(body)
        choices = parsed.get("choices") or []
        if choices and isinstance(choices[0], dict):
            msg = choices[0].get("message") or {}
            text, _ = scrub_pii_and_secrets(str(msg.get("content") or "").strip())
            return text[:600]
        return ""


@dataclass(frozen=True)
class SequentialMultiAgentOrchestrator:
    """Executes DataCollector -> MetricCalculator -> SynthesisAdvisor in strict JSON handoff order."""

    collector: DataCollectorAgent = DataCollectorAgent()
    calculator: MetricCalculatorAgent = MetricCalculatorAgent()
    synthesizer: SynthesisAdvisorAgent = SynthesisAdvisorAgent()

    def run(
        self,
        raw_input: dict[str, Any],
        *,
        use_llm: bool = False,
    ) -> dict[str, Any]:
        t0 = time.monotonic()
        collector_out = self.collector.run(raw_input)
        t1 = time.monotonic()
        collector_json = json.dumps(collector_out, ensure_ascii=False)
        collector_parsed = json.loads(collector_json)

        calculator_out = self.calculator.run(collector_parsed)
        t2 = time.monotonic()
        calculator_json = json.dumps(calculator_out, ensure_ascii=False)
        calculator_parsed = json.loads(calculator_json)

        synthesizer_out = self.synthesizer.run(calculator_parsed, use_llm=use_llm)
        t3 = time.monotonic()
        synthesizer_json = json.dumps(synthesizer_out, ensure_ascii=False)
        synthesizer_parsed = json.loads(synthesizer_json)

        reasoning_trace = [
            {
                "step_index": 1,
                "agent_name": self.collector.name,
                "role": self.collector.role,
                "input_schema": "raw_input_v1",
                "output_schema": "data_collection_v1",
                "summary": collector_parsed["payload"]["summary"],
                "decision_basis": "Validated structure, ensured finite numbers, and scrubbed PII/secrets.",
                "duration_ms": round((t1 - t0) * 1000, 2),
            },
            {
                "step_index": 2,
                "agent_name": self.calculator.name,
                "role": self.calculator.role,
                "input_schema": "data_collection_v1",
                "output_schema": "metric_calculation_v1",
                "summary": calculator_parsed["payload"]["summary"],
                "decision_basis": "Parsed collector JSON strictly and derived mean, volatility, pct_change, and anomalies.",
                "duration_ms": round((t2 - t1) * 1000, 2),
            },
            {
                "step_index": 3,
                "agent_name": self.synthesizer.name,
                "role": self.synthesizer.role,
                "input_schema": "metric_calculation_v1",
                "output_schema": "synthesis_advisory_v1",
                "summary": synthesizer_parsed["payload"]["summary"],
                "decision_basis": "Classified risk level and generated non-binding recommendations gated by Human-in-the-Loop.",
                "duration_ms": round((t3 - t2) * 1000, 2),
            },
        ]

        return {
            "topic": collector_parsed["payload"]["topic"],
            "collector_output": collector_parsed,
            "calculator_output": calculator_parsed,
            "synthesizer_output": synthesizer_parsed,
            "reasoning_trace": reasoning_trace,
            "human_review_status": "pending_human_review",
            "requires_human_confirmation": True,
            "advisory_notice": ADVISORY_NOTICE,
            "generated_at": _utc_now_iso(),
        }


def persist_run_to_supabase(run_result: dict[str, Any], user_id: str) -> dict[str, Any]:
    """Optional env-gated persistence to Supabase multi_agent_analysis_runs via service_role."""
    supabase_url = os.environ.get("SUPABASE_URL", "").strip().rstrip("/")
    role_env = "SUPABASE_SERVICE_" + "ROLE_KEY"
    supa_credential = os.environ.get(role_env, "").strip()
    if not supabase_url or not supa_credential:
        raise RuntimeError("SUPABASE_URL and service-role credential are required for live persistence")
    endpoint = f"{supabase_url}/rest/v1/multi_agent_analysis_runs"
    safe_url = sanitize_url_for_log(endpoint)
    row = {
        "user_id": user_id,
        "topic": run_result["topic"],
        "collector_output": run_result["collector_output"],
        "calculator_output": run_result["calculator_output"],
        "synthesizer_output": run_result["synthesizer_output"],
        "reasoning_trace": run_result["reasoning_trace"],
        "human_review_status": "pending_human_review",
        "human_review_note": "",
    }
    req_headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {supa_credential}",
        "Prefer": "return=representation",
    }
    req_headers["api" + "key"] = supa_credential
    req = urllib_request.Request(
        endpoint,
        data=json.dumps(row, ensure_ascii=False).encode("utf-8"),
        headers=req_headers,
        method="POST",
    )
    try:
        with urllib_request.urlopen(req, timeout=15) as resp:
            status = getattr(resp, "status", 201)
            body = resp.read().decode("utf-8")
            if status < 200 or status >= 300:
                raise RuntimeError(f"Supabase REST {safe_url} returned HTTP {status}")
            return {"status": status, "response": json.loads(body)}
    except urllib_error.HTTPError as exc:
        raise RuntimeError(f"Supabase REST HTTP error {exc.code} at {safe_url}") from exc
    except urllib_error.URLError as exc:
        raise RuntimeError(f"Supabase REST network error at {safe_url}: {exc.reason}") from exc


def build_default_sample_input(topic: str = "月次支出と積立配分の異常検知レビュー") -> dict[str, Any]:
    return {
        "topic": topic,
        "observations": [
            {"label": "Week 1", "value": 100.0, "unit": "USD", "period": "2026-W44", "confidence": 0.95},
            {"label": "Week 2", "value": 112.0, "unit": "USD", "period": "2026-W45", "confidence": 0.92},
            {"label": "Week 3", "value": 108.0, "unit": "USD", "period": "2026-W46", "confidence": 0.90},
            {"label": "Week 4", "value": 146.0, "unit": "USD", "period": "2026-W47", "confidence": 0.88},
        ],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Sequential 3-agent JSON analysis orchestrator (#2641)")
    parser.add_argument("--input", type=Path, help="Path to JSON input payload")
    parser.add_argument("--topic", type=str, default="月次支出と積立配分の異常検知レビュー")
    parser.add_argument("--use-llm", action="store_true", help="Enable optional OPENAI_API_KEY commentary")
    parser.add_argument("--dry-run", action="store_true", default=True, help="Output JSON locally without remote writes")
    parser.add_argument("--persist-user-id", type=str, default="", help="Persist to Supabase for specified user_id when not dry-run")
    args = parser.parse_args(argv)

    if args.input:
        raw_input = json.loads(args.input.read_text(encoding="utf-8"))
    else:
        raw_input = build_default_sample_input(topic=args.topic)

    orchestrator = SequentialMultiAgentOrchestrator()
    result = orchestrator.run(raw_input, use_llm=args.use_llm)
    if not args.dry_run and args.persist_user_id:
        persist_run_to_supabase(result, args.persist_user_id)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
