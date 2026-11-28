import {
  assertEquals,
  assertRejects,
  assertStringIncludes,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  abstractAndSanitizePattern,
  detectResidualSensitiveMaterial,
  filterPatternsForScope,
  isScopeAuthorized,
  sanitizeLearningPattern,
} from "./team_memory_isolation.ts";

Deno.test("sanitizeLearningPattern strips tokens, code blocks, paths, and emails", () => {
  const sampleGhp = ["ghp", "_SampleLeak987654321"].join("");
  const sampleEmail = ["ops", "user@example.com"].join("-");
  const codeBlock = "```dart\nfinal token = '" + sampleGhp + "';\n```";

  const sanitized = sanitizeLearningPattern({
    scopeType: "org",
    scopeId: "org:alpha",
    patternType: "anti_pattern",
    rawSummary: `Avoid logging ${sampleGhp} by ${sampleEmail} at C:\\Users\\dev\\repo\\secret.env ${codeBlock}`,
    rawRule: `Never persist credentials (${sampleGhp}) or raw ${codeBlock} in shared memory.`,
  });

  assertEquals(sanitized.isSanitized, true);
  assertEquals(sanitized.redactionCount > 0, true);
  assertEquals(sanitized.sanitizedSummary.includes("SampleLeak987654321"), false);
  assertEquals(sanitized.sanitizedSummary.includes("example.com"), false);
  assertEquals(sanitized.sanitizedSummary.includes("```"), false);
  assertEquals(sanitized.abstractRule.includes("SampleLeak987654321"), false);
  assertEquals(detectResidualSensitiveMaterial(sanitized.sanitizedSummary), null);
  assertEquals(detectResidualSensitiveMaterial(sanitized.abstractRule), null);
});

Deno.test("abstractAndSanitizePattern enforces post-LLM fail-closed sanitization", async () => {
  const sampleSk = ["sk", "-LiveModelLeak123456789"].join("");
  const result = await abstractAndSanitizePattern(
    {
      scopeType: "project",
      scopeId: "proj:core",
      patternType: "success_rule",
      rawSummary: "Always copy constant seed fixtures before adding entries in tests.",
    },
    (text) => `${text} Echoed ${sampleSk}`,
  );
  assertEquals(result.abstractRule.includes("LiveModelLeak123456789"), false);
  assertStringIncludes(result.abstractRule, "Always copy constant seed fixtures");

  await assertRejects(
    async () => {
      await abstractAndSanitizePattern(
        {
          scopeType: "agent",
          scopeId: "agent:batch",
          patternType: "guardrail",
          rawSummary: "Short",
        },
        () => "x",
      );
    },
    Error,
  );
});

Deno.test("filterPatternsForScope blocks cross-scope data leakage", () => {
  const orgAlphaPattern = sanitizeLearningPattern({
    scopeType: "org",
    scopeId: "org:alpha",
    patternType: "guardrail",
    rawSummary: "Require explicit scope checks before reading shared pattern rows.",
  });
  const orgBetaPattern = sanitizeLearningPattern({
    scopeType: "org",
    scopeId: "org:beta",
    patternType: "anti_pattern",
    rawSummary: "Never mutate unmodifiable list literals in widget test repositories.",
  });

  const alphaMemberScopes = [{ scopeType: "org" as const, scopeId: "org:alpha" }];
  assertEquals(isScopeAuthorized(alphaMemberScopes, { scopeType: "org", scopeId: "org:beta" }), false);
  assertEquals(
    filterPatternsForScope([orgAlphaPattern, orgBetaPattern], alphaMemberScopes, {
      scopeType: "org",
      scopeId: "org:beta",
    }).length,
    0,
  );
  assertEquals(
    filterPatternsForScope([orgAlphaPattern, orgBetaPattern], alphaMemberScopes, {
      scopeType: "org",
      scopeId: "org:alpha",
    }).length,
    1,
  );

  assertThrows(() =>
    sanitizeLearningPattern({
      scopeType: "project",
      scopeId: "../escape",
      patternType: "guardrail",
      rawSummary: "Reject invalid path traversal scope identifiers.",
    })
  );
});
