#!/usr/bin/env node
/**
 * Generate or verify OGP (1200x630) and X 16:9 (1600x900) social cards
 * from `scripts/ogp_cards.json` using existing 3D brand artwork and HTML/CSS.
 *
 * Modes:
 *   node scripts/generate_ogp_cards.mjs --out-dir build/web
 *   node scripts/generate_ogp_cards.mjs --out-dir web --verify-only
 *   node scripts/generate_ogp_cards.mjs --html-dir <dir>
 */

import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const DEFAULT_REPO_ROOT = path.resolve(__dirname, "..");
const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const MIN_CARD_BYTES = 100_000;
const MAX_CARD_BYTES = 1_500_000;

const SYSTEM_CHROME_CANDIDATES = [
  process.env.CHROME_EXECUTABLE,
  "/usr/bin/google-chrome",
  "/usr/bin/google-chrome-stable",
  "/usr/bin/chromium",
  "/usr/bin/chromium-browser",
  "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
  "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe",
].filter(Boolean);

/**
 * Parse CLI flags without external dependencies.
 * @param {string[]} argv
 */
export function parseArgs(argv) {
  const opts = {
    repoRoot: DEFAULT_REPO_ROOT,
    assetsRoot: DEFAULT_REPO_ROOT,
    outDir: null,
    configPath: null,
    htmlDir: null,
    chromeBin: null,
    verifyOnly: false,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--verify-only") {
      opts.verifyOnly = true;
    } else if (arg === "--repo-root" && argv[i + 1]) {
      opts.repoRoot = path.resolve(argv[++i]);
    } else if (arg === "--assets-root" && argv[i + 1]) {
      opts.assetsRoot = path.resolve(argv[++i]);
    } else if (arg === "--out-dir" && argv[i + 1]) {
      opts.outDir = path.resolve(argv[++i]);
    } else if (arg === "--config" && argv[i + 1]) {
      opts.configPath = path.resolve(argv[++i]);
    } else if (arg === "--html-dir" && argv[i + 1]) {
      opts.htmlDir = path.resolve(argv[++i]);
    } else if (arg === "--chrome-bin" && argv[i + 1]) {
      opts.chromeBin = path.resolve(argv[++i]);
    } else {
      throw new Error(`Unknown or incomplete argument: ${arg}`);
    }
  }
  opts.configPath ??= path.join(opts.repoRoot, "scripts", "ogp_cards.json");
  opts.outDir ??= path.join(opts.repoRoot, "web");
  return opts;
}

/**
 * Ensure `target` stays inside `root` to guard manifest-driven paths.
 * @param {string} root
 * @param {string} relPath
 */
export function resolveInside(root, relPath) {
  const base = path.resolve(root);
  const resolved = path.resolve(base, relPath);
  const rel = path.relative(base, resolved);
  if (rel.startsWith("..") || path.isAbsolute(rel)) {
    throw new Error(`Path escapes allowed root: ${relPath}`);
  }
  return resolved;
}

/**
 * Bind an HTTP server to loopback while rejecting cleanly on listen errors.
 * @param {http.Server} server
 * @param {number} port
 * @param {string} host
 */
export function listenLoopback(server, port = 0, host = "127.0.0.1") {
  return new Promise((resolve, reject) => {
    const onError = (err) => {
      server.off("listening", onListening);
      reject(err);
    };
    const onListening = () => {
      server.off("error", onError);
      resolve(server.address());
    };
    server.once("error", onError);
    server.once("listening", onListening);
    try {
      server.listen(port, host);
    } catch (err) {
      server.off("error", onError);
      server.off("listening", onListening);
      reject(err);
    }
  });
}

/**
 * Find pre-installed Chrome/Chromium executable if present on the host.
 * @param {string | null} explicitPath
 */
export function detectChromeExecutable(explicitPath = null) {
  if (explicitPath) {
    return explicitPath;
  }
  for (const candidate of SYSTEM_CHROME_CANDIDATES) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }
  return null;
}

/**
 * Escape HTML special characters.
 * @param {string} value
 */
export function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function hexToRgba(hex, alpha) {
  const cleaned = hex.replace("#", "");
  if (!/^[0-9a-fA-F]{6}$/.test(cleaned)) {
    throw new Error(`Invalid hex color: ${hex}`);
  }
  const r = Number.parseInt(cleaned.slice(0, 2), 16);
  const g = Number.parseInt(cleaned.slice(2, 4), 16);
  const b = Number.parseInt(cleaned.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

/**
 * Build standalone HTML/CSS for one card matching the approved LP visual identity.
 * Supports both 1200x630 OGP cards and 1600x900 16:9 X cards.
 * @param {object} card
 * @param {object} canvas
 * @param {string} artDataUri
 * @param {string | null} repoFontUrl
 */
export function renderCardHtml(card, canvas, artDataUri, repoFontUrl = null) {
  const width = Number(card.width);
  const height = Number(card.height);
  const isWide = width >= 1500;
  const contentWidth = isWide ? 910 : 720;
  const contentPadding = isWide ? "92px 0 116px 96px" : "64px 0 132px 72px";
  const dotSize = isWide ? 18 : 14;
  const badgeFontSize = isWide ? 28 : 23;
  const badgeGap = isWide ? 14 : 12;
  const badgeMarginBottom = isWide ? 30 : 22;
  const h1FontSize = isWide ? 88 : 66;
  const h1MarginBottom = isWide ? 28 : 22;
  const subFontSize = isWide ? 31 : 24;
  const subMarginBottom = isWide ? 34 : 26;
  const trustFontSize = isWide ? 24 : 19;
  const trustGap = isWide ? 20 : 16;

  const badgeParts = String(card.badge).split("|").map((s) => s.trim()).filter(Boolean);
  const badgeHtml =
    badgeParts.length > 1
      ? `<span class="brand-name">${escapeHtml(badgeParts[0])}</span><span class="brand-div">|</span><span class="brand-sub">${escapeHtml(badgeParts.slice(1).join(" | "))}</span>`
      : `<span class="brand-name">${escapeHtml(badgeParts[0] ?? "自分株式会社")}</span>`;

  const headlineLines = card.headline.map((line, idx) =>
    idx === 1
      ? `<span class="accent">${escapeHtml(line)}</span>`
      : escapeHtml(line)
  );
  const subcopyHtml = card.subcopy.map((line) => escapeHtml(line)).join("<br>");
  const trustHtml = card.trust
    .map((item) => `<span>${escapeHtml(item)}</span>`)
    .join('<span class="sep">|</span>');

  const accentGlow = hexToRgba(card.accentPrimary, 0.22);
  const secondaryGlow = hexToRgba(card.accentSecondary, 0.16);
  const dotGlow = hexToRgba(card.accentPrimary, 0.78);
  const repoFontRule = repoFontUrl
    ? `@font-face { font-family: "RepoNotoSansJP"; src: url("${escapeHtml(repoFontUrl)}") format("truetype"); font-weight: 100 900; font-display: swap; }\n`
    : "";

  return `<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<style>
  ${repoFontRule}* { box-sizing: border-box; margin: 0; padding: 0; }
  html, body {
    width: ${width}px;
    height: ${height}px;
    overflow: hidden;
    background: ${escapeHtml(canvas.background)};
    font-family: "Noto Sans CJK JP", "Noto Sans JP", "Yu Gothic UI", "Meiryo", "RepoNotoSansJP", system-ui, sans-serif;
    color: ${escapeHtml(canvas.textPrimary)};
  }
  .card {
    position: relative;
    width: ${width}px;
    height: ${height}px;
    background: ${escapeHtml(canvas.background)};
    overflow: hidden;
  }
  .bg-art {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    object-fit: cover;
    object-position: ${escapeHtml(card.artPosition ?? "86% 50%")};
    transform: scale(${isWide ? "1.03" : "1.06"});
    filter: contrast(1.06) saturate(1.12);
  }
  .ambient-glow {
    position: absolute;
    inset: 0;
    background:
      radial-gradient(circle at 80% 48%, ${accentGlow} 0%, transparent 46%),
      radial-gradient(circle at 18% 82%, ${secondaryGlow} 0%, transparent 42%);
    pointer-events: none;
  }
  .vignette {
    position: absolute;
    inset: 0;
    background:
      linear-gradient(96deg, rgba(7, 17, 30, 0.98) 0%, rgba(7, 17, 30, 0.95) 42%, rgba(7, 17, 30, 0.62) 64%, rgba(7, 17, 30, 0.16) 84%, rgba(7, 17, 30, 0.08) 100%),
      linear-gradient(180deg, rgba(7, 17, 30, 0.52) 0%, transparent 18%, transparent 74%, rgba(7, 17, 30, 0.74) 100%);
  }
  .accent-bar {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 4px;
    background: linear-gradient(90deg, ${escapeHtml(card.accentPrimary)}, ${escapeHtml(card.accentSecondary)}, transparent 78%);
    z-index: 3;
  }
  .content {
    position: relative;
    z-index: 2;
    width: ${contentWidth}px;
    height: 100%;
    padding: ${contentPadding};
    display: flex;
    flex-direction: column;
    justify-content: flex-start;
  }
  .brand-row {
    display: inline-flex;
    align-items: center;
    gap: ${badgeGap}px;
    margin-bottom: ${badgeMarginBottom}px;
  }
  .brand-dot {
    width: ${dotSize}px;
    height: ${dotSize}px;
    border-radius: 999px;
    background: ${escapeHtml(card.accentPrimary)};
    box-shadow: 0 0 18px ${dotGlow};
    flex-shrink: 0;
  }
  .brand-name {
    font-size: ${badgeFontSize}px;
    font-weight: 700;
    letter-spacing: 0.05em;
    color: #f0e5d0;
  }
  .brand-div {
    font-size: ${Math.max(16, badgeFontSize - 4)}px;
    color: rgba(240, 229, 208, 0.35);
  }
  .brand-sub {
    font-size: ${Math.max(18, badgeFontSize - 2)}px;
    font-weight: 700;
    letter-spacing: 0.06em;
    color: ${escapeHtml(card.headlineAccent)};
  }
  h1 {
    font-size: ${h1FontSize}px;
    font-weight: 900;
    line-height: 1.16;
    letter-spacing: -0.02em;
    color: ${escapeHtml(canvas.textPrimary)};
    text-shadow: 0 6px 28px rgba(0, 0, 0, 0.58);
    margin-bottom: ${h1MarginBottom}px;
  }
  .accent {
    color: ${escapeHtml(card.headlineAccent)};
  }
  .sub {
    font-size: ${subFontSize}px;
    font-weight: 500;
    line-height: 1.5;
    color: ${escapeHtml(canvas.textSecondary)};
    margin-bottom: ${subMarginBottom}px;
  }
  .trust {
    display: inline-flex;
    align-items: center;
    gap: ${trustGap}px;
    font-size: ${trustFontSize}px;
    font-weight: 700;
    color: ${escapeHtml(canvas.trustColor)};
  }
  .sep {
    color: rgba(240, 229, 208, 0.35);
  }
</style>
</head>
<body>
  <div class="card">
    <div class="accent-bar"></div>
    <img class="bg-art" src="${artDataUri}" alt="">
    <div class="ambient-glow"></div>
    <div class="vignette"></div>
    <div class="content">
      <div class="brand-row">
        <span class="brand-dot"></span>
        ${badgeHtml}
      </div>
      <h1>${headlineLines.join("<br>")}</h1>
      <p class="sub">${subcopyHtml}</p>
      <div class="trust">${trustHtml}</div>
    </div>
  </div>
</body>
</html>
`;
}

function readPngDimensions(buffer) {
  if (buffer.length < 24 || !buffer.subarray(0, 8).equals(PNG_SIGNATURE)) {
    throw new Error("Invalid PNG header");
  }
  return {
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20),
  };
}

/**
 * Validate all generated PNG cards match manifest filenames, dimensions, and byte bounds.
 * @param {object} manifest
 * @param {string} outDir
 */
export function verifyOutputs(manifest, outDir) {
  for (const card of manifest.cards) {
    const outPath = resolveInside(outDir, card.output);
    if (!fs.existsSync(outPath)) {
      throw new Error(`Missing rendered card: ${outPath}`);
    }
    const raw = fs.readFileSync(outPath);
    if (raw.length < MIN_CARD_BYTES) {
      throw new Error(`Card smaller than ${MIN_CARD_BYTES} B (${raw.length} B): ${card.output}`);
    }
    if (raw.length > MAX_CARD_BYTES) {
      throw new Error(`Card exceeds ${MAX_CARD_BYTES} B (${raw.length} B): ${card.output}`);
    }
    const { width, height } = readPngDimensions(raw);
    if (width !== card.width || height !== card.height) {
      throw new Error(
        `Dimension mismatch for ${card.output}: expected ${card.width}x${card.height}, got ${width}x${height}`,
      );
    }
    console.log(`VERIFIED ${card.output}: ${width}x${height} (${raw.length} B)`);
  }
}

function loadManifestWithArt(configPath, assetsRoot) {
  const manifest = JSON.parse(fs.readFileSync(configPath, "utf-8"));
  const cardsWithArt = manifest.cards.map((card) => {
    const artPath = resolveInside(assetsRoot, card.artwork);
    const b64 = fs.readFileSync(artPath).toString("base64");
    return {
      ...card,
      artDataUri: `data:image/webp;base64,${b64}`,
    };
  });
  return { manifest, cardsWithArt };
}

function writeHtmlBundle(htmlDir, manifest, cardsWithArt) {
  fs.mkdirSync(htmlDir, { recursive: true });
  const records = [];
  for (const card of cardsWithArt) {
    const htmlContent = renderCardHtml(card, manifest.canvas, card.artDataUri);
    const htmlFile = `${card.id}.html`;
    fs.writeFileSync(path.join(htmlDir, htmlFile), htmlContent, "utf-8");
    records.push({
      id: card.id,
      htmlFile,
      output: card.output,
      width: card.width,
      height: card.height,
      badge: card.badge,
      alt: card.alt,
    });
  }
  fs.writeFileSync(
    path.join(htmlDir, "manifest.json"),
    `${JSON.stringify({ cards: records }, null, 2)}\n`,
    "utf-8",
  );
  console.log(`WROTE ${records.length} HTML templates into ${htmlDir}`);
}

async function renderWithChromeCli(chromeBin, htmlDir, outDir, manifest, cardsWithArt) {
  writeHtmlBundle(htmlDir, manifest, cardsWithArt);
  const profileDir = path.join(htmlDir, "_chrome_profile");
  fs.mkdirSync(profileDir, { recursive: true });

  const server = http.createServer((req, res) => {
    const cleanName = path.basename((req.url ?? "/").split("?")[0]);
    const filePath = path.join(htmlDir, cleanName);
    if (!fs.existsSync(filePath) || !cleanName.endsWith(".html")) {
      res.writeHead(404);
      res.end("not found");
      return;
    }
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    fs.createReadStream(filePath).pipe(res);
  });

  const addr = await listenLoopback(server);
  const baseUrl = `http://127.0.0.1:${addr.port}`;

  try {
    for (const card of cardsWithArt) {
      const outPath = resolveInside(outDir, card.output);
      fs.mkdirSync(path.dirname(outPath), { recursive: true });
      const winW = card.width + 200;
      const winH = card.height + 170;
      execFileSync(chromeBin, [
        "--headless=new",
        "--disable-gpu",
        "--no-sandbox",
        "--hide-scrollbars",
        `--user-data-dir=${profileDir}`,
        `--window-size=${winW},${winH}`,
        "--force-device-scale-factor=1",
        `--screenshot=${outPath}`,
        `${baseUrl}/${card.id}.html`,
      ]);
      console.log(`CHROME-CLI RENDERED ${card.output}`);
    }
  } finally {
    server.close();
    fs.rmSync(profileDir, { recursive: true, force: true });
  }
}

async function renderWithPlaywright(repoRoot, outDir, manifest, cardsWithArt, chromeBin = null) {
  let chromium;
  try {
    ({ chromium } = await import("@playwright/test"));
  } catch (err) {
    throw new Error(
      "@playwright/test is required to render OGP cards; run `npm ci` before generate_ogp_cards.mjs.",
      { cause: err },
    );
  }
  const repoFontPath = path.join(repoRoot, "web", "assets", "fonts", "NotoSansJP-Regular.ttf");
  const hasRepoFont = fs.existsSync(repoFontPath);
  const cardByPath = new Map();

  const server = http.createServer((req, res) => {
    const urlPath = (req.url ?? "/").split("?")[0];
    if (hasRepoFont && urlPath === "/fonts/NotoSansJP-Regular.ttf") {
      res.writeHead(200, { "Content-Type": "font/ttf" });
      fs.createReadStream(repoFontPath).pipe(res);
      return;
    }
    const htmlPayload = cardByPath.get(urlPath);
    if (!htmlPayload) {
      res.writeHead(404);
      res.end("not found");
      return;
    }
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(htmlPayload);
  });

  const addr = await listenLoopback(server);
  const baseUrl = `http://127.0.0.1:${addr.port}`;
  const fontUrl = hasRepoFont ? `${baseUrl}/fonts/NotoSansJP-Regular.ttf` : null;

  for (const card of cardsWithArt) {
    cardByPath.set(
      `/${card.id}.html`,
      renderCardHtml(card, manifest.canvas, card.artDataUri, fontUrl),
    );
  }

  const executablePath = detectChromeExecutable(chromeBin);
  const launchOptions = executablePath
    ? { executablePath, headless: true, args: ["--no-sandbox", "--disable-dev-shm-usage"] }
    : { headless: true };
  if (executablePath) {
    console.log(`Using system Chrome executable: ${executablePath}`);
  }

  let browser = null;
  try {
    browser = await chromium.launch(launchOptions);
    for (const card of cardsWithArt) {
      const outPath = resolveInside(outDir, card.output);
      fs.mkdirSync(path.dirname(outPath), { recursive: true });
      const context = await browser.newContext({
        viewport: { width: card.width, height: card.height },
        deviceScaleFactor: 1,
      });
      try {
        const page = await context.newPage();
        await page.goto(`${baseUrl}/${card.id}.html`, { waitUntil: "networkidle" });
        await page.evaluate(() => document.fonts?.ready);
        await page.locator(".card").screenshot({ path: outPath, type: "png" });
        console.log(`PLAYWRIGHT RENDERED ${card.output}`);
      } finally {
        await context.close();
      }
    }
  } finally {
    if (browser) {
      await browser.close();
    }
    server.close();
  }
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.verifyOnly) {
    const manifest = JSON.parse(fs.readFileSync(opts.configPath, "utf-8"));
    verifyOutputs(manifest, opts.outDir);
    return;
  }

  const { manifest, cardsWithArt } = loadManifestWithArt(opts.configPath, opts.assetsRoot);
  if (opts.htmlDir && !opts.chromeBin) {
    writeHtmlBundle(opts.htmlDir, manifest, cardsWithArt);
    return;
  }
  if (opts.chromeBin && process.env.OGP_USE_CHROME_CLI === "1") {
    const htmlDir = opts.htmlDir ?? path.join(opts.repoRoot, ".tmp_ogp_html");
    await renderWithChromeCli(opts.chromeBin, htmlDir, opts.outDir, manifest, cardsWithArt);
    return;
  }

  await renderWithPlaywright(opts.repoRoot, opts.outDir, manifest, cardsWithArt, opts.chromeBin);
  verifyOutputs(manifest, opts.outDir);
}

function isCliEntrypoint() {
  if (!process.argv[1]) {
    return false;
  }
  try {
    return fs.realpathSync(process.argv[1]) === fs.realpathSync(__filename);
  } catch {
    return path.resolve(process.argv[1]) === __filename;
  }
}

if (isCliEntrypoint()) {
  main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
