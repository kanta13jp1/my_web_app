import {
  countVoiceTextChars,
  estimateVoiceAiCostUsd,
  reserveVoiceTtsUsage,
  type VoiceAiDb,
  type VoiceAiDbQuery,
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
  const db = new FakeDb();
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
        voice_ai_training_consent: false,
        voice_ai_consent_updated_at: null,
      },
      error: null,
    });
  }
}
