import {
  countVoiceTextChars,
  createVoiceProxyToken,
  estimateVoiceAiCostUsd,
  estimateVoiceSttSeconds,
  observeCartesiaChunkTiming,
  reserveVoiceTtsUsage,
  verifyVoiceProxyToken,
  type VoiceAiDb,
  type VoiceAiDbQuery,
  VoiceAiError,
} from "./voice_ai.ts";

Deno.test("countVoiceTextChars counts unicode code points", () => {
  assertEquals(countVoiceTextChars("abc"), 3);
  assertEquals(countVoiceTextChars("音声AI"), 4);
});

Deno.test("estimateVoiceAiCostUsd uses env-configured TTS rate", () => {
  const previous = Deno.env.get("VOICE_AI_TTS_USD_PER_1M_CHARS");
  Deno.env.set("VOICE_AI_TTS_USD_PER_1M_CHARS", "10");
  try {
    assertEquals(estimateVoiceAiCostUsd("elevenlabs", "tts_chars", 1000), 0.01);
  } finally {
    if (previous == null) {
      Deno.env.delete("VOICE_AI_TTS_USD_PER_1M_CHARS");
    } else {
      Deno.env.set("VOICE_AI_TTS_USD_PER_1M_CHARS", previous);
    }
  }
});

Deno.test("reserveVoiceTtsUsage returns blocked when char limit is exceeded", async () => {
  const previousZdr = Deno.env.get("CARTESIA_ZDR_ENABLED");
  Deno.env.set("CARTESIA_ZDR_ENABLED", "true");
  const db = new FakeDb();
  try {
    const result = await reserveVoiceTtsUsage(db, {
      userId: "00000000-0000-0000-0000-000000000001",
      body: { daily_char_limit: 4 },
      provider: "cartesia",
      feature: "test",
      text: "12345",
    });

    assertEquals(result.policy.trainingConsent, false);
    assertEquals(result.policy.zeroDataRetentionRequested, true);
    assertEquals(result.usage.blocked, true);
    assertEquals(db.rpcCalls[0].args.p_metric_type, "tts_chars");
    assertEquals(db.rpcCalls[0].args.p_zero_data_retention_requested, true);
  } finally {
    restoreEnv("CARTESIA_ZDR_ENABLED", previousZdr);
  }
});

Deno.test("STT duration cannot be understated below the audio-size estimate", () => {
  assertEquals(estimateVoiceSttSeconds(160_001, 1), 11);
  assertEquals(estimateVoiceSttSeconds(16_000, "20"), 20);
  assertEquals(estimateVoiceSttSeconds(16_000, Number.POSITIVE_INFINITY), 1);
});

Deno.test("client input cannot disable or raise the server TTS limit", async () => {
  const previousDaily = Deno.env.get("VOICE_AI_TTS_DAILY_CHAR_LIMIT");
  const previousMonthly = Deno.env.get("VOICE_AI_TTS_MONTHLY_CHAR_LIMIT");
  const previousZdr = Deno.env.get("CARTESIA_ZDR_ENABLED");
  Deno.env.set("VOICE_AI_TTS_DAILY_CHAR_LIMIT", "20000");
  Deno.env.set("VOICE_AI_TTS_MONTHLY_CHAR_LIMIT", "300000");
  Deno.env.set("CARTESIA_ZDR_ENABLED", "true");
  const db = new FakeDb();
  try {
    await reserveVoiceTtsUsage(db, {
      userId: "00000000-0000-0000-0000-000000000001",
      body: { daily_char_limit: false, monthly_char_limit: 999_999_999 },
      provider: "cartesia",
      feature: "test",
      text: "12345",
    });

    assertEquals(db.rpcCalls[0].args.p_daily_limit, 20_000);
    assertEquals(db.rpcCalls[0].args.p_monthly_limit, 300_000);

    await reserveVoiceTtsUsage(db, {
      userId: "00000000-0000-0000-0000-000000000001",
      body: { daily_char_limit: 0, monthly_char_limit: -1 },
      provider: "cartesia",
      feature: "test",
      text: "12345",
    });

    assertEquals(db.rpcCalls[1].args.p_daily_limit, 20_000);
    assertEquals(db.rpcCalls[1].args.p_monthly_limit, 300_000);
  } finally {
    restoreEnv("VOICE_AI_TTS_DAILY_CHAR_LIMIT", previousDaily);
    restoreEnv("VOICE_AI_TTS_MONTHLY_CHAR_LIMIT", previousMonthly);
    restoreEnv("CARTESIA_ZDR_ENABLED", previousZdr);
  }
});

Deno.test("provider calls fail closed without consent or confirmed ZDR", async () => {
  const previousZdr = Deno.env.get("CARTESIA_ZDR_ENABLED");
  Deno.env.set("CARTESIA_ZDR_ENABLED", "false");
  const db = new FakeDb();
  try {
    let caught: unknown;
    try {
      await reserveVoiceTtsUsage(db, {
        userId: "00000000-0000-0000-0000-000000000001",
        body: {},
        provider: "cartesia",
        feature: "test",
        text: "privacy",
      });
    } catch (error) {
      caught = error;
    }

    assertEquals(caught instanceof VoiceAiError, true);
    assertEquals((caught as VoiceAiError).status, 403);
    assertEquals(db.rpcCalls.length, 0);
  } finally {
    restoreEnv("CARTESIA_ZDR_ENABLED", previousZdr);
  }
});

Deno.test("voice proxy token is scoped, expiring, and tamper evident", async () => {
  const userId = "00000000-0000-0000-0000-000000000001";
  const token = await createVoiceProxyToken(userId, "test-secret", 60);
  assertEquals(await verifyVoiceProxyToken(token, "test-secret"), userId);
  assertEquals(await verifyVoiceProxyToken(`${token}x`, "test-secret"), null);

  const expired = await createVoiceProxyToken(userId, "test-secret", -1);
  assertEquals(await verifyVoiceProxyToken(expired, "test-secret"), null);
});

Deno.test("Cartesia chunk timing records one TTFA then inter-chunk latency", () => {
  const first = observeCartesiaChunkTiming({
    generationStartedAt: 1000,
    lastChunkAt: 0,
    firstChunkSeen: false,
    observedAt: 1080,
  });
  assertEquals(first.ttfaMs, 80);
  assertEquals(first.chunkLatencyMs, null);

  const second = observeCartesiaChunkTiming({
    generationStartedAt: 1000,
    lastChunkAt: first.lastChunkAt,
    firstChunkSeen: first.firstChunkSeen,
    observedAt: 1125,
  });
  assertEquals(second.ttfaMs, null);
  assertEquals(second.chunkLatencyMs, 45);
});

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Assertion failed:\nactual:   ${JSON.stringify(actual)}\nexpected: ${
        JSON.stringify(expected)
      }`,
    );
  }
}

function restoreEnv(name: string, value: string | undefined) {
  if (value == null) {
    Deno.env.delete(name);
  } else {
    Deno.env.set(name, value);
  }
}

class FakeDb implements VoiceAiDb {
  rpcCalls: Array<{ name: string; args: Record<string, unknown> }> = [];

  from(): VoiceAiDbQuery {
    return new FakeQuery();
  }

  rpc(name: string, args: Record<string, unknown> = {}) {
    this.rpcCalls.push({ name, args });
    const quantity = Number(args.p_quantity ?? 0);
    const dailyLimit = Number(args.p_daily_limit ?? 0);
    return Promise.resolve({
      data: {
        event_id: "evt-1",
        blocked: dailyLimit > 0 && quantity > dailyLimit,
        daily_total: quantity,
        monthly_total: quantity,
        daily_limit: args.p_daily_limit,
        monthly_limit: args.p_monthly_limit,
        estimated_cost_usd: args.p_estimated_cost_usd,
      },
      error: null,
    });
  }
}

class FakeQuery implements VoiceAiDbQuery {
  select(): VoiceAiDbQuery {
    return this;
  }

  eq(): VoiceAiDbQuery {
    return this;
  }

  gte(): VoiceAiDbQuery {
    return this;
  }

  order(): VoiceAiDbQuery {
    return this;
  }

  limit() {
    return Promise.resolve({ data: [], error: null });
  }

  maybeSingle() {
    return Promise.resolve({
      data: {
        training_consent: false,
        consent_updated_at: null,
      },
      error: null,
    });
  }
}
