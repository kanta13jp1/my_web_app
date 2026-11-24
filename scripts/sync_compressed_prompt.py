#!/usr/bin/env python3
"""Synchronize and verify COMPRESSED_PROMPT.md, pre-push rebase protocol, and CI analyze gate (#2680)."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import tempfile
from pathlib import Path
from typing import Any


SYNC_START = "<!-- COMPRESSED_PROMPT_SYNC:START -->"
SYNC_END = "<!-- COMPRESSED_PROMPT_SYNC:END -->"
CANONICAL_MARKER = "## Current 2-Instance Override"
REQUIRED_ANALYSIS_ERRORS = (
    "unused_import: error",
    "unused_local_variable: error",
    "dead_code: error",
    "unused_element: error",
)


def _read_lf(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def compute_v3_checksum(v3_text: str) -> str:
    normalized = v3_text.replace("\r\n", "\n")
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()[:16]


def collect_repo_metrics(repo_root: Path) -> dict[str, int]:
    """Collect deterministic repository artifact counts from tracked layout."""
    migrations_dir = repo_root / "supabase" / "migrations"
    functions_dir = repo_root / "supabase" / "functions"
    workflows_dir = repo_root / ".github" / "workflows"
    features_dir = repo_root / "lib" / "features"

    migrations_count = len(list(migrations_dir.glob("*.sql"))) if migrations_dir.exists() else 0
    edge_functions_count = (
        len([p for p in functions_dir.iterdir() if p.is_dir() and not p.name.startswith("_")])
        if functions_dir.exists()
        else 0
    )
    workflows_count = (
        len([*workflows_dir.glob("*.yml"), *workflows_dir.glob("*.yaml")])
        if workflows_dir.exists()
        else 0
    )
    features_count = (
        len([p for p in features_dir.iterdir() if p.is_dir()])
        if features_dir.exists()
        else 0
    )
    return {
        "migrations": migrations_count,
        "edge_functions": edge_functions_count,
        "workflows": workflows_count,
        "features": features_count,
    }


def verify_ci_analyze_contract(repo_root: Path) -> dict[str, Any]:
    """Verify `.github/workflows/ci.yml`, `quality_gate.py`, and `analysis_options.yaml` enforce 0 analyze findings."""
    violations: list[str] = []

    ci_path = repo_root / ".github" / "workflows" / "ci.yml"
    if not ci_path.exists():
        violations.append(".github/workflows/ci.yml missing")
    else:
        ci_text = _read_lf(ci_path)
        if "quality_gate.py --analyze-only" not in ci_text and "flutter analyze" not in ci_text:
            violations.append(".github/workflows/ci.yml missing analyze step")
        analyze_match = re.search(
            r"-\s+name:\s+Analyze code\b(?P<block>.*?)(?=\n\s*-\s+name:|\Z)",
            ci_text,
            flags=re.DOTALL,
        )
        if not analyze_match:
            violations.append(".github/workflows/ci.yml missing `Analyze code` step")
        else:
            block = analyze_match.group("block")
            if re.search(r"continue-on-error\s*:\s*true", block, re.IGNORECASE):
                violations.append("Analyze code step must not set continue-on-error: true")
            if "--no-fatal-warnings" in block or "--no-fatal-infos" in block:
                violations.append("Analyze code step must not weaken analyzer exit flags")

    qg_path = repo_root / "scripts" / "quality_gate.py"
    if qg_path.exists():
        qg_text = _read_lf(qg_path)
        for bad_flag in ("--no-fatal-warnings", "--no-fatal-infos"):
            if bad_flag in qg_text:
                violations.append(f"scripts/quality_gate.py contains forbidden weakening flag {bad_flag}")

    ao_path = repo_root / "analysis_options.yaml"
    if not ao_path.exists():
        violations.append("analysis_options.yaml missing")
    else:
        ao_text = _read_lf(ao_path)
        for rule in REQUIRED_ANALYSIS_ERRORS:
            if rule not in ao_text:
                violations.append(f"analysis_options.yaml missing strict rule `{rule}`")

    return {
        "ok": len(violations) == 0,
        "violations": violations,
    }


def verify_rebase_sync_protocol(repo_root: Path) -> dict[str, Any]:
    """Verify pre-push `git pull --rebase` protocol across prompt docs and opt-in git hooks."""
    violations: list[str] = []

    v3_path = repo_root / ".github" / "COMPRESSED_PROMPT_V3.md"
    if not v3_path.exists():
        violations.append(".github/COMPRESSED_PROMPT_V3.md missing")
    else:
        v3_text = _read_lf(v3_path)
        if "git pull --rebase" not in v3_text:
            violations.append(".github/COMPRESSED_PROMPT_V3.md missing `git pull --rebase` rule")

    pre_push_path = repo_root / ".githooks" / "pre-push"
    if not pre_push_path.exists():
        violations.append(".githooks/pre-push missing")
    else:
        pp_text = _read_lf(pre_push_path)
        if "sync_compressed_prompt.py" not in pp_text:
            violations.append(".githooks/pre-push must invoke scripts/sync_compressed_prompt.py")
        if "origin/main" not in pp_text or "git pull --rebase" not in pp_text:
            violations.append(".githooks/pre-push must guard against behind origin/main and instruct `git pull --rebase`")

    pre_commit_path = repo_root / ".githooks" / "pre-commit"
    if not pre_commit_path.exists():
        violations.append(".githooks/pre-commit missing")

    remote_sync_path = repo_root / "scripts" / "check_remote_synced.py"
    if not remote_sync_path.exists():
        violations.append("scripts/check_remote_synced.py missing")

    return {
        "ok": len(violations) == 0,
        "violations": violations,
    }


def render_compressed_prompt(repo_root: Path) -> tuple[str, dict[str, Any]]:
    """Render canonical root `COMPRESSED_PROMPT.md` synchronized with `.github/COMPRESSED_PROMPT_V3.md`."""
    v3_path = repo_root / ".github" / "COMPRESSED_PROMPT_V3.md"
    if not v3_path.exists():
        raise FileNotFoundError(f"missing source prompt: {v3_path}")

    v3_text = _read_lf(v3_path)
    v3_lines = len(v3_text.splitlines())
    v3_checksum = compute_v3_checksum(v3_text)
    metrics = collect_repo_metrics(repo_root)
    analyze_contract = verify_ci_analyze_contract(repo_root)
    rebase_contract = verify_rebase_sync_protocol(repo_root)

    metadata = {
        "v3_checksum": v3_checksum,
        "v3_lines": v3_lines,
        "metrics": metrics,
        "ci_analyze_strict": analyze_contract["ok"],
        "rebase_protocol_ok": rebase_contract["ok"],
    }

    sync_payload = json.dumps(
        {
            "source": ".github/COMPRESSED_PROMPT_V3.md",
            "v3_checksum": v3_checksum,
            "v3_lines": v3_lines,
            "metrics": metrics,
            "ci_analyze_gate": "strict-zero-errors-zero-warnings",
            "pre_push_rebase_guard": ".githooks/pre-push",
        },
        ensure_ascii=False,
        indent=2,
    )

    doc = "\n".join(
        [
            "# 自分株式会社 共有コンテキスト同期メモリ (`COMPRESSED_PROMPT.md`)",
            "",
            "> 正規詳細版: [`.github/COMPRESSED_PROMPT_V3.md`](.github/COMPRESSED_PROMPT_V3.md) / "
            "Codex運用: [`AGENTS.md`](AGENTS.md) / Claude運用: [`CLAUDE.md`](CLAUDE.md)",
            "> このファイルは `python scripts/sync_compressed_prompt.py --write` で決定論的に生成・同期されます。",
            "",
            "## Current 2-Instance Override",
            "",
            "並列作業時は以下の2インスタンス体制と共有ルールを必ず遵守し、重複実装・静的解析エラーを防ぎます。",
            "",
            "| レーン | 主な担当領域 | 同期・検証ゲート |",
            "| --- | --- | --- |",
            "| **Claude Code #1 (Windows app)** | アーキテクチャ設計・調査・ドキュメント・WBS/UXトリアージ | `docs/`, `AGENTS.md`, `CLAUDE.md` |",
            "| **Codex #1 (Windows app)** | 実装・CI/CD・GitHub PR・Edge Functions・マイグレーション | Cloud CI + `sync_compressed_prompt.py --check` |",
            "| **User / Automation** | 手動承認・スケジュール監視・GitHub Actions | `permissions: {}` 最小権限実行 |",
            "",
            "## 必須プッシュ前同期プロトコル (`git pull --rebase`)",
            "",
            "全エージェントおよび開発者は、コミット・プッシュ直前に必ず以下を実行し、他インスタンスの変更と競合なく同期します。",
            "",
            "```bash",
            "git stash",
            "git pull --rebase origin main",
            "git push",
            "git stash pop",
            "```",
            "",
            "- オプトイン Git フック有効化: `git config core.hooksPath .githooks`",
            "- `.githooks/pre-commit`: Dart ファイルの重複 `dispose` / `setState` を事前検証 (`scripts/check_duplicate_dispose.py`)。",
            "- `.githooks/pre-push`: `COMPRESSED_PROMPT.md` 同期確認 (`scripts/sync_compressed_prompt.py --check`) と `origin/main` 遅延検知（`git pull --rebase origin main` 要求）。",
            "",
            "## CI/CD `flutter analyze` 0エラー・0警告 厳格通過条件",
            "",
            "- `.github/workflows/ci.yml` (`Analyze code`) は `python scripts/quality_gate.py --analyze-only --analyzer-artifact-dir .ci-logs/analyzer` を `continue-on-error` なしで実行します。",
            "- `analysis_options.yaml` により `unused_import` / `unused_local_variable` / `dead_code` / `unused_element` / `prefer_const_constructors` 等の違反はすべてビルド失敗として拒否されます。",
            "- ローカルでの `COMPRESSED_PROMPT.md` 整合検証は `python scripts/sync_compressed_prompt.py --check` で実行できます。",
            "",
            "## 同期スナップショット",
            "",
            f"{SYNC_START}",
            "```json",
            sync_payload,
            "```",
            f"{SYNC_END}",
            "",
        ],
    )
    return doc, metadata


def check_sync_state(repo_root: Path, *, strict_metrics: bool = False) -> dict[str, Any]:
    """Validate parity between `.github/COMPRESSED_PROMPT_V3.md`, `COMPRESSED_PROMPT.md`, hooks, and CI."""
    violations: list[str] = []

    analyze_contract = verify_ci_analyze_contract(repo_root)
    rebase_contract = verify_rebase_sync_protocol(repo_root)
    violations.extend(analyze_contract["violations"])
    violations.extend(rebase_contract["violations"])

    prompt_path = repo_root / "COMPRESSED_PROMPT.md"
    v3_path = repo_root / ".github" / "COMPRESSED_PROMPT_V3.md"

    if not v3_path.exists():
        violations.append(".github/COMPRESSED_PROMPT_V3.md missing")
        expected_checksum = ""
        live_metrics: dict[str, int] = {}
    else:
        expected_checksum = compute_v3_checksum(_read_lf(v3_path))
        live_metrics = collect_repo_metrics(repo_root)

    parsed_snapshot: dict[str, Any] = {}
    if not prompt_path.exists():
        violations.append("COMPRESSED_PROMPT.md missing at repository root")
    else:
        raw_bytes = prompt_path.read_bytes()
        if raw_bytes.startswith(b"\xef\xbb\xbf"):
            violations.append("COMPRESSED_PROMPT.md must not contain UTF-8 BOM")
        if b"\r\n" in raw_bytes:
            violations.append("COMPRESSED_PROMPT.md must use LF line endings")

        content = raw_bytes.decode("utf-8", errors="replace")
        if CANONICAL_MARKER not in content:
            violations.append(f"COMPRESSED_PROMPT.md missing `{CANONICAL_MARKER}`")
        if "git pull --rebase" not in content:
            violations.append("COMPRESSED_PROMPT.md missing `git pull --rebase` protocol")
        if "flutter analyze" not in content:
            violations.append("COMPRESSED_PROMPT.md missing `flutter analyze` gate documentation")

        if SYNC_START not in content or SYNC_END not in content:
            violations.append("COMPRESSED_PROMPT.md missing sync metadata delimiters")
        else:
            block = content.split(SYNC_START, 1)[1].split(SYNC_END, 1)[0]
            json_match = re.search(r"```json\s*(\{.*?\})\s*```", block, flags=re.DOTALL)
            if not json_match:
                violations.append("COMPRESSED_PROMPT.md sync block missing valid JSON block")
            else:
                try:
                    parsed_snapshot = json.loads(json_match.group(1))
                except json.JSONDecodeError as exc:
                    violations.append(f"COMPRESSED_PROMPT.md sync JSON invalid: {exc}")
                else:
                    recorded_checksum = str(parsed_snapshot.get("v3_checksum") or "")
                    if expected_checksum and recorded_checksum != expected_checksum:
                        violations.append(
                            f"COMPRESSED_PROMPT.md v3_checksum `{recorded_checksum}` out of sync with "
                            f".github/COMPRESSED_PROMPT_V3.md `{expected_checksum}`",
                        )
                    recorded_metrics = parsed_snapshot.get("metrics")
                    if not isinstance(recorded_metrics, dict):
                        violations.append("COMPRESSED_PROMPT.md sync metrics must be a JSON object")
                    else:
                        for metric_key in ("migrations", "edge_functions", "workflows", "features"):
                            val = recorded_metrics.get(metric_key)
                            if isinstance(val, bool) or not isinstance(val, int) or val < 0:
                                violations.append(
                                    f"COMPRESSED_PROMPT.md metrics missing non-negative integer `{metric_key}`",
                                )
                    if strict_metrics and recorded_metrics != live_metrics:
                        violations.append(
                            f"COMPRESSED_PROMPT.md metrics {recorded_metrics} != live {live_metrics}",
                        )

    return {
        "issue": 2680,
        "status": "synced" if not violations else "out_of_sync",
        "in_sync": len(violations) == 0,
        "expected_v3_checksum": expected_checksum,
        "recorded_v3_checksum": parsed_snapshot.get("v3_checksum", ""),
        "live_metrics": live_metrics,
        "recorded_metrics": parsed_snapshot.get("metrics", {}),
        "ci_analyze_strict": analyze_contract["ok"],
        "rebase_protocol_ok": rebase_contract["ok"],
        "violations": violations,
    }


def run_self_test(repo_root: Path) -> dict[str, Any]:
    result = check_sync_state(repo_root, strict_metrics=False)
    if not result["in_sync"]:
        raise RuntimeError(f"live repo sync check failed: {result['violations']}")

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        for rel in (
            ".github/COMPRESSED_PROMPT_V3.md",
            ".github/workflows/ci.yml",
            "scripts/quality_gate.py",
            "analysis_options.yaml",
            ".githooks/pre-commit",
            ".githooks/pre-push",
            "scripts/check_remote_synced.py",
        ):
            src = repo_root / rel
            dst = tmp / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(src.read_bytes())

        doc, _ = render_compressed_prompt(tmp)
        (tmp / "COMPRESSED_PROMPT.md").write_text(doc, encoding="utf-8", newline="\n")
        assert check_sync_state(tmp)["in_sync"] is True

        # Drift detection when V3 updates without regenerating COMPRESSED_PROMPT.md
        v3 = tmp / ".github" / "COMPRESSED_PROMPT_V3.md"
        v3.write_text(_read_lf(v3) + "\n<!-- drift test -->\n", encoding="utf-8", newline="\n")
        drift = check_sync_state(tmp)
        assert drift["in_sync"] is False
        assert any("out of sync" in v for v in drift["violations"])

    return {"self_test": "passed", "checks": 2, "v3_checksum": result["expected_v3_checksum"]}


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", default=False)
    mode.add_argument("--write", action="store_true", default=False)
    mode.add_argument("--dry-run", action="store_true", default=False)
    parser.add_argument("--strict-metrics", action="store_true", default=False)
    parser.add_argument("--json-out", type=Path, default=None)
    parser.add_argument("--markdown-out", type=Path, default=None)
    parser.add_argument("--github-output", type=Path, default=None)
    parser.add_argument("--self-test", action="store_true", default=False)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    root = args.repo_root.resolve()

    if args.self_test:
        print(json.dumps(run_self_test(root), ensure_ascii=False))
        return 0

    if args.write:
        doc, metadata = render_compressed_prompt(root)
        target = root / "COMPRESSED_PROMPT.md"
        target.write_text(doc, encoding="utf-8", newline="\n")
        print(
            f"Updated {target.name} (v3_checksum={metadata['v3_checksum']}, "
            f"metrics={metadata['metrics']})",
        )
        return 0

    result = check_sync_state(root, strict_metrics=args.strict_metrics)
    summary_lines = [
        "### Compressed Prompt Sync Check (#2680)",
        f"- Status: `{result['status']}` | In Sync: `{result['in_sync']}`",
        f"- V3 Checksum: `{result['expected_v3_checksum']}` | Recorded: `{result['recorded_v3_checksum']}`",
        f"- CI Analyze Strict: `{result['ci_analyze_strict']}` | Rebase Protocol OK: `{result['rebase_protocol_ok']}`",
    ]
    for item in result["violations"]:
        summary_lines.append(f"- Violation: {item}")
    md = "\n".join(summary_lines) + "\n"
    print(md, end="")

    if args.json_out is not None:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if args.markdown_out is not None:
        args.markdown_out.parent.mkdir(parents=True, exist_ok=True)
        args.markdown_out.write_text(md, encoding="utf-8")
    if args.github_output is not None:
        args.github_output.parent.mkdir(parents=True, exist_ok=True)
        with args.github_output.open("a", encoding="utf-8") as handle:
            handle.write(f"status={result['status']}\n")
            handle.write(f"in_sync={str(result['in_sync']).lower()}\n")
            handle.write(f"ci_analyze_strict={str(result['ci_analyze_strict']).lower()}\n")
            handle.write(f"rebase_protocol_ok={str(result['rebase_protocol_ok']).lower()}\n")

    if args.dry_run:
        return 0
    return 0 if result["in_sync"] else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
