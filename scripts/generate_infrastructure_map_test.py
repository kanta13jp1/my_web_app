#!/usr/bin/env python3
"""Tests for generate_infrastructure_map.py."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from generate_infrastructure_map import collect_inventory, render_markdown


class InfrastructureMapTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        migration_dir = self.root / "supabase" / "migrations"
        workflow_dir = self.root / ".github" / "workflows"
        migration_dir.mkdir(parents=True)
        workflow_dir.mkdir(parents=True)

        (migration_dir / "20260830000000_fixture.sql").write_text(
            """
            create table public.accounts (id uuid primary key);
            create table public.tasks (
              id uuid primary key,
              account_id uuid references public.accounts(id)
            );
            create or replace function public.task_count()
            returns bigint language sql as $$
              select count(*) from public.tasks;
            $$;
            insert into storage.buckets (id, name)
            values ('task-files', 'task-files');
            """,
            encoding="utf-8",
        )
        (workflow_dir / "fixture.yml").write_text(
            """
            name: Fixture Deploy
            on:
              push:
              workflow_dispatch:
            jobs:
              lint:
                runs-on: ubuntu-latest
              deploy:
                needs:
                  - lint
                runs-on: ubuntu-latest
                steps:
                  - run: supabase db push
                  - run: firebase deploy
            """,
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_extracts_resources_dependencies_and_workflow_shape(self) -> None:
        inventory = collect_inventory(self.root)
        self.assertIn("public.accounts", inventory.resources)
        self.assertIn("public.tasks", inventory.resources)
        self.assertIn("public.task_count", inventory.resources)
        self.assertIn("storage.bucket:task-files", inventory.resources)
        self.assertTrue(
            any(
                edge.source == "public.tasks"
                and edge.target == "public.accounts"
                and edge.kind == "foreign key"
                for edge in inventory.dependencies
            )
        )

        workflow = inventory.workflows[0]
        self.assertEqual(workflow.name, "Fixture Deploy")
        self.assertEqual(workflow.triggers, ["push", "workflow_dispatch"])
        self.assertEqual(workflow.needs, [("deploy", "lint")])
        self.assertEqual(
            workflow.infrastructure,
            ["Firebase Hosting", "Supabase migrations", "Supabase platform"],
        )

    def test_render_is_deterministic_and_contains_blast_radius_guidance(self) -> None:
        inventory = collect_inventory(self.root)
        first = render_markdown(inventory, "abc123", "2026-08-30T00:00:00Z")
        second = render_markdown(inventory, "abc123", "2026-08-30T00:00:00Z")

        self.assertEqual(first, second)
        self.assertIn("# Infrastructure Map", first)
        self.assertIn("## Blast-radius dependency graph", first)
        self.assertIn("```mermaid", first)
        self.assertIn("public.tasks", first)
        self.assertIn("public.accounts", first)
        self.assertIn("-->|depends on|", first)
        self.assertIn("generated/infrastructure-docs", first)
        self.assertIn("Source revision: `abc123`", first)


if __name__ == "__main__":
    unittest.main()
