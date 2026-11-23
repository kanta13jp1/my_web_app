import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  detectChromeExecutable,
  renderCardHtml,
  verifyOutputs,
} from "../../scripts/generate_ogp_cards.mjs";

function makeSyntheticPng(width, height, totalBytes = 120_000) {
  const buf = Buffer.alloc(totalBytes, 0x20);
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(buf, 0);
  buf.writeUInt32BE(13, 8);
  buf.write("IHDR", 12, "ascii");
  buf.writeUInt32BE(width, 16);
  buf.writeUInt32BE(height, 20);
  return buf;
}

function makeCardSpec(overrides = {}) {
  return {
    id: "ogp-lp",
    output: "ogp-lp-20261123.png",
    width: 1200,
    height: 630,
    artPosition: "86% 50%",
    accentPrimary: "#38bdf8",
    accentSecondary: "#f59e0b",
    headlineAccent: "#f5d08a",
    badge: "AI | <script>alert(1)</script>",
    headline: ["line 1", "line 2 & more"],
    subcopy: ['sub "quote" copy', "line 2"],
    trust: ["item 1", "item 2"],
    ...overrides,
  };
}

test("renderCardHtml escapes HTML, embeds repo font when given, and honors dimensions", () => {
  const canvas = {
    background: "#07111e",
    textPrimary: "#f8f5ee",
    textSecondary: "#dbe4f0",
    trustColor: "#cbd5e1",
  };
  const ogpHtml = renderCardHtml(
    makeCardSpec(),
    canvas,
    "data:image/webp;base64,AA==",
    "http://127.0.0.1:4321/fonts/NotoSansJP-Regular.ttf",
  );
  assert.ok(ogpHtml.includes("width: 1200px;"));
  assert.ok(ogpHtml.includes("height: 630px;"));
  assert.ok(ogpHtml.includes("@font-face"));
  assert.ok(ogpHtml.includes("RepoNotoSansJP"));
  assert.ok(ogpHtml.includes("&lt;script&gt;alert(1)&lt;/script&gt;"));
  assert.ok(ogpHtml.includes("sub &quot;quote&quot; copy"));
  assert.equal(ogpHtml.includes("<script>alert(1)</script>"), false);

  const wideHtml = renderCardHtml(
    makeCardSpec({ width: 1600, height: 900 }),
    canvas,
    "data:image/webp;base64,AA==",
    null,
  );
  assert.ok(wideHtml.includes("width: 1600px;"));
  assert.ok(wideHtml.includes("height: 900px;"));
  assert.equal(wideHtml.includes("@font-face"), false);
});

test("detectChromeExecutable respects explicit path and returns string or null when auto-detecting", () => {
  assert.equal(detectChromeExecutable("/custom/bin/chrome"), "/custom/bin/chrome");
  const detected = detectChromeExecutable(null);
  assert.ok(detected === null || typeof detected === "string");
});

test("verifyOutputs validates valid synthetic PNGs and rejects malformed or escaping outputs", () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "ogp-cards-test-"));
  try {
    const manifest = {
      cards: [
        { output: "card-ogp.png", width: 1200, height: 630 },
        { output: "card-wide.png", width: 1600, height: 900 },
      ],
    };
    fs.writeFileSync(path.join(tmpDir, "card-ogp.png"), makeSyntheticPng(1200, 630));
    fs.writeFileSync(path.join(tmpDir, "card-wide.png"), makeSyntheticPng(1600, 900));
    verifyOutputs(manifest, tmpDir);

    assert.throws(
      () => verifyOutputs({ cards: [{ output: "missing.png", width: 1200, height: 630 }] }, tmpDir),
      /Missing rendered card/,
    );

    fs.writeFileSync(path.join(tmpDir, "wrong-dim.png"), makeSyntheticPng(800, 600));
    assert.throws(
      () => verifyOutputs({ cards: [{ output: "wrong-dim.png", width: 1200, height: 630 }] }, tmpDir),
      /Dimension mismatch/,
    );

    fs.writeFileSync(path.join(tmpDir, "tiny.png"), makeSyntheticPng(1200, 630, 512));
    assert.throws(
      () => verifyOutputs({ cards: [{ output: "tiny.png", width: 1200, height: 630 }] }, tmpDir),
      /Card smaller than/,
    );

    fs.writeFileSync(path.join(tmpDir, "bad-header.png"), Buffer.alloc(120_000, 0x41));
    assert.throws(
      () => verifyOutputs({ cards: [{ output: "bad-header.png", width: 1200, height: 630 }] }, tmpDir),
      /Invalid PNG header/,
    );

    assert.throws(
      () => verifyOutputs({ cards: [{ output: "../escape.png", width: 1200, height: 630 }] }, tmpDir),
      /Path escapes allowed root/,
    );
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});
