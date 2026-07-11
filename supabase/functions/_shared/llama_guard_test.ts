import {
  assertEquals,
  assertStrictEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { parseLlamaGuardOutput } from "./llama_guard.ts";

Deno.test("parseLlamaGuardOutput handles safe verdict", () => {
  assertEquals(parseLlamaGuardOutput("safe"), { safe: true, categories: [] });
  assertEquals(parseLlamaGuardOutput("  Safe \n"), {
    safe: true,
    categories: [],
  });
});

Deno.test("parseLlamaGuardOutput handles unsafe verdict with categories", () => {
  assertEquals(parseLlamaGuardOutput("unsafe\nS1"), {
    safe: false,
    categories: ["S1"],
  });
  assertEquals(parseLlamaGuardOutput("unsafe\nS1,S9, s13"), {
    safe: false,
    categories: ["S1", "S9", "S13"],
  });
});

Deno.test("parseLlamaGuardOutput ignores malformed categories", () => {
  assertEquals(parseLlamaGuardOutput("unsafe\nS1,banana,S999"), {
    safe: false,
    categories: ["S1"],
  });
});

Deno.test("parseLlamaGuardOutput fails open on unexpected output", () => {
  assertStrictEquals(parseLlamaGuardOutput("I cannot classify this").safe, true);
  assertStrictEquals(parseLlamaGuardOutput("").safe, true);
});
