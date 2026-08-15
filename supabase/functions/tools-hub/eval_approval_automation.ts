export type EvalAutomationTask = {
  title: string;
  description: string;
  dueDate: string | null;
  assignee: string | null;
  priority: "low" | "medium" | "high";
};

export type EvalAutomationCalendarEvent = {
  title: string;
  description: string;
  startAt: string;
  endAt: string;
  allDay: boolean;
  color: string;
  reminderMinutes: number | null;
  calendarId: string;
};

export type EvalApprovalAutomationPlan = {
  tasks: EvalAutomationTask[];
  calendarEvents: EvalAutomationCalendarEvent[];
};

export type EvalApprovalAutomationHandlers = {
  createTask: (
    task: EvalAutomationTask,
    itemKey: string,
  ) => Promise<boolean>;
  createCalendarEvent: (
    event: EvalAutomationCalendarEvent,
    itemKey: string,
  ) => Promise<boolean>;
};

function asRecord(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function text(value: unknown, fallback = ""): string {
  const normalized = String(value ?? "").trim();
  return normalized || fallback;
}

function isoDate(value: unknown): string | null {
  const normalized = text(value);
  if (!normalized || Number.isNaN(Date.parse(normalized))) return null;
  return new Date(normalized).toISOString();
}

function priority(value: unknown): "low" | "medium" | "high" {
  const normalized = text(value).toLowerCase();
  return normalized === "low" || normalized === "high" ? normalized : "medium";
}

function reminderMinutes(value: unknown): number | null {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) return null;
  return Math.min(Math.trunc(parsed), 10080);
}

export function selectEvalApprovalAutomationPayload(
  payload: unknown,
  selectedOptionId: string,
): unknown {
  const root = asRecord(payload);
  if (!Array.isArray(root.options) || root.options.length === 0) return root;

  const normalizedOptionId = text(selectedOptionId);
  if (!normalizedOptionId) {
    throw new Error("selected_option_id is required for option automation");
  }
  const selected = root.options
    .map(asRecord)
    .find((option) => text(option.id ?? option.value) === normalizedOptionId);
  if (!selected) {
    throw new Error(`selected option not found: ${normalizedOptionId}`);
  }
  const selectedPayload = asRecord(selected.payload);
  return Object.keys(selectedPayload).length > 0 ? selectedPayload : selected;
}

export function normalizeEvalApprovalAutomation(
  payload: unknown,
): EvalApprovalAutomationPlan {
  const root = asRecord(payload);
  const automation = asRecord(root.automation);
  const rawTasks = Array.isArray(automation.tasks)
    ? automation.tasks
    : Array.isArray(root.tasks)
    ? root.tasks
    : [];
  const rawEvents = Array.isArray(automation.calendar_events)
    ? automation.calendar_events
    : Array.isArray(root.calendar_events)
    ? root.calendar_events
    : [];

  const tasks = rawTasks.slice(0, 20).flatMap((raw) => {
    const item = asRecord(raw);
    const title = text(item.title);
    if (!title) return [];
    return [{
      title: title.slice(0, 240),
      description: text(item.description).slice(0, 4000),
      dueDate: isoDate(item.due_date),
      assignee: text(item.assignee) || null,
      priority: priority(item.priority),
    }];
  });

  const calendarEvents = rawEvents.slice(0, 20).flatMap((raw) => {
    const item = asRecord(raw);
    const title = text(item.title);
    const startAt = isoDate(item.start_at);
    if (!title || !startAt) return [];
    const requestedEnd = isoDate(item.end_at);
    const startMs = Date.parse(startAt);
    const endAt = requestedEnd && Date.parse(requestedEnd) >= startMs
      ? requestedEnd
      : new Date(startMs + 60 * 60 * 1000).toISOString();
    return [{
      title: title.slice(0, 240),
      description: text(item.description).slice(0, 4000),
      startAt,
      endAt,
      allDay: item.all_day === true,
      color: text(item.color, "#4285f4").slice(0, 20),
      reminderMinutes: reminderMinutes(item.reminder_min),
      calendarId: text(item.calendar_id, "default").slice(0, 120),
    }];
  });

  return { tasks, calendarEvents };
}

export async function executeEvalApprovalAutomation(
  payload: unknown,
  handlers: EvalApprovalAutomationHandlers,
  selectedOptionId = "",
) {
  const selectedPayload = selectEvalApprovalAutomationPayload(
    payload,
    selectedOptionId,
  );
  const plan = normalizeEvalApprovalAutomation(selectedPayload);
  let tasksCreated = 0;
  let tasksExisting = 0;
  let calendarEventsCreated = 0;
  let calendarEventsExisting = 0;

  for (const [index, task] of plan.tasks.entries()) {
    if (await handlers.createTask(task, `task-${index + 1}`)) {
      tasksCreated += 1;
    } else {
      tasksExisting += 1;
    }
  }
  for (const [index, event] of plan.calendarEvents.entries()) {
    if (
      await handlers.createCalendarEvent(event, `calendar-${index + 1}`)
    ) {
      calendarEventsCreated += 1;
    } else {
      calendarEventsExisting += 1;
    }
  }

  return {
    success: true,
    status: "completed",
    tasks_created: tasksCreated,
    tasks_existing: tasksExisting,
    calendar_events_created: calendarEventsCreated,
    calendar_events_existing: calendarEventsExisting,
  };
}
