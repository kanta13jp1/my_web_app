import {
  assertEquals,
  assertNotEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildInvestigationIssuePayload,
  diffPromptSnapshots,
  normalizePromptSnapshot,
  PROMPT_CHANGE_LABELS,
} from "./prompt_history_intake.ts";

Deno.test(
  "normalizePromptSnapshot produces deterministic digest and default status",
  () => {
    const a = normalizePromptSnapshot({
      provider: " Anthropic ",
      modelName: "claude-sonnet",
      versionTag: "2026-11-01",
      capturedAtIso: "2026-11-26T12:00:00Z",
      sections: { b: "two\r\n", a: " one " },
    });
    const b = normalizePromptSnapshot({
      provider: "anthropic",
      modelName: "claude-sonnet",
      versionTag: "2026-11-01",
      capturedAtIso: "2026-11-26T12:00:00.000Z",
      sections: { a: "one", b: "two" },
    });

    assertEquals(a.contentDigest, b.contentDigest);
    assertEquals(a.verificationStatus, "未確認");
    assertEquals(
      PROMPT_CHANGE_LABELS.breaking,
      "Breaking Prompt Contract Change",
    );
  },
);

Deno.test(
  "diffPromptSnapshots detects breaking vs additive and builds dry-run",
  () => {
    const prev = normalizePromptSnapshot({
      provider: "anthropic",
      modelName: "claude-sonnet",
      versionTag: "v1",
      capturedAtIso: "2026-11-01T00:00:00Z",
      sections: { identity: "Be concise.", safety: "Refuse harm." },
    });
    const next = normalizePromptSnapshot({
      provider: "anthropic",
      modelName: "claude-sonnet",
      versionTag: "v2",
      capturedAtIso: "2026-11-26T00:00:00Z",
      sections: { identity: "Be concise.", tools: "Use JSON schema." },
    });

    const diff = diffPromptSnapshots(prev, next);
    assertEquals(diff.severity, "breaking");
    assertEquals(diff.addedSections, ["tools"]);
    assertEquals(diff.removedSections, ["safety"]);

    const payload = buildInvestigationIssuePayload(diff, next);
    assertNotEquals(payload, null);
    assertEquals(payload?.dryRun, true);
  },
);

Deno.test(
  "normalizePromptSnapshot rejects invalid ISO timestamp",
  () => {
    assertThrows(
      () =>
        normalizePromptSnapshot({
          provider: "anthropic",
          modelName: "claude",
          versionTag: "v1",
          capturedAtIso: "not-a-date",
          sections: {},
        }),
      TypeError,
      "capturedAtIso must be a valid ISO timestamp",
    );
  },
);
