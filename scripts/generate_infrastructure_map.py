#!/usr/bin/env python3
"""Generate deterministic infrastructure documentation from repository sources."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

CREATE_TABLE_RE = re.compile(
    r"\bcreate\s+table\s+(?:if\s+not\s+exists\s+)?(?P<name>(?:\"?[A-Za-z_][\w$-]*\"?\.)?\"?[A-Za-z_][\w$-]*\"?)",
    re.IGNORECASE,
)
CREATE_FUNCTION_RE = re.compile(
    r"\bcreate\s+(?:or\s+replace\s+)?function\s+(?P<name>(?:\"?[A-Za-z_][\w$-]*\"?\.)?\"?[A-Za-z_][\w$-]*\"?)",
    re.IGNORECASE,
)
FOREIGN_KEY_RE = re.compile(
    r"\breferences\s+(?P<name>(?:\"?[A-Za-z_][\w$-]*\"?\.)?\"?[A-Za-z_][\w$-]*\"?)",
    re.IGNORECASE,
)
DATA_REFERENCE_RE = re.compile(
    r"\b(?:from|join|update|into|delete\s+from)\s+(?P<name>(?:\"?[A-Za-z_][\w$-]*\"?\.)?\"?[A-Za-z_][\w$-]*\"?)",
    re.IGNORECASE,
)
BUCKET_INSERT_RE = re.compile(
    r"\binsert\s+into\s+storage\.buckets\b(?P<body>.*?);",
    re.IGNORECASE | re.DOTALL,
)
QUOTED_VALUE_RE = re.compile(r"['\"](?P<value>[^'\"]+)['\"]")
WORKFLOW_INFRA_PATTERNS = {
    "Supabase migrations": ("supabase db ", "supabase/migrations", "db push"),
    "Supabase Edge Functions": ("supabase functions", "supabase/functions"),
    "Supabase platform": ("supabase",),
    "Firebase Hosting": ("firebase deploy", "firebase hosting"),
    "GitHub Wiki/docs": (".wiki.git", "docs/generated", "infrastructure-docs"),
    "Notion": ("notion",),
}


@dataclass(frozen=True, order=True)
class Dependency:
    source: str
    target: str
    kind: str
    source_path: str


@dataclass
class Resource:
    name: str
    kind: str
    source_paths: set[str] = field(default_factory=set)


@dataclass
class Workflow:
    path: str
    name: str
    triggers: list[str]
    jobs: list[str]
    needs: list[tuple[str, str]]
    infrastructure: list[str]


@dataclass
class Inventory:
    resources: dict[str, Resource] = field(default_factory=dict)
    dependencies: set[Dependency] = field(default_factory=set)
    workflows: list[Workflow] = field(default_factory=list)


def strip_sql_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.DOTALL)
    return re.sub(r"--[^\n]*", " ", text)


def clean_identifier(value: str, default_schema: str = "public") -> str:
    parts = [part.strip().strip('"') for part in value.split(".")]
    return ".".join(parts) if len(parts) > 1 else f"{default_schema}.{parts[0]}"


def add_resource(inventory: Inventory, name: str, kind: str, source_path: str) -> None:
    current = inventory.resources.setdefault(name, Resource(name=name, kind=kind))
    if current.kind == "table (referenced)" and kind == "table":
        current.kind = kind
    current.source_paths.add(source_path)


def sql_files(repo_root: Path) -> Iterable[Path]:
    migrations = repo_root / "supabase" / "migrations"
    if not migrations.exists():
        return []
    return sorted(path for path in migrations.rglob("*.sql") if path.is_file())


def parse_sql(repo_root: Path, inventory: Inventory) -> None:
    parsed_files: list[tuple[str, str]] = []
    for path in sql_files(repo_root):
        relative = path.relative_to(repo_root).as_posix()
        source = strip_sql_comments(path.read_text(encoding="utf-8", errors="replace"))
        parsed_files.append((relative, source))

        for match in CREATE_TABLE_RE.finditer(source):
            table = clean_identifier(match.group("name"))
            add_resource(inventory, table, "table", relative)
            segment_end = source.find(";", match.end())
            segment = source[match.end() : segment_end if segment_end >= 0 else len(source)]
            for reference in FOREIGN_KEY_RE.finditer(segment):
                target = clean_identifier(reference.group("name"))
                add_resource(inventory, target, "table (referenced)", relative)
                inventory.dependencies.add(Dependency(table, target, "foreign key", relative))

        for insert in BUCKET_INSERT_RE.finditer(source):
            value = QUOTED_VALUE_RE.search(insert.group("body"))
            if value:
                add_resource(
                    inventory,
                    f"storage.bucket:{value.group('value')}",
                    "storage bucket",
                    relative,
                )

    ignored_schemas = {"old", "new", "excluded"}
    ignored_identifiers = {
        "anon",
        "authenticated",
        "false",
        "null",
        "on",
        "own",
        "public",
        "select",
        "service_role",
        "set",
        "to",
        "true",
        "values",
    }
    for relative, source in parsed_files:
        function_matches = list(CREATE_FUNCTION_RE.finditer(source))
        for index, match in enumerate(function_matches):
            function = clean_identifier(match.group("name"))
            add_resource(inventory, function, "RPC/function", relative)

            limit = (
                function_matches[index + 1].start()
                if index + 1 < len(function_matches)
                else len(source)
            )
            function_tail = source[match.end() : limit]
            quote = re.search(
                r"\bas\s+(?P<tag>\$[A-Za-z0-9_]*\$)",
                function_tail,
                flags=re.IGNORECASE,
            )
            if quote:
                closing = function_tail.find(quote.group("tag"), quote.end())
                body = (
                    function_tail[quote.end() : closing]
                    if closing >= 0
                    else function_tail[quote.end() :]
                )
            else:
                body = function_tail

            for data_match in DATA_REFERENCE_RE.finditer(body):
                raw_target = data_match.group("name").strip().strip('"')
                parts = [part.strip('"') for part in raw_target.split(".")]
                if parts[0].lower() in ignored_schemas:
                    continue
                if len(parts) == 1 and parts[0].lower() in ignored_identifiers:
                    continue

                target = clean_identifier(raw_target)
                known = inventory.resources.get(target)
                if len(parts) == 1 and (
                    known is None or not known.kind.startswith("table")
                ):
                    continue
                if target == function:
                    continue
                add_resource(inventory, target, "table (referenced)", relative)
                inventory.dependencies.add(
                    Dependency(function, target, "reads/writes (conservative)", relative)
                )

def strip_yaml_comment(line: str) -> str:
    in_single = False
    in_double = False
    result: list[str] = []
    for char in line:
        if char == "'" and not in_double:
            in_single = not in_single
        elif char == '"' and not in_single:
            in_double = not in_double
        if char == "#" and not in_single and not in_double:
            break
        result.append(char)
    return "".join(result).rstrip()


def strip_quotes(value: str) -> str:
    return value.strip().strip("\"'")


def parse_inline_list(value: str) -> list[str]:
    value = value.strip()
    if value.startswith("[") and value.endswith("]"):
        return [strip_quotes(item) for item in value[1:-1].split(",") if strip_quotes(item)]
    return [strip_quotes(value)] if value else []


def parse_workflow(path: Path, repo_root: Path) -> Workflow:
    relative = path.relative_to(repo_root).as_posix()
    raw = path.read_text(encoding="utf-8", errors="replace")
    raw_lines = raw.splitlines()
    meaningful = [line for line in raw_lines if line.strip()]
    base_indent = min(
        (len(line) - len(line.lstrip(" ")) for line in meaningful),
        default=0,
    )
    name = path.stem
    triggers: list[str] = []
    jobs: list[str] = []
    needs: list[tuple[str, str]] = []
    section = ""
    current_job = ""
    collecting_needs = False

    for raw_line in raw_lines:
        line = strip_yaml_comment(raw_line[base_indent:])
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip(" "))
        stripped = line.strip()

        if indent == 0:
            current_job = ""
            collecting_needs = False
            if stripped.startswith("name:"):
                name = strip_quotes(stripped.split(":", 1)[1]) or name
                continue
            if stripped in {"on:", '"on":', "'on':"}:
                section = "on"
                continue
            if stripped.startswith("on:"):
                section = ""
                triggers.extend(parse_inline_list(stripped.split(":", 1)[1]))
                continue
            if stripped == "jobs:":
                section = "jobs"
                continue
            section = ""
            continue

        if section == "on" and indent == 2 and stripped.endswith(":"):
            triggers.append(strip_quotes(stripped[:-1]))
            continue

        if section == "jobs":
            if indent == 2 and stripped.endswith(":"):
                current_job = strip_quotes(stripped[:-1])
                collecting_needs = False
                jobs.append(current_job)
                continue
            if current_job and collecting_needs:
                if indent >= 4 and stripped.startswith("- "):
                    dependency = strip_quotes(stripped[2:])
                    if dependency:
                        needs.append((current_job, dependency))
                    continue
                collecting_needs = False
            if current_job and indent >= 4 and stripped.startswith("needs:"):
                dependencies = parse_inline_list(stripped.split(":", 1)[1])
                for dependency in dependencies:
                    needs.append((current_job, dependency))
                collecting_needs = not dependencies

    lowered = raw.lower()
    infrastructure = sorted(
        label
        for label, needles in WORKFLOW_INFRA_PATTERNS.items()
        if any(needle in lowered for needle in needles)
    )
    return Workflow(
        path=relative,
        name=name,
        triggers=sorted(set(triggers)),
        jobs=sorted(set(jobs)),
        needs=sorted(set(needs)),
        infrastructure=infrastructure,
    )

def parse_workflows(repo_root: Path, inventory: Inventory) -> None:
    workflow_dir = repo_root / ".github" / "workflows"
    if not workflow_dir.exists():
        return
    for path in sorted(
        candidate
        for candidate in workflow_dir.iterdir()
        if candidate.is_file() and candidate.suffix.lower() in {".yml", ".yaml"}
    ):
        inventory.workflows.append(parse_workflow(path, repo_root))


def collect_inventory(repo_root: Path) -> Inventory:
    inventory = Inventory()
    parse_sql(repo_root, inventory)
    parse_workflows(repo_root, inventory)
    inventory.workflows.sort(key=lambda item: item.path)
    return inventory


def mermaid_id(prefix: str, value: str) -> str:
    digest = hashlib.sha1(value.encode("utf-8")).hexdigest()[:10]
    return f"{prefix}_{digest}"


def cell(values: Iterable[str] | str) -> str:
    value = values if isinstance(values, str) else "<br>".join(values)
    return value.replace("|", "\\|") or "-"


def source_link(path: str) -> str:
    return f"[`{path}`](../../{path})"


def render_database_graph(inventory: Inventory) -> list[str]:
    dependencies = sorted(inventory.dependencies)
    impact: dict[str, int] = {}
    for dependency in dependencies:
        impact[dependency.target] = impact.get(dependency.target, 0) + 1

    selected_names = {
        name
        for name, _ in sorted(impact.items(), key=lambda item: (-item[1], item[0]))[:20]
    }
    selected_edges = [
        dependency
        for dependency in dependencies
        if dependency.target in selected_names or dependency.source in selected_names
    ][:100]
    selected_nodes = sorted(
        {name for edge in selected_edges for name in (edge.source, edge.target)}
    )[:40]
    node_set = set(selected_nodes)
    selected_edges = [
        edge
        for edge in selected_edges
        if edge.source in node_set and edge.target in node_set
    ]

    lines = ["```mermaid", "flowchart LR"]
    if not selected_edges:
        lines.append('  no_dependencies["No SQL dependencies detected"]')
    else:
        for name in selected_nodes:
            lines.append(f'  {mermaid_id("r", name)}["{name}"]')
        for dependency in selected_edges:
            lines.append(
                f'  {mermaid_id("r", dependency.source)} -->|depends on| '
                f'{mermaid_id("r", dependency.target)}'
            )
    lines.append("```")
    return lines


def render_markdown(inventory: Inventory, source_revision: str, generated_at: str) -> str:
    resources = sorted(inventory.resources.values(), key=lambda item: (item.kind, item.name))
    dependencies = sorted(inventory.dependencies)
    impact: dict[str, set[str]] = {}
    for dependency in dependencies:
        impact.setdefault(dependency.target, set()).add(dependency.source)
    for workflow in inventory.workflows:
        for job, required in workflow.needs:
            impact.setdefault(f"{workflow.path}#{required}", set()).add(
                f"{workflow.path}#{job}"
            )

    lines = [
        "# Infrastructure Map",
        "",
        "> This file is generated by `scripts/generate_infrastructure_map.py`; do not edit it manually.",
        "",
        f"- Source revision: `{source_revision}`",
        f"- Source commit time: `{generated_at}`",
        "- Inputs: `supabase/migrations/**/*.sql`, `.github/workflows/*.{yml,yaml}`",
        "",
        "## System overview",
        "",
        "```mermaid",
        "flowchart LR",
        '  migrations["Supabase migrations"] --> database["Tables / RPCs / Storage"]',
        '  workflows["GitHub Actions workflows"] --> automation["CI / deploy automation"]',
        '  database --> map["Generated infrastructure map"]',
        '  automation --> map',
        '  map --> artifact["GitHub Actions artifact"]',
        '  map --> docsbranch["generated/infrastructure-docs branch"]',
        "```",
        "",
        "The arrows identify source-to-output relationships. In the dependency graph below, changing a node on the right can affect the nodes pointing to it.",
        "",
        "## Blast-radius dependency graph",
        "",
        *render_database_graph(inventory),
        "",
        "The graph is capped at 40 nodes and 100 edges, prioritizing resources with the most dependants. Treat conservative RPC read/write edges as review leads.",
        "",
        "## Highest-impact resources",
        "",
        "| Resource | Direct dependants |",
        "|---|---:|",
    ]
    ranked_impact = sorted(impact.items(), key=lambda item: (-len(item[1]), item[0]))[:25]
    lines.extend(
        (f"| `{resource}` | {len(dependants)} |" for resource, dependants in ranked_impact)
        if ranked_impact
        else ["| No dependencies detected | 0 |"]
    )

    lines.extend(["", "## Supabase resource inventory", "", "| Resource | Type | Source |", "|---|---|---|"])
    if resources:
        for resource in resources:
            sources = sorted(source_link(path) for path in resource.source_paths)
            lines.append(f"| `{resource.name}` | {resource.kind} | {cell(sources)} |")
    else:
        lines.append("| No resources detected | - | - |")

    lines.extend(["", "## GitHub Actions inventory", "", "| Workflow | Triggers | Jobs | Infrastructure touched | Source |", "|---|---|---:|---|---|"])
    for workflow in inventory.workflows:
        lines.append(
            f"| {workflow.name} | {cell(workflow.triggers)} | {len(workflow.jobs)} | "
            f"{cell(workflow.infrastructure)} | {source_link(workflow.path)} |"
        )
    if not inventory.workflows:
        lines.append("| No workflows detected | - | 0 | - | - |")

    lines.extend(["", "## Workflow job dependencies", "", "| Workflow | Job | Needs |", "|---|---|---|"])
    job_edges = [
        (workflow, job, required)
        for workflow in inventory.workflows
        for job, required in workflow.needs
    ]
    lines.extend(
        (f"| {workflow.name} | `{job}` | `{required}` |" for workflow, job, required in job_edges)
        if job_edges
        else ["| No `needs` dependencies detected | - | - |"]
    )

    lines.extend(
        [
            "",
            "## Publication and interpretation",
            "",
            "- Every relevant pull request validates the parser and uploads this document as an Actions artifact.",
            "- Relevant pushes to `main` publish the canonical document to the `generated/infrastructure-docs` branch without pushing generated content back to `main`.",
            "- SQL extraction is intentionally read-only and conservative. Dynamic SQL, runtime API calls, policy semantics, and secrets are not inferred.",
            "- Confirm production blast radius with migration review, CI checks, and the owning engineer before applying a change.",
            "",
        ]
    )
    return "\n".join(lines)


def default_generated_at(repo_root: Path) -> str:
    try:
        return subprocess.check_output(
            ["git", "show", "-s", "--format=%cI", "HEAD"],
            cwd=repo_root,
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path, default=Path("docs/generated/INFRASTRUCTURE_MAP.md"))
    parser.add_argument("--source-revision", default="HEAD")
    parser.add_argument("--generated-at")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    inventory = collect_inventory(repo_root)
    rendered = render_markdown(
        inventory,
        args.source_revision,
        args.generated_at or default_generated_at(repo_root),
    )
    output = args.output if args.output.is_absolute() else repo_root / args.output

    if args.check:
        if not output.exists() or output.read_text(encoding="utf-8") != rendered:
            print(f"Generated infrastructure document is stale: {output}")
            return 1
    else:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(rendered, encoding="utf-8", newline="\n")

    if args.json:
        print(
            json.dumps(
                {
                    "resources": len(inventory.resources),
                    "dependencies": len(inventory.dependencies),
                    "workflows": len(inventory.workflows),
                    "output": str(output),
                },
                sort_keys=True,
            )
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
