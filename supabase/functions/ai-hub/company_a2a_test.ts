import {
  assertEquals,
  assertStringIncludes,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  assertA2AVersion,
  buildCompanyAgentCard,
  companyTaskToA2A,
  decodeA2APageToken,
  encodeA2APageToken,
  parseA2ASendMessage,
} from "./company_a2a.ts";

Deno.test("A2A card declares version 1.0 HTTP+JSON and bearer auth", () => {
  const card = buildCompanyAgentCard("https://example.com/functions/v1/ai-hub");
  assertEquals(card.supportedInterfaces[0].protocolBinding, "HTTP+JSON");
  assertEquals(card.supportedInterfaces[0].protocolVersion, "1.0");
  assertEquals(
    card.securitySchemes.bearerAuth.httpAuthSecurityScheme.scheme,
    "Bearer",
  );
  assertEquals(
    card.skills.some((skill) => skill.id === "cited-research"),
    true,
  );
});

Deno.test("A2A version negotiation rejects missing legacy and unknown versions", () => {
  assertThrows(
    () => assertA2AVersion(new Request("https://example.com/a2a/tasks")),
    Error,
    "requested 0.3",
  );
  assertThrows(
    () =>
      assertA2AVersion(
        new Request("https://example.com/a2a/tasks", {
          headers: { "A2A-Version": "2.0" },
        }),
      ),
    Error,
    "requested 2.0",
  );
  assertA2AVersion(
    new Request("https://example.com/a2a/tasks", {
      headers: { "A2A-Version": "1.0" },
    }),
  );
});

Deno.test("A2A message parser requires scoped text and supported skills", () => {
  const parsed = parseA2ASendMessage({
    message: {
      messageId: "message-1",
      contextId: "context-1",
      role: "ROLE_USER",
      parts: [{ text: "Build the pilot brief" }],
    },
    metadata: { companyId: "company-1", skillId: "launch-execution" },
  });
  assertEquals(parsed.companyId, "company-1");
  assertEquals(parsed.skillId, "launch-execution");
  assertEquals(parsed.text, "Build the pilot brief");
  const bounded = parseA2ASendMessage({
    message: {
      messageId: "message-2",
      role: "ROLE_USER",
      parts: Array.from({ length: 20 }, () => ({ text: "x".repeat(2000) })),
    },
    metadata: { companyId: "company-1" },
  });
  assertEquals(bounded.text.length, 12_000);
  assertEquals(
    (bounded.rawMessage.parts as Array<Record<string, unknown>>).length,
    1,
  );
  assertThrows(() =>
    parseA2ASendMessage({ message: { role: "ROLE_USER", parts: [] } })
  );
});

Deno.test("agent tasks map to A2A lifecycle and citation artifacts", () => {
  const task = {
    id: "10000000-0000-4000-8000-000000000001",
    title: "Pilot brief",
    status: "completed",
    updated_at: "2026-08-15T00:00:00.000Z",
    metadata: {
      company_id: "company-1",
      a2a_context_id: "context-1",
      a2a_skill_id: "cited-research",
      a2a_message: {
        messageId: "message-1",
        role: "ROLE_USER",
        parts: [{ text: "Research" }],
      },
    },
    result: {
      text: "Evidence [1]",
      citations: [{ sourceUrl: "https://example.com" }],
    },
  };
  const mapped = companyTaskToA2A(task);
  assertEquals(
    (mapped.status as Record<string, unknown>).state,
    "TASK_STATE_COMPLETED",
  );
  assertEquals(Array.isArray(mapped.artifacts), true);
  assertStringIncludes(JSON.stringify(mapped), "https://example.com");
  assertEquals(
    companyTaskToA2A({ ...task, status: "cancelled" }).artifacts,
    undefined,
  );
  const token = encodeA2APageToken(task);
  assertEquals(decodeA2APageToken(token), {
    updatedAt: "2026-08-15T00:00:00.000Z",
    id: "10000000-0000-4000-8000-000000000001",
  });
  const unsafeToken = btoa(JSON.stringify({
    updatedAt: "2026-08-15T00:00:00.000Z,id.gt.0",
    id: "not-a-uuid",
  }));
  assertEquals(decodeA2APageToken(unsafeToken), null);
});
