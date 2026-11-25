#!/usr/bin/env python3
"""Canonical manifest and report integrity verifier for AI University RSS updates."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ACTIVE_RSS_PROVIDERS: tuple[tuple[str, str, str], ...] = (
    ("google", "https://blog.google/technology/ai/rss/", "Google AI"),
    ("openai", "https://openai.com/news/rss.xml", "OpenAI"),
    ("microsoft", "https://blogs.microsoft.com/ai/feed/", "Microsoft AI"),
    ("amazon", "https://aws.amazon.com/blogs/machine-learning/feed/", "Amazon Bedrock"),
    ("huggingface", "https://huggingface.co/blog/feed.xml", "Hugging Face"),
    ("nvidia", "https://blogs.nvidia.com/feed/", "NVIDIA"),
    ("lightricks", "https://www.lightricks.com/blog/feed", "Lightricks LTX-2"),
    ("arcee_ai", "https://www.arcee.ai/blog/rss.xml", "Arcee AI Trinity"),
    ("minimax", "https://www.minimax.io/blog/rss.xml", "MiniMax Hailuo"),
    ("moondream", "https://moondream.ai/blog/rss.xml", "Moondream VLM"),
    ("rakuten_ai", "https://global.rakuten.com/corp/news/press.rss", "Rakuten AI 3.0"),
    ("pfn", "https://www.preferred.jp/en/feed/", "Preferred Networks (PLaMo)"),
    ("siliconflow", "https://siliconflow.cn/blog/rss.xml", "SiliconFlow"),
    ("novita_ai", "https://novita.ai/blog/rss.xml", "Novita AI"),
    ("deepinfra", "https://deepinfra.com/blog/rss.xml", "DeepInfra"),
    ("nebius", "https://nebius.com/blog/rss.xml", "Nebius AI Studio"),
    ("fal_ai", "https://blog.fal.ai/rss/", "fal.ai"),
    ("fish_audio", "https://fish.audio/blog/rss.xml", "Fish Audio"),
    ("atlas_cloud", "https://www.atlascloud.ai/blog/rss", "Atlas Cloud"),
    ("mira_network", "https://docs.mira.network/blog/rss.xml", "Mira Network"),
    ("gmi_cloud", "https://www.gmicloud.ai/blog/rss.xml", "GMI Cloud"),
    ("inworld", "https://inworld.ai/blog/rss.xml", "Inworld AI"),
    ("coreweave", "https://www.coreweave.com/blog/rss.xml", "CoreWeave"),
    ("lambda_labs", "https://lambda.ai/blog/rss.xml", "Lambda Labs"),
    ("hyperbolic", "https://hyperbolic.ai/blog/rss.xml", "Hyperbolic Labs"),
    ("anyscale", "https://www.anyscale.com/blog/rss.xml", "Anyscale"),
    ("cerebrium", "https://www.cerebrium.ai/blog/rss.xml", "Cerebrium"),
    ("magic_ai", "https://magic.dev/blog/rss.xml", "Magic AI"),
    ("nous_research", "https://nousresearch.com/feed/", "Nous Research (Hermes 4 / Psyche)"),
    ("sierra_ai", "https://sierra.ai/blog/rss.xml", "Sierra (Bret Taylor)"),
    ("figure_ai", "https://figure.ai/news/rss.xml", "Figure AI (Figure 03 / Helix VLA)"),
    ("replit", "https://blog.replit.com/rss.xml", "Replit (Agent 4)"),
    ("cursor", "https://cursor.com/blog/rss.xml", "Cursor (Anysphere)"),
    ("lovable", "https://lovable.dev/blog/rss.xml", "Lovable (Anton Osika)"),
    ("bolt_new", "https://bolt.new/blog/rss.xml", "Bolt.new (StackBlitz)"),
    ("v0", "https://vercel.com/blog/rss.xml", "v0 by Vercel"),
    ("windsurf", "https://windsurf.com/blog/rss.xml", "Windsurf (旧 Codeium / Cascade)"),
    ("hume_ai", "https://www.hume.ai/blog/rss.xml", "Hume AI (EVI / 感情知能 Voice AI)"),
    ("glean", "https://www.glean.com/blog/rss.xml", "Glean (Enterprise Work AI)"),
    ("vapi", "https://vapi.ai/blog/rss.xml", "Vapi (Voice AI Platform)"),
    ("e2b", "https://e2b.dev/blog/rss.xml", "E2B (AI Agent Code Execution)"),
    ("firecrawl", "https://www.firecrawl.dev/blog/rss.xml", "Firecrawl (Web Scraping for AI)"),
    ("weaviate", "https://weaviate.io/blog/rss.xml", "Weaviate (AI-Native Vector DB)"),
    ("livekit", "https://blog.livekit.io/rss/", "LiveKit (Realtime AI Agents)"),
    ("higgsfield", "https://higgsfield.ai/blog/rss.xml", "Higgsfield AI (Multi-Model Video)"),
    ("browserbase", "https://www.browserbase.com/blog/rss.xml", "Browserbase (AI Browser Automation)"),
    ("tavily", "https://blog.tavily.com/rss.xml", "Tavily (AI Search API for Agents)"),
    ("nomic_ai", "https://www.nomic.ai/blog/rss.xml", "Nomic AI (Open Source Embeddings)"),
    ("chroma", "https://www.trychroma.com/blog/rss.xml", "Chroma (Open Source Vector DB)"),
    ("upstage", "https://www.upstage.ai/blog/rss.xml", "Upstage (Solar LLM / Korea AI Unicorn)"),
    ("modal", "https://modal.com/blog/rss.xml", "Modal (Serverless GPU Cloud)"),
    ("runpod", "https://blog.runpod.io/rss/", "RunPod (GPU Cloud Marketplace)"),
    ("scale_ai", "https://scale.com/blog/rss", "Scale AI (Data & Enterprise AI)"),
    ("baseten", "https://www.baseten.co/blog/rss.xml", "Baseten (ML Inference Platform)"),
    ("arize_ai", "https://arize.com/blog/rss/", "Arize AI (LLM Observability)"),
    ("langsmith", "https://blog.langchain.dev/rss/", "LangSmith (LLM Observability by LangChain)"),
    ("comet_ml", "https://www.comet.com/site/blog/feed/", "Comet ML (ML Experiment Tracking & LLM Evals)"),
    ("braintrust", "https://www.braintrust.dev/blog/rss.xml", "Braintrust (AI Observability & Eval Platform)"),
    ("galileo", "https://www.galileo.ai/blog/rss.xml", "Galileo AI (LLM Eval Guardrails Monitoring)"),
    ("prefect", "https://www.prefect.io/blog/rss.xml", "Prefect (Python Workflow Orchestration)"),
    ("confident_ai", "https://www.confident-ai.com/blog/rss.xml", "Confident AI / DeepEval (LLM Evaluation)"),
    ("crewai", "https://www.crewai.com/blog/rss.xml", "CrewAI (Multi-Agent Orchestration)"),
    ("patronus_ai", "https://www.patronus.ai/blog/rss.xml", "Patronus AI (LLM Evaluation & Safety)"),
    ("autogen", "https://devblogs.microsoft.com/autogen/feed/", "AutoGen (Microsoft Research Multi-Agent OSS)"),
    ("agno", "https://www.agno.com/blog/rss.xml", "Agno / phidata (Python-native Agent Framework)"),
    ("haystack", "https://haystack.deepset.ai/blog/feed", "Haystack deepset (OSS RAG & LLM App Framework)"),
    ("zenml", "https://www.zenml.io/blog/rss.xml", "ZenML (MLOps Pipeline OSS)"),
    ("vllm", "https://blog.vllm.ai/feed.xml", "vLLM (UC Berkeley High-Throughput LLM Serving)"),
    ("ragas", "https://docs.ragas.io/blog/rss.xml", "Ragas (RAG Evaluation Framework OSS)"),
    ("continue_dev", "https://blog.continue.dev/rss.xml", "Continue.dev (OSS AI Coding Assistant for VS Code/JetBrains)"),
    ("aider", "https://aider.chat/feed.xml", "Aider (AI Pair Programmer CLI with Git Integration)"),
    ("dspy", "https://dspy.ai/blog/rss.xml", "DSPy (Stanford — Programming not Prompting LLM Framework)"),
    ("pydantic_ai", "https://ai.pydantic.dev/blog/rss.xml", "Pydantic AI (Type-Safe Production Agent Framework)"),
    ("litellm", "https://blog.litellm.ai/rss.xml", "LiteLLM (100+ LLM Unified Proxy / OpenAI Compatible)"),
    ("langgraph", "https://blog.langchain.dev/rss/", "LangGraph (Stateful Multi-Actor LLM Graph Framework)"),
)

START_MARKER = "<!-- ai-university-update:start -->"
END_MARKER = "<!-- ai-university-update:end -->"
RUN_KEY_PREFIX = "<!-- ai-university-update:run-key:"
SECTION_HEADING = "## AI大学コンテンツ更新 (ai-university-update)"

_MARKED_BLOCK_RE = re.compile(
    rf"{re.escape(START_MARKER)}.*?{re.escape(END_MARKER)}\n?",
    flags=re.DOTALL,
)
_LEGACY_SECTION_RE = re.compile(
    rf"^{re.escape(SECTION_HEADING)}\n.*?(?=^## |\Z)",
    flags=re.MULTILINE | re.DOTALL,
)
_RUN_KEY_RE = re.compile(
    r"<!-- ai-university-update:run-key:([^\s>]+) -->"
)


def validate_manifest(
    providers: tuple[tuple[str, str, str], ...] = ACTIVE_RSS_PROVIDERS,
) -> set[str]:
    """Validate that manifest entries are non-empty and provider IDs are unique."""
    seen: set[str] = set()
    for provider_id, rss_url, provider_name in providers:
        pid = provider_id.strip()
        url = rss_url.strip()
        name = provider_name.strip()
        if not pid or "\t" in pid or "\n" in pid:
            raise ValueError(f"Invalid manifest provider id: {provider_id!r}")
        if not url.startswith(("http://", "https://")) or "\t" in url or "\n" in url:
            raise ValueError(f"Invalid manifest RSS URL for {pid}: {rss_url!r}")
        if not name or "\t" in name or "\n" in name:
            raise ValueError(f"Invalid manifest provider name for {pid}: {provider_name!r}")
        if pid in seen:
            raise ValueError(f"Duplicate provider id in manifest: {pid}")
        seen.add(pid)
    if not seen:
        raise ValueError("Active RSS provider manifest is empty")
    return seen


def _parse_provider_list(raw: str) -> list[str]:
    return [token for token in raw.strip().split() if token]


def validate_run_counts(
    *,
    manifest_total: int,
    succeeded: int,
    failed: int,
    skipped: int,
    failed_providers_raw: str,
    skipped_providers_raw: str,
    run_key: str,
) -> tuple[list[str], list[str]]:
    """Verify run counters and provider lists reconcile cleanly against the manifest."""
    known_ids = validate_manifest()
    expected_total = len(known_ids)
    if manifest_total != expected_total:
        raise ValueError(
            f"manifest_total={manifest_total} does not match manifest count={expected_total}"
        )
    if succeeded < 0 or failed < 0 or skipped < 0:
        raise ValueError(
            f"Negative count detected: succeeded={succeeded}, failed={failed}, skipped={skipped}"
        )
    if succeeded > manifest_total:
        raise ValueError(
            f"succeeded={succeeded} exceeds manifest_total={manifest_total}"
        )
    if succeeded + failed + skipped != manifest_total:
        raise ValueError(
            f"Count mismatch: succeeded({succeeded}) + failed({failed}) + skipped({skipped}) "
            f"!= manifest_total({manifest_total})"
        )
    clean_run_key = run_key.strip()
    if not clean_run_key or any(ch.isspace() for ch in clean_run_key) or "-->" in clean_run_key:
        raise ValueError(f"Invalid run_key: {run_key!r}")

    failed_list = _parse_provider_list(failed_providers_raw)
    skipped_list = _parse_provider_list(skipped_providers_raw)
    if len(failed_list) != failed:
        raise ValueError(
            f"failed_providers length ({len(failed_list)}) != failed ({failed})"
        )
    if len(skipped_list) != skipped:
        raise ValueError(
            f"skipped_providers length ({len(skipped_list)}) != skipped ({skipped})"
        )

    for pid in failed_list:
        if pid not in known_ids:
            raise ValueError(f"Unknown failed provider id: {pid!r}")
    for pid in skipped_list:
        if pid not in known_ids:
            raise ValueError(f"Unknown skipped provider id: {pid!r}")
    overlap = set(failed_list) & set(skipped_list)
    if overlap:
        raise ValueError(f"Providers appear in both failed and skipped: {sorted(overlap)}")

    return failed_list, skipped_list


def render_report_section(
    *,
    run_key: str,
    manifest_total: int,
    succeeded: int,
    failed: int,
    skipped: int,
    failed_list: list[str],
    skipped_list: list[str],
) -> str:
    failed_text = ", ".join(failed_list) if failed_list else "なし"
    skipped_text = ", ".join(skipped_list) if skipped_list else "なし"
    lines = [
        START_MARKER,
        f"{RUN_KEY_PREFIX}{run_key.strip()} -->",
        SECTION_HEADING,
        "",
        f"- 実行キー: `{run_key.strip()}`",
        f"- マニフェスト総数: {manifest_total}社",
        f"- 更新成功: {succeeded}/{manifest_total}（失敗: {failed}、スキップ: {skipped}）",
        f"- 失敗プロバイダー: {failed_text}",
        f"- スキッププロバイダー: {skipped_text}",
        END_MARKER,
    ]
    return "\n".join(lines) + "\n"


def _strip_existing_sections(text: str) -> str:
    cleaned = _MARKED_BLOCK_RE.sub("", text)
    cleaned = _LEGACY_SECTION_RE.sub("", cleaned)
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned).rstrip()
    return cleaned


def _verify_rendered_report(content: str, expected_run_key: str) -> None:
    start_count = content.count(START_MARKER)
    end_count = content.count(END_MARKER)
    heading_count = len(
        re.findall(rf"^{re.escape(SECTION_HEADING)}$", content, flags=re.MULTILINE)
    )
    run_keys = _RUN_KEY_RE.findall(content)
    if start_count != 1 or end_count != 1 or heading_count != 1:
        raise ValueError(
            f"Duplicate or missing AI University section after upsert: "
            f"start={start_count}, end={end_count}, heading={heading_count}"
        )
    if run_keys != [expected_run_key.strip()]:
        raise ValueError(
            f"Run key invariant failed after upsert: found={run_keys}, expected={[expected_run_key.strip()]}"
        )


def upsert_daily_report(
    *,
    report_path: Path,
    date_label: str,
    run_key: str,
    manifest_total: int,
    succeeded: int,
    failed: int,
    skipped: int,
    failed_providers_raw: str,
    skipped_providers_raw: str,
) -> str:
    failed_list, skipped_list = validate_run_counts(
        manifest_total=manifest_total,
        succeeded=succeeded,
        failed=failed,
        skipped=skipped,
        failed_providers_raw=failed_providers_raw,
        skipped_providers_raw=skipped_providers_raw,
        run_key=run_key,
    )
    existing = (
        report_path.read_text(encoding="utf-8").replace("\r\n", "\n")
        if report_path.exists()
        else f"# 自分株式会社 日次レポート {date_label}\n"
    )
    prefix = _strip_existing_sections(existing)
    section = render_report_section(
        run_key=run_key,
        manifest_total=manifest_total,
        succeeded=succeeded,
        failed=failed,
        skipped=skipped,
        failed_list=failed_list,
        skipped_list=skipped_list,
    )
    rendered = f"{prefix}\n\n{section}" if prefix else section
    _verify_rendered_report(rendered, run_key)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    with report_path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(rendered)
    return rendered


def render_step_summary(
    *,
    timestamp: str,
    run_key: str,
    manifest_total: int,
    succeeded: int,
    failed: int,
    skipped: int,
    failed_providers_raw: str,
    skipped_providers_raw: str,
) -> str:
    failed_list, skipped_list = validate_run_counts(
        manifest_total=manifest_total,
        succeeded=succeeded,
        failed=failed,
        skipped=skipped,
        failed_providers_raw=failed_providers_raw,
        skipped_providers_raw=skipped_providers_raw,
        run_key=run_key,
    )
    failed_text = ", ".join(failed_list) if failed_list else "なし"
    skipped_text = ", ".join(skipped_list) if skipped_list else "なし"
    return "\n".join(
        [
            f"## AI大学コンテンツ更新 {timestamp}",
            "",
            "| 項目 | 値 |",
            "| --- | --- |",
            f"| 実行キー | `{run_key.strip()}` |",
            f"| マニフェスト総数 | {manifest_total}社 |",
            f"| 更新成功 | {succeeded}/{manifest_total}（失敗: {failed}、スキップ: {skipped}） |",
            f"| 失敗プロバイダー | {failed_text} |",
            f"| スキッププロバイダー | {skipped_text} |",
            "",
        ]
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("count", help="Print the number of active RSS providers.")
    subparsers.add_parser("list-tsv", help="Print provider, url, name rows as TSV.")

    def add_run_count_args(target: argparse.ArgumentParser) -> None:
        target.add_argument("--manifest-total", type=int, required=True)
        target.add_argument("--succeeded", type=int, required=True)
        target.add_argument("--failed", type=int, required=True)
        target.add_argument("--skipped", type=int, required=True)
        target.add_argument("--failed-providers", default="")
        target.add_argument("--skipped-providers", default="")
        target.add_argument("--run-key", required=True)

    validate_p = subparsers.add_parser(
        "validate-run",
        help="Validate run counts against the canonical RSS provider manifest.",
    )
    add_run_count_args(validate_p)

    upsert_p = subparsers.add_parser(
        "upsert-report",
        help="Validate counts and upsert one run-keyed section in daily report.",
    )
    upsert_p.add_argument("--report-path", required=True, type=Path)
    upsert_p.add_argument("--date", required=True)
    add_run_count_args(upsert_p)

    summary_p = subparsers.add_parser(
        "render-summary",
        help="Validate counts and emit GITHUB_STEP_SUMMARY markdown.",
    )
    summary_p.add_argument("--timestamp", required=True)
    add_run_count_args(summary_p)

    return parser


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")

    args = build_parser().parse_args(argv)
    try:
        if args.command == "count":
            validate_manifest()
            print(len(ACTIVE_RSS_PROVIDERS))
            return 0
        if args.command == "list-tsv":
            validate_manifest()
            for provider_id, rss_url, provider_name in ACTIVE_RSS_PROVIDERS:
                print(f"{provider_id}\t{rss_url}\t{provider_name}")
            return 0
        if args.command == "validate-run":
            validate_run_counts(
                manifest_total=args.manifest_total,
                succeeded=args.succeeded,
                failed=args.failed,
                skipped=args.skipped,
                failed_providers_raw=args.failed_providers,
                skipped_providers_raw=args.skipped_providers,
                run_key=args.run_key,
            )
            return 0
        if args.command == "upsert-report":
            upsert_daily_report(
                report_path=args.report_path,
                date_label=args.date,
                run_key=args.run_key,
                manifest_total=args.manifest_total,
                succeeded=args.succeeded,
                failed=args.failed,
                skipped=args.skipped,
                failed_providers_raw=args.failed_providers,
                skipped_providers_raw=args.skipped_providers,
            )
            return 0
        if args.command == "render-summary":
            print(
                render_step_summary(
                    timestamp=args.timestamp,
                    run_key=args.run_key,
                    manifest_total=args.manifest_total,
                    succeeded=args.succeeded,
                    failed=args.failed,
                    skipped=args.skipped,
                    failed_providers_raw=args.failed_providers,
                    skipped_providers_raw=args.skipped_providers,
                ),
                end="",
            )
            return 0
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
