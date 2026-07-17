import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  executeEvalApprovalAutomation,
  normalizeEvalApprovalAutomation,
  selectEvalApprovalAutomationPayload,
} from "./eval_approval_automation.ts";

Deno.test("normalizes decision automation tasks and calendar events", () => {
  const plan = normalizeEvalApprovalAutomation({
    automation: {
      tasks: [{
        title: " Ship the approved plan ",
        priority: "high",
        due_date: "2026-07-20T09:00:00+09:00",
      }, { title: " " }],
      calendar_events: [{
        title: " CEO checkpoint ",
        start_at: "2026-07-21T10:00:00+09:00",
        end_at: "invalid",
        reminder_min: 30,
      }],
    },
  });

  assertEquals(plan.tasks.length, 1);
  assertEquals(plan.tasks[0].title, "Ship the approved plan");
  assertEquals(plan.tasks[0].priority, "high");
  assertEquals(plan.calendarEvents.length, 1);
  assertEquals(plan.calendarEvents[0].calendarId, "default");
  assertEquals(
    Date.parse(plan.calendarEvents[0].endAt) -
      Date.parse(plan.calendarEvents[0].startAt),
    60 * 60 * 1000,
  );
});

Deno.test("executes each approved automation item once through handlers", async () => {
  const calls: string[] = [];
  const result = await executeEvalApprovalAutomation({
    tasks: [{ title: "Task A" }, { title: "Task B" }],
    calendar_events: [{
      title: "Review",
      start_at: "2026-07-21T10:00:00Z",
    }],
  }, {
    createTask: (_task, key) => {
      calls.push(key);
      return Promise.resolve(key === "task-1");
    },
    createCalendarEvent: (_event, key) => {
      calls.push(key);
      return Promise.resolve(true);
    },
  });

  assertEquals(calls, ["task-1", "task-2", "calendar-1"]);
  assertEquals(result, {
    success: true,
    status: "completed",
    tasks_created: 1,
    tasks_existing: 1,
    calendar_events_created: 1,
    calendar_events_existing: 0,
  });
});

Deno.test("executes only the automation for the selected option", async () => {
  const calls: string[] = [];
  const payload = {
    options: [
      { id: "now", tasks: [{ title: "Ship now" }] },
      {
        id: "later",
        payload: { tasks: [{ title: "Schedule the staffed release" }] },
      },
    ],
  };

  const selected = selectEvalApprovalAutomationPayload(payload, "later");
  assertEquals(
    normalizeEvalApprovalAutomation(selected).tasks[0].title,
    "Schedule the staffed release",
  );

  const result = await executeEvalApprovalAutomation(payload, {
    createTask: (task, key) => {
      calls.push(`${key}:${task.title}`);
      return Promise.resolve(true);
    },
    createCalendarEvent: () => Promise.resolve(true),
  }, "later");

  assertEquals(calls, ["task-1:Schedule the staffed release"]);
  assertEquals(result.tasks_created, 1);
});

Deno.test("rejects an unknown selected option before executing", async () => {
  const payload = { options: [{ id: "known", tasks: [{ title: "Task" }] }] };
  let message = "";
  try {
    await executeEvalApprovalAutomation(payload, {
      createTask: () => Promise.resolve(true),
      createCalendarEvent: () => Promise.resolve(true),
    }, "unknown");
  } catch (error) {
    message = error instanceof Error ? error.message : String(error);
  }
  assertEquals(message, "selected option not found: unknown");
});

Deno.test("empty automation is a successful no-op", async () => {
  const result = await executeEvalApprovalAutomation({}, {
    createTask: () => Promise.resolve(true),
    createCalendarEvent: () => Promise.resolve(true),
  });

  assertEquals(result.tasks_created, 0);
  assertEquals(result.calendar_events_created, 0);
});
