import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  dedupeWbsTasksById,
  normalizeWbsListPagination,
  paginateWbsTasks,
} from "./wbs_list_tasks.ts";

Deno.test("normalizeWbsListPagination clamps limit and offset", () => {
  assertEquals(normalizeWbsListPagination({}), { limit: 50, offset: 0 });
  assertEquals(normalizeWbsListPagination({ limit: 500, offset: -10 }), {
    limit: 200,
    offset: 0,
  });
  assertEquals(normalizeWbsListPagination({ limit: "25", offset: "75" }), {
    limit: 25,
    offset: 75,
  });
});

Deno.test("dedupeWbsTasksById preserves first row per id", () => {
  const result = dedupeWbsTasksById([
    { id: "task-a", title: "first" },
    { id: "task-b", title: "middle" },
    { id: "task-a", title: "duplicate" },
  ]);

  assertEquals(result.duplicateRowsRemoved, 1);
  assertEquals(result.tasks, [
    { id: "task-a", title: "first" },
    { id: "task-b", title: "middle" },
  ]);
});

Deno.test("paginateWbsTasks applies offset after sorting/filtering", () => {
  const rows = Array.from({ length: 6 }, (_, index) => ({
    id: `task-${index + 1}`,
  }));

  assertEquals(paginateWbsTasks(rows, { limit: 2, offset: 0 }), [
    { id: "task-1" },
    { id: "task-2" },
  ]);
  assertEquals(paginateWbsTasks(rows, { limit: 2, offset: 2 }), [
    { id: "task-3" },
    { id: "task-4" },
  ]);
});
